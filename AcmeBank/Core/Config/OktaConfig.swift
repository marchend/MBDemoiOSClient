//
//  OktaConfig.swift
//  AcmeBank
//
//  Runtime loader for the four Okta OIDC configuration values injected into
//  the app's Info.plist at build time by `Scripts/inject_okta_config.sh`.
//
//  Design:
//  - `load()` reads `Bundle.main.infoDictionary` and detects the sentinel
//    strings the build script writes when an env var is unset.
//  - Returns `.configured(...)` only when ALL four values are present, are
//    not sentinels, and the URLs parse.
//  - Returns `.notConfigured(reason:)` with a developer-readable reason when
//    any value is missing or malformed — callers (e.g. AuthService) decide
//    what to do with the unconfigured state.
//  - No `fatalError`, no force-unwraps. A misconfigured build must still
//    boot so the misconfiguration is observable in-app.
//

import Foundation

public enum OktaConfig: Equatable {
    case configured(issuer: URL, clientID: String, redirectURI: URL, scopes: String)
    case notConfigured(reason: String)

    // Info.plist keys written by Scripts/inject_okta_config.sh.
    private static let issuerKey      = "OktaIssuer"
    private static let clientIDKey    = "OktaClientID"
    private static let redirectURIKey = "OktaRedirectURI"
    private static let scopesKey      = "OktaScopes"

    // Sentinel strings written by Scripts/inject_okta_config.sh when an env
    // var is unset. Must stay byte-identical to the script.
    private static let issuerSentinel      = "__OKTA_ISSUER_UNSET__"
    private static let clientIDSentinel    = "__OKTA_CLIENT_ID_UNSET__"
    private static let redirectURISentinel = "__OKTA_REDIRECT_URI_UNSET__"
    private static let scopesSentinel      = "__OKTA_SCOPES_UNSET__"

    /// Load Okta config from `Bundle.main.infoDictionary`. Returns
    /// `.notConfigured` when any key is absent, holds the build-script
    /// sentinel, or fails URL parsing.
    public static func load() -> OktaConfig {
        load(from: Bundle.main.infoDictionary ?? [:])
    }

    /// Test-seam: load from an arbitrary dictionary so unit tests don't have
    /// to mutate `Bundle.main`.
    static func load(from info: [String: Any]) -> OktaConfig {
        guard let rawIssuer = info[issuerKey] as? String, !rawIssuer.isEmpty else {
            return .notConfigured(reason: "Missing Info.plist key '\(issuerKey)'.")
        }
        if rawIssuer == issuerSentinel {
            return .notConfigured(reason: "OKTA_ISSUER env var not set at build time (Info.plist '\(issuerKey)' holds sentinel).")
        }

        guard let rawClientID = info[clientIDKey] as? String, !rawClientID.isEmpty else {
            return .notConfigured(reason: "Missing Info.plist key '\(clientIDKey)'.")
        }
        if rawClientID == clientIDSentinel {
            return .notConfigured(reason: "OKTA_CLIENT_ID env var not set at build time (Info.plist '\(clientIDKey)' holds sentinel).")
        }

        guard let rawRedirectURI = info[redirectURIKey] as? String, !rawRedirectURI.isEmpty else {
            return .notConfigured(reason: "Missing Info.plist key '\(redirectURIKey)'.")
        }
        if rawRedirectURI == redirectURISentinel {
            return .notConfigured(reason: "OKTA_REDIRECT_URI env var not set at build time (Info.plist '\(redirectURIKey)' holds sentinel).")
        }

        guard let rawScopes = info[scopesKey] as? String, !rawScopes.isEmpty else {
            return .notConfigured(reason: "Missing Info.plist key '\(scopesKey)'.")
        }
        if rawScopes == scopesSentinel {
            return .notConfigured(reason: "OKTA_SCOPES env var not set at build time (Info.plist '\(scopesKey)' holds sentinel).")
        }

        guard let issuerURL = URL(string: rawIssuer), issuerURL.scheme != nil else {
            return .notConfigured(reason: "Malformed URL in Info.plist '\(issuerKey)': '\(rawIssuer)'.")
        }
        guard let redirectURL = URL(string: rawRedirectURI), redirectURL.scheme != nil else {
            return .notConfigured(reason: "Malformed URL in Info.plist '\(redirectURIKey)': '\(rawRedirectURI)'.")
        }

        return .configured(
            issuer: issuerURL,
            clientID: rawClientID,
            redirectURI: redirectURL,
            scopes: rawScopes
        )
    }
}
