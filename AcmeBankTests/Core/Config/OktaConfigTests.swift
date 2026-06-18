//
//  OktaConfigTests.swift
//  AcmeBankTests
//

import XCTest
@testable import AcmeBank

final class OktaConfigTests: XCTestCase {

    // MARK: - Fixtures

    private let realIssuer      = "https://example.okta.com/oauth2/default"
    private let realClientID    = "0oa1234567890abcdef"
    private let realRedirectURI = "com.acmebank.mobile:/callback"
    private let realScopes      = "openid profile offline_access"

    private let issuerSentinel      = "__OKTA_ISSUER_UNSET__"
    private let clientIDSentinel    = "__OKTA_CLIENT_ID_UNSET__"
    private let redirectURISentinel = "__OKTA_REDIRECT_URI_UNSET__"
    private let scopesSentinel      = "__OKTA_SCOPES_UNSET__"

    private func info(
        issuer: String? = nil,
        clientID: String? = nil,
        redirectURI: String? = nil,
        scopes: String? = nil
    ) -> [String: Any] {
        [
            "OktaIssuer":      issuer      ?? realIssuer,
            "OktaClientID":    clientID    ?? realClientID,
            "OktaRedirectURI": redirectURI ?? realRedirectURI,
            "OktaScopes":      scopes      ?? realScopes,
        ]
    }

    // MARK: - Happy path

    func test_load_allFourValuesPresent_returnsConfigured() {
        let result = OktaConfig.load(from: info())

        guard case let .configured(issuer, clientID, redirectURI, scopes) = result else {
            return XCTFail("Expected .configured, got \(result)")
        }
        XCTAssertEqual(issuer.absoluteString, realIssuer)
        XCTAssertEqual(clientID, realClientID)
        XCTAssertEqual(redirectURI.absoluteString, realRedirectURI)
        XCTAssertEqual(scopes, realScopes)
    }

    // MARK: - Sentinel paths

    func test_load_issuerSentinel_returnsNotConfiguredNamingIssuer() {
        let result = OktaConfig.load(from: info(issuer: issuerSentinel))

        guard case let .notConfigured(reason) = result else {
            return XCTFail("Expected .notConfigured, got \(result)")
        }
        XCTAssertTrue(reason.contains("OKTA_ISSUER"), "Reason should name OKTA_ISSUER, got: \(reason)")
    }

    func test_load_clientIDSentinel_returnsNotConfiguredNamingClientID() {
        let result = OktaConfig.load(from: info(clientID: clientIDSentinel))

        guard case let .notConfigured(reason) = result else {
            return XCTFail("Expected .notConfigured, got \(result)")
        }
        XCTAssertTrue(reason.contains("OKTA_CLIENT_ID"), "Reason should name OKTA_CLIENT_ID, got: \(reason)")
    }

    func test_load_redirectURISentinel_returnsNotConfiguredNamingRedirectURI() {
        let result = OktaConfig.load(from: info(redirectURI: redirectURISentinel))

        guard case let .notConfigured(reason) = result else {
            return XCTFail("Expected .notConfigured, got \(result)")
        }
        XCTAssertTrue(reason.contains("OKTA_REDIRECT_URI"), "Reason should name OKTA_REDIRECT_URI, got: \(reason)")
    }

    func test_load_scopesSentinel_returnsNotConfiguredNamingScopes() {
        let result = OktaConfig.load(from: info(scopes: scopesSentinel))

        guard case let .notConfigured(reason) = result else {
            return XCTFail("Expected .notConfigured, got \(result)")
        }
        XCTAssertTrue(reason.contains("OKTA_SCOPES"), "Reason should name OKTA_SCOPES, got: \(reason)")
    }

    // MARK: - Malformed URL

    func test_load_malformedIssuerURL_returnsNotConfigured() {
        // A bare string with no scheme is not a usable issuer URL.
        let result = OktaConfig.load(from: info(issuer: "not a url"))

        guard case let .notConfigured(reason) = result else {
            return XCTFail("Expected .notConfigured, got \(result)")
        }
        XCTAssertTrue(
            reason.localizedCaseInsensitiveContains("malformed") || reason.contains("OktaIssuer"),
            "Reason should indicate malformed issuer URL, got: \(reason)"
        )
    }
}
