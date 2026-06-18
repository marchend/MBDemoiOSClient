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

        let status = try await flow.start(username, with: .password(password))

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
}
