//
//  NotConfiguredBannerUITests.swift
//  AcmeBankUITests
//
//  Verifies the `.notConfigured` UX path: when the app was built
//  without the four `OKTA_*` env vars set, tapping Sign In must
//  surface a banner that explicitly says Okta is not configured \u2014
//  NOT a misleading network or credential error.
//
//  Skipped when the build IS Okta-configured (the e2e test in
//  `SignInToLandingUITests` covers that branch instead).
//

import XCTest

final class NotConfiguredBannerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_notConfigured_showsBanner() throws {
        try XCTSkipIf(
            oktaIsConfigured(),
            "Skipping not-configured banner test: build IS Okta-configured."
        )

        let app = XCUIApplication()
        app.launch()

        // Sign-in is gated on both fields being non-empty, so type
        // something into each. The values are irrelevant \u2014 the
        // .notConfigured guard in LoginViewModel.performSignIn fires
        // before the credentials are ever read.
        let usernameField = app.textFields["usernameField"]
        XCTAssertTrue(
            usernameField.waitForExistence(timeout: 5),
            "Username field never appeared \u2014 the app may have crashed at launch."
        )
        usernameField.tap()
        usernameField.typeText("not-a-real-user")

        let passwordField: XCUIElement = {
            let secure = app.secureTextFields["passwordField"]
            if secure.exists { return secure }
            return app.textFields["passwordField"]
        }()
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText("not-a-real-password")

        let signInButton = app.buttons["signInButton"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        signInButton.tap()

        // ErrorBannerView combines its children into a single
        // accessibility element labelled `"Error: <message>"` (see
        // ErrorBannerView.swift). XCUITest exposes the resulting
        // element under both `staticTexts` and `otherElements`
        // depending on the OS; query by a stable substring of the
        // copy LoginViewModel produces.
        let needle = "Okta is not configured on this build"

        let bannerPredicate = NSPredicate(format: "label CONTAINS[c] %@", needle)

        let bannerStatic = app.staticTexts.matching(bannerPredicate).firstMatch
        let bannerOther = app.otherElements.matching(bannerPredicate).firstMatch

        // Wait for the banner to appear on the test thread using
        // `waitForExistence`, which is the supported XCTest API for
        // this (it polls on the test thread and is safe to call from
        // the main thread). We don't know in advance which element
        // class hosts the combined accessibility element on this OS
        // version, so we try both:
        //
        //   - If `bannerStatic` materialises within 5 s, the first
        //     call returns `true` and the second short-circuits
        //     immediately (its `.exists` is already `true`, so
        //     `waitForExistence` returns without further polling).
        //   - If `bannerStatic` never appears, the first call burns
        //     its full 5 s budget and we then give `bannerOther` its
        //     own budget.
        //
        // This replaces an earlier `DispatchQueue.global().async` poll
        // that called `.exists` from a background thread \u2014 unsupported
        // by XCTest and a documented source of CI flakiness.
        let appeared =
            bannerStatic.waitForExistence(timeout: 5)
            || bannerOther.waitForExistence(timeout: 5)

        XCTAssertTrue(
            appeared,
            "Not-configured banner with copy containing '\(needle)' never appeared."
        )
    }
}
