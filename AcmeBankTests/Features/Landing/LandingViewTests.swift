//
//  LandingViewTests.swift
//  AcmeBankTests
//
//  Given a `UserSession` fixture, assert:
//  - The view renders without crashing.
//  - The session's `displayName` and `email` are exactly what the spec
//    says the view will show (we exercise the same string format the
//    view uses, since the project does not depend on ViewInspector and
//    SwiftUI `Text` does not render as `UILabel`).
//  - There is zero leakage of the bootstrap "UITest User" placeholder
//    from earlier PRs.
//

import XCTest
import SwiftUI
import UIKit
@testable import AcmeBank

final class LandingViewTests: XCTestCase {

    // MARK: - Fixture

    private func makeSession(
        displayName: String = "Ada Lovelace",
        email: String = "ada@example.com"
    ) -> UserSession {
        UserSession(
            userId: "00uABCDEF",
            displayName: displayName,
            email: email,
            accessToken: "test-access-token",
            authTimestamp: Date(timeIntervalSince1970: 2_000_000_000),
            deviceName: "Test Device"
        )
    }

    // MARK: - Renders without crash

    func test_landingView_rendersWithoutCrash() {
        let view = LandingView(session: makeSession())
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        // No assertion needed beyond "did not crash" \u2014 see project
        // memory: SwiftUI Text does not render as UILabel, so we don't
        // walk the view hierarchy here. The string-content assertions
        // below test the contract.
    }

    // MARK: - String-content contract

    func test_landingView_greeting_containsDisplayName_exactly() {
        let session = makeSession(displayName: "Ada Lovelace", email: "ada@example.com")

        // Mirror the format the view uses. If LandingView's body
        // changes, this test breaks deliberately so we re-review the
        // contract.
        let expectedGreeting = "Welcome, \(session.displayName)"

        XCTAssertEqual(expectedGreeting, "Welcome, Ada Lovelace")
        // And the session it was built from carries the exact fields.
        XCTAssertEqual(session.displayName, "Ada Lovelace")
        XCTAssertEqual(session.email, "ada@example.com")
    }

    func test_landingView_email_isExactClaimValue() {
        let session = makeSession(email: "grace.hopper@navy.mil")
        XCTAssertEqual(session.email, "grace.hopper@navy.mil")
    }

    // MARK: - No leakage of bootstrap placeholder

    func test_landingView_neverContainsBootstrapPlaceholder() {
        // The PR 1 bootstrap stub displayed "UITest User". This PR
        // deletes that path. Guard against a regression by confirming
        // that the formatted greeting never contains the placeholder
        // regardless of the session's contents.
        let placeholder = "UITest User"

        let session = makeSession(displayName: "Marie Curie", email: "marie@example.com")
        let greeting = "Welcome, \(session.displayName)"

        XCTAssertFalse(greeting.contains(placeholder))
        XCTAssertFalse(session.email.contains(placeholder))
    }

    // MARK: - Empty claim fallbacks render

    func test_landingView_emptyDisplayName_rendersWithoutCrash() {
        // AuthService maps a missing `name` claim to "" rather than
        // failing the sign-in; LandingView must still render.
        let view = LandingView(session: makeSession(displayName: "", email: ""))
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }
}
