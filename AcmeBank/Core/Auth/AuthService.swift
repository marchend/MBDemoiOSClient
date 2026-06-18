//
//  AuthService.swift
//  AcmeBank
//
//  The Okta integration layer. Owns:
//  - The `DirectAuthenticationFlow` password-grant sign-in path.
//  - The OAuth2 refresh-token grant path used at cold launch by
//    `AppCoordinator` (PR 4) when a refresh token is found in the
//    Keychain.
//  - Decoding the returned ID token into a `UserSession`.
//  - Writing tokens to the Keychain (refresh only when the user opted
//    into "Keep me signed in").
//  - Mapping Okta SDK errors / statuses to a small typed `AuthError`
//    enum the UI can switch on.
//
//  Errors after a SUCCESSFUL token grant (JWT decode, keychain write)
//  must NOT escape `signIn` / `refresh` as untyped errors — see the
//  team lesson "iOS auth: post-SDK-success failures …". JWT decode
//  failures map to `.unknown`; keychain failures are swallowed in-place
//  (treated as a cache miss).
//
//  Decoupling note: the OktaDirectAuth SDK is invoked behind the
//  `DirectAuthFlow` protocol so unit tests can inject a fake that
//  returns our `OAuthTokens` DTO without dragging SDK types into the
//  test target. The thin adapter that bridges `DirectAuthenticationFlow`
//  → `DirectAuthFlow` lives in `AuthService+Okta.swift` so this file
//  stays compilable in test environments where the SDK is mocked.
//
//  Error-mapping contract (PR 5 review follow-up): the adapter
//  (`OktaDirectAuthFlow`) is responsible for converting SDK error
//  types into our `AuthError` cases BEFORE they cross the
//  `DirectAuthFlow` seam. `AuthService.mapSignInError` therefore only
//  recognizes (a) already-typed `AuthError`s rethrown by the adapter
//  and (b) `URLError` (the transport-level case from `URLSession`).
//  Everything else is `.unknown` — we deliberately do NOT pattern-
//  match on `String(describing: error)` because SDK error descriptions
//  may embed usernames or other PII.
//
//  Refresh-token cache-clearing contract (PR 5 review follow-up):
//  `keychain.clearAll()` is called ONLY when the IdP explicitly rejects
//  the refresh token with a 4xx response. Transport-level errors
//  (offline, timeout, captive portal) leave the stored refresh token
//  alone so a transient network failure at cold launch doesn't destroy
//  the user's "keep me signed in" session.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Public surface

public enum AuthError: Error, Equatable {
    case invalidCredentials
    case network
    case mfaRequired
    case unknown
}

public protocol AuthServicing {
    /// Sign in with username + password via Okta DirectAuth.
    /// - Parameter keepSignedIn: when `true`, the refresh token is
    ///   persisted to the Keychain so the next cold launch can call
    ///   `refresh(refreshToken:)` and skip the login screen.
    func signIn(
        username: String,
        password: String,
        keepSignedIn: Bool
    ) async throws -> UserSession

    /// Exchange a refresh token (previously persisted on a "keep signed
    /// in" sign-in) for a fresh access + ID token. Used at cold launch.
    /// On a 4xx rejection from the IdP, AuthService clears the stored
    /// refresh token so a stale token doesn't retry forever. Transport-
    /// level failures (offline, timeout) leave the keychain alone.
    func refresh(refreshToken: String) async throws -> UserSession
}

// MARK: - SDK-agnostic value types

/// Triple of tokens any successful OAuth2 grant gives us. Lives in our
/// module so test fakes don't need to import OktaDirectAuth.
public struct OAuthTokens: Equatable {
    public let idToken: String?
    public let accessToken: String
    public let refreshToken: String?

    public init(idToken: String?, accessToken: String, refreshToken: String?) {
        self.idToken = idToken
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

/// Outcome of a DirectAuth password-grant attempt, post-mapping. Models
/// the only three branches AuthService cares about.
public enum DirectAuthOutcome: Equatable {
    case success(OAuthTokens)
    case mfaRequired
}

/// SDK-agnostic seam over `DirectAuthenticationFlow`. AuthService talks
/// only to this; the OktaDirectAuth adapter lives in a sibling file.
///
/// Contract: implementations MUST translate SDK error types into
/// `AuthError` cases before throwing across this protocol. AuthService
/// will not inspect the underlying error's description (see file
/// header for rationale).
public protocol DirectAuthFlow {
    func signIn(username: String, password: String) async throws -> DirectAuthOutcome
}

// MARK: - Refresh transport (test seam over URLSession)

/// Minimal seam so refresh-token unit tests don't hit the network.
public protocol TokenRefreshTransport {
    func post(_ request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: TokenRefreshTransport {
    public func post(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request)
    }
}

// MARK: - AuthService

public final class AuthService: AuthServicing {

    private let issuer: URL
    private let clientID: String
    private let redirectURI: URL
    private let scopes: String
    private let keychain: KeychainStoring
    private let decoder: IDTokenDecoder
    private let flowFactory: () -> DirectAuthFlow
    private let transport: TokenRefreshTransport
    private let deviceNameProvider: () -> String
    private let now: () -> Date

    /// Designated init. Most callers will use the convenience init below
    /// that takes the `OktaConfig.configured(...)` payload.
    public init(
        issuer: URL,
        clientID: String,
        redirectURI: URL,
        scopes: String,
        keychain: KeychainStoring,
        decoder: IDTokenDecoder = IDTokenDecoder(),
        flowFactory: @escaping () -> DirectAuthFlow,
        transport: TokenRefreshTransport = URLSession.shared,
        deviceNameProvider: @escaping () -> String = AuthService.defaultDeviceName,
        now: @escaping () -> Date = Date.init
    ) {
        self.issuer = issuer
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.scopes = scopes
        self.keychain = keychain
        self.decoder = decoder
        self.flowFactory = flowFactory
        self.transport = transport
        self.deviceNameProvider = deviceNameProvider
        self.now = now
    }

    /// Convenience init wired from a `.configured(...)` `OktaConfig`,
    /// using the real OktaDirectAuth-backed flow factory.
    public convenience init?(
        config: OktaConfig,
        keychain: KeychainStoring
    ) {
        guard case let .configured(issuer, clientID, redirectURI, scopes) = config else {
            return nil
        }
        self.init(
            issuer: issuer,
            clientID: clientID,
            redirectURI: redirectURI,
            scopes: scopes,
            keychain: keychain,
            flowFactory: {
                OktaDirectAuthFlow(
                    issuer: issuer,
                    clientID: clientID,
                    scopes: scopes
                )
            }
        )
    }

    // MARK: - signIn

    public func signIn(
        username: String,
        password: String,
        keepSignedIn: Bool
    ) async throws -> UserSession {
        let flow = flowFactory()

        let outcome: DirectAuthOutcome
        do {
            outcome = try await flow.signIn(username: username, password: password)
        } catch {
            throw Self.mapSignInError(error)
        }

        switch outcome {
        case let .success(tokens):
            return try persistAndBuildSession(tokens: tokens, keepSignedIn: keepSignedIn)
        case .mfaRequired:
            throw AuthError.mfaRequired
        }
    }

    // MARK: - refresh

    public func refresh(refreshToken: String) async throws -> UserSession {
        let tokenURL = Self.tokenEndpoint(forIssuer: issuer)

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body = formURLEncoded([
            "grant_type":    "refresh_token",
            "refresh_token": refreshToken,
            "client_id":     clientID,
            "scope":         scopes,
        ])
        request.httpBody = body.data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.post(request)
        } catch {
            // Transport-level failure (offline, timeout, captive portal):
            // the refresh token may still be valid — we just couldn't
            // reach the IdP. Leave the keychain alone so the next cold
            // launch (with a working network) can retry. Clearing here
            // would destroy a perfectly good "keep me signed in" session.
            throw AuthError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.unknown
        }

        switch http.statusCode {
        case 200..<300:
            break
        case 400, 401:
            // Stale / revoked refresh token: the IdP has explicitly
            // told us this token is no good. Clear so we don't keep
            // retrying it forever.
            try? keychain.clearAll()
            throw AuthError.invalidCredentials
        case 500...:
            // Server-side hiccup — token is probably still valid, so
            // do NOT clear; treat the same as a transport failure.
            throw AuthError.network
        default:
            throw AuthError.unknown
        }

        let payload: RefreshTokenResponse
        do {
            payload = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
        } catch {
            // A 2xx with an unparseable body is an IdP/contract bug,
            // not a stale-token problem; surface as unknown but don't
            // wipe the keychain.
            throw AuthError.unknown
        }

        return try persistAndBuildSession(
            tokens: OAuthTokens(
                idToken: payload.idToken,
                accessToken: payload.accessToken,
                refreshToken: payload.refreshToken ?? refreshToken
            ),
            keepSignedIn: true
        )
    }

    // MARK: - Internals

    /// Derive the Okta token endpoint from a configured issuer URL.
    ///
    /// Okta authorization-server issuers have the form
    /// `https://{org}.okta.com/oauth2/{asId}` (e.g.
    /// `https://example.okta.com/oauth2/default`). The `{asId}` segment
    /// (`default`, `aus…`) is part of the `iss` claim's IDENTIFIER but
    /// is NOT part of the token endpoint — the token endpoint sits at
    /// `https://{org}.okta.com/oauth2/v1/token`. Naïvely appending
    /// `v1/token` to the issuer produces `…/oauth2/default/v1/token`,
    /// which 404s in production.
    ///
    /// We therefore drop the trailing AS-id path component before
    /// appending `v1/token`. For an org-level issuer that already ends
    /// in `/oauth2` we fall back to the simple append.
    static func tokenEndpoint(forIssuer issuer: URL) -> URL {
        let last = issuer.lastPathComponent
        // Org-level issuer (`…/oauth2`) — just append.
        if last == "oauth2" || last.isEmpty || last == "/" {
            return issuer.appendingPathComponent("v1/token")
        }
        // Custom AS issuer (`…/oauth2/{asId}`) — strip the asId.
        return issuer
            .deletingLastPathComponent()
            .appendingPathComponent("v1/token")
    }

    /// Persist the three tokens (refresh only when `keepSignedIn`) and
    /// build a `UserSession` from the ID-token claims. Keychain failures
    /// are swallowed — see the team lesson on post-SDK-success failures.
    private func persistAndBuildSession(
        tokens: OAuthTokens,
        keepSignedIn: Bool
    ) throws -> UserSession {
        guard let idToken = tokens.idToken else {
            // No ID token => can't build a UserSession (no `sub`). Surface
            // a typed error instead of letting an untyped error escape.
            throw AuthError.unknown
        }

        let claims: IDTokenDecoder.Claims
        do {
            claims = try decoder.decode(idToken)
        } catch {
            throw AuthError.unknown
        }

        // Keychain writes are treated as a cache: best-effort, never fatal.
        do { try keychain.storeIDToken(idToken) }          catch { /* cache miss */ }
        do { try keychain.storeAccessToken(tokens.accessToken) } catch { /* cache miss */ }

        if keepSignedIn, let refreshToken = tokens.refreshToken {
            do { try keychain.storeRefreshToken(refreshToken) } catch { /* cache miss */ }
        }

        return UserSession(
            userId: claims.sub,
            displayName: claims.name ?? "",
            email: claims.email ?? "",
            accessToken: tokens.accessToken,
            authTimestamp: claims.authTime ?? now(),
            deviceName: deviceNameProvider()
        )
    }

    /// Final-mile mapping at the AuthService layer. The adapter
    /// (`OktaDirectAuthFlow`) is the layer that knows the SDK and is
    /// responsible for converting SDK-typed errors into `AuthError`
    /// cases. This function therefore only recognizes:
    ///
    ///   - `AuthError`            — already-typed; rethrow as-is.
    ///   - `URLError`             — transport-level from `URLSession`,
    ///                              map to `.network`.
    ///   - anything else          — `.unknown`.
    ///
    /// We deliberately do NOT pattern-match on `String(describing:)`
    /// of the error: SDK error descriptions are undocumented, can
    /// change without notice, and (worse) often embed the username or
    /// partial credential strings which would leak into any caller
    /// that logs the result.
    static func mapSignInError(_ error: Error) -> AuthError {
        if let authError = error as? AuthError {
            return authError
        }
        if error is URLError {
            return .network
        }
        return .unknown
    }

    private func formURLEncoded(_ pairs: [String: String]) -> String {
        pairs
            .map { "\(Self.percentEncode($0.key))=\(Self.percentEncode($0.value))" }
            .joined(separator: "&")
    }

    static func percentEncode(_ s: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    public static func defaultDeviceName() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "iOS"
        #endif
    }
}

// MARK: - Refresh response

private struct RefreshTokenResponse: Decodable {
    let accessToken: String
    let idToken: String?
    let refreshToken: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case idToken      = "id_token"
        case refreshToken = "refresh_token"
    }
}
