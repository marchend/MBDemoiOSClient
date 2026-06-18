//
//  SignInToLandingUITests.swift
//  AcmeBankUITests
//
//  End-to-end XCUITest that drives a real sign-in against the
//  configured Okta tenant and verifies the app lands on `LandingView`.
//
//  Skipped automatically when the build is not Okta-configured (any of
//  the four `OKTA_*` env vars unset at build time) or when the test
//  runner doesn't have `OKTA_TEST_USERNAME` / `OKTA_TEST_PASSWORD`
//  injected. Both skip conditions are expected on local dev machines
//  and on CI runs that don't have access to the test tenant.
//

import XCTest

final class SignInToLandingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_signIn_navigatesToLanding() throws {
        // Skip-by-design when the build can't possibly succeed:
        // - Okta config missing  \u2192 LoginView's `signInTapped` short-circuits
        //   to the not-configured banner (covered by NotConfiguredBannerUITests).
        // - Test creds missing   \u2192 nothing to type.
        try XCTSkipUnless(
            oktaIsConfigured(),
            "Skipping end-to-end sign-in test: app was built without OKTA_* env vars set."
        )
        guard let username = oktaTestUsername(),
              let password = oktaTestPassword() else {
            throw XCTSkip("Skipping end-to-end sign-in test: OKTA_TEST_USERNAME / OKTA_TEST_PASSWORD not set on the test runner.")
        }

        let app = XCUIApplication()
        app.launch()

        // Locate the form fields by the accessibility identifiers
        // LoginView exposes (see LoginView.swift, PR 1).
        let usernameField = app.textFields["usernameField"]
        XCTAssertTrue(
            usernameField.waitForExistence(timeout: 10),
            "Username field never appeared \u2014 the app may have crashed at launch."
        )
        usernameField.tap()
        usernameField.typeText(username)

        // The password field is a SecureTextField when hidden and a
        // TextField when revealed; query both so the test works
        // regardless of the eye-toggle's default state.
        let passwordField: XCUIElement = {
            let secure = app.secureTextFields["passwordField"]
            if secure.exists { return secure }
            return app.textFields["passwordField"]
        }()
        XCTAssertTrue(
            passwordField.waitForExistence(timeout: 5),
            "Password field never appeared."
        )
        passwordField.tap()
        passwordField.typeText(password)

        // Tap Sign In.
        let signInButton = app.buttons["signInButton"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        signInButton.tap()

        // The end-to-end contract: after a successful Okta sign-in the
        // app navigates to LandingView and renders the welcome greeting
        // populated from real ID-token claims. 10 s timeout to absorb
        // tenant latency.
        let welcomeGreeting = app.staticTexts["welcomeGreeting"]
        XCTAssertTrue(
            welcomeGreeting.waitForExistence(timeout: 10),
            "welcomeGreeting did not appear within 10 s after Sign In tap \u2014 sign-in flow broken."
        )

        // Email element exists too (no timeout needed: greeting and
        // email are siblings in LandingView, so the element appears
        // in the same SwiftUI render pass).
        let welcomeEmail = app.staticTexts["welcomeEmail"]
        XCTAssertTrue(welcomeEmail.exists, "welcomeEmail not found on LandingView.")
    }
}
