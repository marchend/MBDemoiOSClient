//
//  AppCoordinatorTests.swift
//  AcmeBankTests
//
//  Drives `AppCoordinator`'s cold-launch behaviour through fakes so
//  the test never touches the real Keychain or hits the network.
//
//  Pinned to `@MainActor` because `AppCoordinator` is `@MainActor`-
//  isolated (its `@Published var session` requires main-thread writes).
//

import XCTest
import Combine
@testable import AcmeBank

@MainActor
final class AppCoordinatorTests: XCTestCase {

    // MARK: - Fixtures

    private let configuredOkta: OktaConfig = .configured(
        issuer: URL(string: "https://example.okta.com/oauth2/default")!,
        clientID: "0oa1234567890abcdef",
        redirectURI: URL(string: "com.acmebank.mobile:/callback")!,
        scopes: "openid profile offline_access"
    )

    private let notConfiguredOkta: OktaConfig =
        .notConfigured(reason: "test: env vars unset")

    private func makeSession(userId: String = "00uABCDEF") -> UserSession {
        UserSession(
            userId: userId,
            displayName: "Ada Lovelace",
            email: "ada@example.com",
            accessToken: "test-access-token",
            authTimestamp: Date(timeIntervalSince1970: 2_000_000_000),
            deviceName: "Test Device"
        )
    }

    // MARK: - Fakes

    /// In-memory `KeychainStoring` fake. Avoids the real Keychain so
    /// tests are hermetic and parallel-safe.
    private final class FakeKeychain: KeychainStoring, @unchecked Sendable {
        var storedRefreshToken: String?
        var storedIDToken: String?
        var storedAccessToken: String?
        private(set) var clearAllCallCount = 0

        /// When non-nil, `loadRefreshToken` throws this error instead of
        /// reading `storedRefreshToken`. Lets a test simulate
        /// `errSecItemNotFound` / unexpected status without seeding.
        var loadError: KeychainError?

        func storeIDToken(_ token: String) throws { storedIDToken = token }
        func storeAccessToken(_ token: String) throws { storedAccessToken = token }
        func storeRefreshToken(_ token: String) throws { storedRefreshToken = token }

        func loadRefreshToken() throws -> String {
            if let loadError { throw loadError }
            guard let token = storedRefreshToken else { throw KeychainError.itemNotFound }
            return token
        }

        func clearAll() throws {
            clearAllCallCount += 1
            storedRefreshToken = nil
            storedIDToken = nil
            storedAccessToken = nil
        }
    }

    /// `AuthServicing` fake. Records calls; lets the test choose the
    /// `refresh` outcome.
    private final class FakeAuthService: AuthServicing, @unchecked Sendable {
        var nextRefreshResult: Result<UserSession, Error> =
            .failure(AuthError.unknown)

        private(set) var refreshCallCount = 0
        private(set) var receivedRefreshToken: String?
        private(set) var signInCallCount = 0

        func signIn(
            username: String,
            password: String,
            keepSignedIn: Bool
        ) async throws -> UserSession {
            signInCallCount += 1
            throw AuthError.unknown
        }

        func refresh(refreshToken: String) async throws -> UserSession {
            refreshCallCount += 1
            receivedRefreshToken = refreshToken
            return try nextRefreshResult.get()
        }
    }

    // MARK: - No refresh token \u2192 stays logged out

    func test_init_noRefreshTokenInKeychain_sessionIsNil_andRefreshNotCalled() async {
        let keychain = FakeKeychain()                 // empty
        let auth = FakeAuthService()

        let sut = AppCoordinator(
            oktaConfig: configuredOkta,
            authService: auth,
            keychain: keychain
        )

        // No bootstrap Task should have been started.
        XCTAssertNil(sut.bootstrapTask)
        XCTAssertNil(sut.session)
        XCTAssertEqual(auth.refreshCallCount, 0)
    }

    // MARK: - Keychain returns a token, refresh succeeds \u2192 session populated

    func test_init_refreshSucceeds_populatesSession() async {
        let keychain = FakeKeychain()
        keychain.storedRefreshToken = "stored-refresh-token"

        let auth = FakeAuthService()
        let expected = makeSession(userId: "00uREFRESHED")
        auth.nextRefreshResult = .success(expected)

        let sut = AppCoordinator(
            oktaConfig: configuredOkta,
            authService: auth,
            keychain: keychain
        )

        // Wait deterministically for the cold-launch Task instead of
        // polling. The stored handle resolves when the refresh completes.
        await sut.bootstrapTask?.value

        XCTAssertEqual(sut.session, expected)
        XCTAssertEqual(auth.refreshCallCount, 1)
        XCTAssertEqual(auth.receivedRefreshToken, "stored-refresh-token")
    }

    // MARK: - Refresh fails \u2192 session stays nil

    func test_init_refreshFails_sessionStaysNil() async {
        let keychain = FakeKeychain()
        keychain.storedRefreshToken = "stale-refresh-token"

        let auth = FakeAuthService()
        // `AuthService.refresh` clears the keychain itself on a 4xx;
        // here we only assert the coordinator's externally observable
        // behaviour: refresh was attempted, session is nil.
        auth.nextRefreshResult = .failure(AuthError.invalidCredentials)

        let sut = AppCoordinator(
            oktaConfig: configuredOkta,
            authService: auth,
            keychain: keychain
        )

        await sut.bootstrapTask?.value

        XCTAssertNil(sut.session)
        XCTAssertEqual(auth.refreshCallCount, 1)
    }

    // MARK: - `.notConfigured` short-circuits the entire refresh path

    func test_init_notConfigured_skipsRefreshEntirely() async {
        let keychain = FakeKeychain()
        // Even with a token in the keychain, .notConfigured must not
        // touch AuthService \u2014 there's no client ID to authenticate against.
        keychain.storedRefreshToken = "irrelevant-token"

        let auth = FakeAuthService()

        let sut = AppCoordinator(
            oktaConfig: notConfiguredOkta,
            authService: auth,
            keychain: keychain
        )

        // No bootstrap Task at all on the unconfigured path.
        XCTAssertNil(sut.bootstrapTask)
        XCTAssertNil(sut.session)
        XCTAssertEqual(auth.refreshCallCount, 0)
    }

    // MARK: - `.configured` but authService nil \u2192 skip refresh

    func test_init_configuredButNoAuthService_skipsRefresh() async {
        let keychain = FakeKeychain()
        keychain.storedRefreshToken = "stored-refresh-token"

        let sut = AppCoordinator(
            oktaConfig: configuredOkta,
            authService: nil,
            keychain: keychain
        )

        XCTAssertNil(sut.bootstrapTask)
        XCTAssertNil(sut.session)
    }

    // MARK: - signOut clears keychain and session

    func test_signOut_clearsKeychainAndSession() async {
        let keychain = FakeKeychain()
        keychain.storedRefreshToken = "stored-refresh-token"

        let auth = FakeAuthService()
        auth.nextRefreshResult = .success(makeSession())

        let sut = AppCoordinator(
            oktaConfig: configuredOkta,
            authService: auth,
            keychain: keychain
        )
        await sut.bootstrapTask?.value
        XCTAssertNotNil(sut.session, "precondition: session populated by refresh")

        sut.signOut()

        XCTAssertNil(sut.session)
        XCTAssertEqual(keychain.clearAllCallCount, 1)
        XCTAssertNil(keychain.storedRefreshToken)
    }
}
