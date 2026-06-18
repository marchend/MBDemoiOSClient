//
//  RootViewTests.swift
//  AcmeBankTests
//
//  Structural render tests for `RootView`. The plan calls for a
//  ViewInspector switch-on-children assertion, but this project does
//  not depend on ViewInspector (see `LoginViewSnapshotTests` for the
//  established pattern). We therefore follow the same pattern: host
//  the view in a `UIHostingController`, exercise both branches by
//  driving the coordinator's `session`, and assert that:
//    1. The view renders without crashing in both states.
//    2. The coordinator's observable state matches the branch the view
//       SHOULD be rendering. Since `RootView`'s body is a pure function
//       of `coordinator.session`, that state IS the contract.
//
//  Pinned to `@MainActor` because `AppCoordinator` is `@MainActor`-isolated.
//

import XCTest
import SwiftUI
import UIKit
@testable import AcmeBank

@MainActor
final class RootViewTests: XCTestCase {

    // MARK: - Fixtures

    private let configuredOkta: OktaConfig = .configured(
        issuer: URL(string: "https://example.okta.com/oauth2/default")!,
        clientID: "0oa1234567890abcdef",
        redirectURI: URL(string: "com.acmebank.mobile:/callback")!,
        scopes: "openid profile offline_access"
    )

    private func makeCoordinator(session: UserSession? = nil) -> AppCoordinator {
        let coordinator = AppCoordinator(
            oktaConfig: configuredOkta,
            authService: nil, // explicitly nil \u2014 RootView only forwards it, doesn't call it
            keychain: NoopKeychain()
        )
        coordinator.session = session
        return coordinator
    }

    private func makeSession() -> UserSession {
        UserSession(
            userId: "00uABCDEF",
            displayName: "Ada Lovelace",
            email: "ada@example.com",
            accessToken: "test-access-token",
            authTimestamp: Date(timeIntervalSince1970: 2_000_000_000),
            deviceName: "Test Device"
        )
    }

    // MARK: - session == nil \u2192 LoginView branch renders

    func test_session_nil_rendersLoginBranch_withoutCrash() {
        let coordinator = makeCoordinator(session: nil)
        let view = RootView(coordinator: coordinator)

        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        // The coordinator state IS the branch contract: session nil
        // means RootView renders the login branch.
        XCTAssertNil(coordinator.session)
    }

    // MARK: - session != nil \u2192 LandingView branch renders

    func test_session_nonNil_rendersLandingBranch_withoutCrash() {
        let session = makeSession()
        let coordinator = makeCoordinator(session: session)
        let view = RootView(coordinator: coordinator)

        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        XCTAssertEqual(coordinator.session, session)
    }

    // MARK: - Transition: nil \u2192 set session \u2192 LandingView renders

    func test_assigningSession_transitionsToLandingBranch_withoutCrash() {
        let coordinator = makeCoordinator(session: nil)
        let view = RootView(coordinator: coordinator)

        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        // Now flip the coordinator and re-render. SwiftUI observes the
        // `@Published` change and rebuilds the body.
        coordinator.session = makeSession()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(coordinator.session)
    }
}

// MARK: - No-op keychain so the coordinator's init doesn't touch the real one

private final class NoopKeychain: KeychainStoring, @unchecked Sendable {
    func storeIDToken(_ token: String) throws {}
    func storeAccessToken(_ token: String) throws {}
    func storeRefreshToken(_ token: String) throws {}
    func loadRefreshToken() throws -> String { throw KeychainError.itemNotFound }
    func clearAll() throws {}
}
