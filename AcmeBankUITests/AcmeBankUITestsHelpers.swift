//
//  AcmeBankUITestsHelpers.swift
//  AcmeBankUITests
//
//  Shared helpers for the XCUITest target. Lives in the UI-test target,
//  NOT the app target \u2014 we deliberately do not `@testable import
//  AcmeBank` here. XCUITest runs out-of-process and reading Info.plist
//  + ProcessInfo directly keeps the helper self-contained.
//
//  `oktaIsConfigured()` MIRRORS the sentinel-detection logic in
//  `AcmeBank/Core/Config/OktaConfig.swift`. The four Info.plist keys
//  and four sentinel strings are duplicated here intentionally \u2014 the
//  alternative (linking the app module from the UI-test target) is
//  invasive and Apple's UI-test process model doesn't play well with
//  app-internal types. If `OktaConfig` ever changes its keys or
//  sentinels, this file MUST be updated in the same PR.
//

import Foundation
import XCTest

// MARK: - Info.plist keys (mirror of OktaConfig)

private enum OktaPlistKey {
    static let issuer      = "OktaIssuer"
    static let clientID    = "OktaClientID"
    static let redirectURI = "OktaRedirectURI"
    static let scopes      = "OktaScopes"
}

// MARK: - Sentinels (mirror of Scripts/inject_okta_config.sh)

private enum OktaSentinel {
    static let issuer      = "__OKTA_ISSUER_UNSET__"
    static let clientID    = "__OKTA_CLIENT_ID_UNSET__"
    static let redirectURI = "__OKTA_REDIRECT_URI_UNSET__"
    static let scopes      = "__OKTA_SCOPES_UNSET__"
}

/// `true` when the app under test was built with all four `OKTA_*`
/// env vars set (none of the Info.plist values hold a sentinel and all
/// four keys are non-empty).
///
/// Reads the app bundle's Info.plist via the launched app's bundle
/// when called from inside a test, or falls back to the test runner's
/// bundle when called pre-launch (the test runner picks up the same
/// Info.plist entries through the app target's plist for the
/// AcmeBank.app bundle resolved at launch time).
///
/// In practice tests call this BEFORE `app.launch()` to decide whether
/// to skip; for that path we read `Bundle.main.infoDictionary` of the
/// runner. The Info.plist values are injected at build time into the
/// AcmeBank.app bundle, which is what `XCUIApplication` launches, so
/// the values relevant for the runtime test live there. To keep the
/// helper usable from both pre- and post-launch, we also accept a
/// `bundle` override.
public func oktaIsConfigured(
    bundle: Bundle = .main
) -> Bool {
    let info = bundle.infoDictionary ?? [:]

    guard let issuer = info[OktaPlistKey.issuer] as? String,
          !issuer.isEmpty,
          issuer != OktaSentinel.issuer
    else { return false }

    guard let clientID = info[OktaPlistKey.clientID] as? String,
          !clientID.isEmpty,
          clientID != OktaSentinel.clientID
    else { return false }

    guard let redirectURI = info[OktaPlistKey.redirectURI] as? String,
          !redirectURI.isEmpty,
          redirectURI != OktaSentinel.redirectURI
    else { return false }

    guard let scopes = info[OktaPlistKey.scopes] as? String,
          !scopes.isEmpty,
          scopes != OktaSentinel.scopes
    else { return false }

    return true
}

// MARK: - Test-credential env vars

/// Read `OKTA_TEST_USERNAME` from the test runner's process
/// environment. Returns `nil` when unset or empty.
public func oktaTestUsername() -> String? {
    let raw = ProcessInfo.processInfo.environment["OKTA_TEST_USERNAME"]
    guard let raw, !raw.isEmpty else { return nil }
    return raw
}

/// Read `OKTA_TEST_PASSWORD` from the test runner's process
/// environment. Returns `nil` when unset or empty.
public func oktaTestPassword() -> String? {
    let raw = ProcessInfo.processInfo.environment["OKTA_TEST_PASSWORD"]
    guard let raw, !raw.isEmpty else { return nil }
    return raw
}
