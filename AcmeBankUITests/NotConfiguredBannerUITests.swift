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
            "Username field never appeared — the app may have crashed at launch."
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

        let bannerExpectation = expectation(
            description: "Not-configured banner appears within 5 s"
        )
        // Poll both element types every 0.1 s up to 5 s. We use a
        // poll loop (not XCUI's built-in `waitForExistence`) because
        // we don't know in advance which element class hosts the
        // combined accessibility element on this OS version.
        DispatchQueue.global().async {
            let deadline = Date().addingTimeInterval(5.0)
            while Date() < deadline {
                if bannerStatic.exists || bannerOther.exists {
                    bannerExpectation.fulfill()
                    return
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        wait(for: [bannerExpectation], timeout: 5.5)

        XCTAssertTrue(
            bannerStatic.exists || bannerOther.exists,
            "Not-configured banner with copy containing '\(needle)' never appeared."
        )
    }
}
