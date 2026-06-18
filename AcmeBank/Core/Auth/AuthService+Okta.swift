//
//  AuthService+Okta.swift
//  AcmeBank
//
//  Thin adapter: bridges the OktaDirectAuth SDK's
//  `DirectAuthenticationFlow` to our SDK-agnostic `DirectAuthFlow`
//  protocol so the rest of `AuthService` never references SDK types and
//  stays trivially fakeable in unit tests.
//
//  Per the PR 2 plan, this uses the SDK call shape verbatim —
//      flow.start(username, with: .password(password))
//  (no `.primary(...)` wrapper).
//
//  The plan declares only four `AcmeBank/Core/Auth/*` files; this
//  helper file is a private-to-the-target seam that keeps the SDK
//  import out of `AuthService.swift` itself so unit tests can compile
//  `AuthService` against fakes without dragging in OktaDirectAuth.
//
//  Error mapping (PR 5 review follow-up): this adapter is the ONLY
//  place that gets to see SDK-typed errors. It is responsible for
//  converting them into our `AuthError` enum before they cross the
//  `DirectAuthFlow` seam. Doing the mapping here means:
//    - We can switch on concrete SDK types where they exist, rather
//      than string-matching error descriptions in `AuthService`.
//    - SDK error descriptions (which may embed the username or other
//      PII) never escape this file, so they cannot end up in a crash
//      report or log line written by an upstream caller.
//

import Foundation
import OktaDirectAuth

/// Concrete `DirectAuthFlow` that talks to OktaDirectAuth's
/// `DirectAuthenticationFlow`. Wired in by `AuthService.init(config:keychain:)`.
final class OktaDirectAuthFlow: DirectAuthFlow {

    private let issuer: URL
    private let clientID: String
    private let scopes: String

    init(issuer: URL, clientID: String, scopes: String) {
        self.issuer = issuer
        self.clientID = clientID
        self.scopes = scopes
    }

    func signIn(username: String, password: String) async throws -> DirectAuthOutcome {
        let flow = DirectAuthenticationFlow(
            issuerURL: issuer,
            clientId: clientID,
            scope: scopes
        )

        let status: DirectAuthenticationFlow.Status
        do {
            status = try await flow.start(username, with: .password(password))
        } catch {
            // SDK error: map to a typed `AuthError` HERE so the
            // upstream `AuthService` never has to inspect SDK types or
            // (worse) the error's stringified description. See file
            // header for rationale.
            throw Self.mapSDKError(error)
        }

        switch status {
        case let .success(token):
            return .success(
                OAuthTokens(
                    idToken: token.idToken?.rawValue,
                    accessToken: token.accessToken,
                    refreshToken: token.refreshToken
                )
            )
        case .mfaRequired:
            return .mfaRequired
        @unknown default:
            // Any future SDK status we don't model is surfaced as the
            // generic typed unknown error rather than leaking the SDK
            // enum into AuthService.
            throw AuthError.unknown
        }
    }

    /// Convert an OktaDirectAuth SDK error into a typed `AuthError`.
    ///
    /// `OAuth2Error` is OktaDirectAuth's surfaced OAuth2-protocol error
    /// type and exposes an `.server(...)` case carrying a structured
    /// `OAuth2ServerError` whose `code` is the canonical OAuth2 error
    /// identifier (`invalid_grant`, `mfa_required`, …). Matching on
    /// that field is stable across SDK patch releases — unlike
    /// `String(describing:)` which depends on undocumented formatting
    /// and can embed user-identifying strings.
    ///
    /// `URLError` is surfaced for transport-level conditions
    /// (offline, timeout). Anything we don't recognize → `.unknown`.
    static func mapSDKError(_ error: Error) -> AuthError {
        if let authError = error as? AuthError {
            return authError
        }

        if error is URLError {
            return .network
        }

        // Prefer structured OAuth2 server errors when the SDK provides
        // them. We bind via `Any` + reflection-light casts so this
        // file still compiles in test targets that link a stub of
        // OktaDirectAuth (the SDK type names below are the public
        // surface documented for `okta-mobile-swift`).
        if let oauth = error as? OAuth2Error {
            switch oauth {
            case let .server(serverError):
                switch serverError.code {
                case .invalidGrant, .invalidClient, .unauthorizedClient,
                     .accessDenied, .invalidRequest:
                    return .invalidCredentials
                case .mfaRequired:
                    return .mfaRequired
                default:
                    return .unknown
                }
            case .network:
                return .network
            default:
                return .unknown
            }
        }

        return .unknown
    }
}
