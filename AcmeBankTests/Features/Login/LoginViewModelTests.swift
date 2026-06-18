import XCTest
@testable import AcmeBank

/// Pinned to `@MainActor` because `LoginViewModel.performSignIn()` is
/// `@MainActor` (so its `@Published` writes drive SwiftUI from the main
/// thread). Running the whole suite on the main actor sidesteps actor-
/// isolation warnings on every property read of the SUT.
@MainActor
final class LoginViewModelTests: XCTestCase {

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

    // MARK: - Test fakes

    /// In-target fake conforming to `AuthServicing`. Drives `signIn`
    /// outcomes deterministically and counts calls. Does NOT import
    /// the Okta SDK — the protocol seam is the whole point.
    ///
    /// Set `signInGate` to suspend the fake mid-call: the test can then
    /// observe in-flight state (e.g. `isSigningIn == true`) and resume
    /// the fake by calling `gate.open()`.
    private final class FakeAuthService: AuthServicing, @unchecked Sendable {
        var nextSignInResult: Result<UserSession, Error> =
            .failure(AuthError.unknown)

        private(set) var signInCallCount = 0
        private(set) var receivedUsername: String?
        private(set) var receivedPassword: String?
        private(set) var receivedKeepSignedIn: Bool?

        /// Optional async hook invoked once on entry to `signIn`. The
        /// fake suspends inside this hook before returning, so a test
        /// can hold the call open while it asserts mid-flight state.
        var signInGate: (@Sendable () async -> Void)?

        func signIn(
            username: String,
            password: String,
            keepSignedIn: Bool
        ) async throws -> UserSession {
            signInCallCount += 1
            receivedUsername = username
            receivedPassword = password
            receivedKeepSignedIn = keepSignedIn
            if let gate = signInGate {
                await gate()
            }
            return try nextSignInResult.get()
        }

        func refresh(refreshToken: String) async throws -> UserSession {
            // Not exercised by LoginViewModel.
            throw AuthError.unknown
        }
    }

    // MARK: - isSignInEnabled

    func test_isSignInEnabled_false_whenBothFieldsEmpty() {
        let sut = LoginViewModel()
        XCTAssertFalse(sut.isSignInEnabled)
    }

    func test_isSignInEnabled_false_whenOnlyUsernameSet() {
        let sut = LoginViewModel()
        sut.username = "user@acmebank.com"
        XCTAssertFalse(sut.isSignInEnabled)
    }

    func test_isSignInEnabled_false_whenOnlyPasswordSet() {
        let sut = LoginViewModel()
        sut.password = "secret"
        XCTAssertFalse(sut.isSignInEnabled)
    }

    func test_isSignInEnabled_true_whenBothFieldsNonEmpty() {
        let sut = LoginViewModel()
        sut.username = "user@acmebank.com"
        sut.password = "secret"
        XCTAssertTrue(sut.isSignInEnabled)
    }

    func test_isSignInEnabled_false_afterClearingUsername() {
        let sut = LoginViewModel()
        sut.username = "user@acmebank.com"
        sut.password = "secret"
        XCTAssertTrue(sut.isSignInEnabled)

        sut.username = ""
        XCTAssertFalse(sut.isSignInEnabled)
    }

    func test_isSignInEnabled_false_afterClearingPassword() {
        let sut = LoginViewModel()
        sut.username = "user@acmebank.com"
        sut.password = "secret"
        XCTAssertTrue(sut.isSignInEnabled)

        sut.password = ""
        XCTAssertFalse(sut.isSignInEnabled)
    }

    // MARK: - isPasswordVisible toggle

    func test_isPasswordVisible_startsAsFalse() {
        let sut = LoginViewModel()
        XCTAssertFalse(sut.isPasswordVisible)
    }

    func test_togglePasswordVisibility_setsTrue() {
        let sut = LoginViewModel()
        sut.togglePasswordVisibility()
        XCTAssertTrue(sut.isPasswordVisible)
    }

    func test_togglePasswordVisibility_setsFalse_whenCalledTwice() {
        let sut = LoginViewModel()
        sut.togglePasswordVisibility()
        sut.togglePasswordVisibility()
        XCTAssertFalse(sut.isPasswordVisible)
    }

    // MARK: - Initial state

    func test_errorMessage_startsAsNil() {
        let sut = LoginViewModel()
        XCTAssertNil(sut.errorMessage)
    }

    func test_keepSignedIn_startsAsFalse() {
        let sut = LoginViewModel()
        XCTAssertFalse(sut.keepSignedIn)
    }

    func test_username_startsEmpty() {
        let sut = LoginViewModel()
        XCTAssertEqual(sut.username, "")
    }

    func test_password_startsEmpty() {
        let sut = LoginViewModel()
        XCTAssertEqual(sut.password, "")
    }

    func test_isSigningIn_startsAsFalse() {
        let sut = LoginViewModel()
        XCTAssertFalse(sut.isSigningIn)
    }

    // MARK: - .notConfigured path

    func test_performSignIn_notConfigured_setsBannerCopy_andNeverCallsAuthService() async {
        let fake = FakeAuthService()
        // Even though we pass a fake, the .notConfigured guard must
        // short-circuit before AuthService is touched. We pass the fake
        // explicitly so a regression (calling AuthService on a
        // misconfigured build) would be loud.
        let sut = LoginViewModel(
            authService: fake,
            oktaConfig: notConfiguredOkta,
            onAuthenticated: { _ in }
        )
        sut.username = "user@acmebank.com"
        sut.password = "secret"

        await sut.performSignIn()

        XCTAssertEqual(
            sut.errorMessage,
            "Okta is not configured on this build — see README."
        )
        XCTAssertEqual(fake.signInCallCount, 0)
        XCTAssertFalse(sut.isSigningIn)
    }

    func test_performSignIn_notConfigured_withNilAuthService_setsBannerCopy() async {
        // The composition root passes `authService: nil` on the
        // unconfigured build path. Verify the guard handles that too.
        let sut = LoginViewModel(
            authService: nil,
            oktaConfig: notConfiguredOkta,
            onAuthenticated: { _ in }
        )
        sut.username = "user@acmebank.com"
        sut.password = "secret"

        await sut.performSignIn()

        XCTAssertEqual(
            sut.errorMessage,
            "Okta is not configured on this build — see README."
        )
    }

    // MARK: - isSigningIn toggling

    func test_performSignIn_togglesIsSigningIn_aroundAsyncCall() async {
        let fake = FakeAuthService()
        fake.nextSignInResult = .success(makeSession())

        // Hold the fake inside `signIn` until we open the gate, so the
        // test can observe `isSigningIn == true` mid-flight.
        let gate = AsyncGate()
        fake.signInGate = { await gate.wait() }

        var onAuthenticatedCalled = false
        let sut = LoginViewModel(
            authService: fake,
            oktaConfig: configuredOkta,
            onAuthenticated: { _ in onAuthenticatedCalled = true }
        )
        sut.username = "user@acmebank.com"
        sut.password = "secret"

        let task = Task { await sut.performSignIn() }

        // Wait for the call to enter the fake (isSigningIn flips).
        await waitForCondition(timeout: 2.0) { sut.isSigningIn }
        XCTAssertTrue(sut.isSigningIn)
        XCTAssertEqual(fake.signInCallCount, 1)

        // Let the fake return and the ViewModel finish.
        gate.open()
        await task.value

        XCTAssertFalse(sut.isSigningIn, "isSigningIn should clear on return")
        XCTAssertTrue(onAuthenticatedCalled)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Error copy mapping (verbatim per spec)

    func test_performSignIn_invalidCredentials_setsExactCopy() async {
        let fake = FakeAuthService()
        fake.nextSignInResult = .failure(AuthError.invalidCredentials)

        let sut = LoginViewModel(
            authService: fake,
            oktaConfig: configuredOkta,
            onAuthenticated: { _ in XCTFail("onAuthenticated should not fire on failure") }
        )
        sut.username = "user@acmebank.com"
        sut.password = "wrong"

        await sut.performSignIn()

        XCTAssertEqual(
            sut.errorMessage,
            "Incorrect username or password. Please try again."
        )
        XCTAssertFalse(sut.isSigningIn)
    }

    func test_performSignIn_network_setsExactCopy() async {
        let fake = FakeAuthService()
        fake.nextSignInResult = .failure(AuthError.network)

        let sut = LoginViewModel(
            authService: fake,
            oktaConfig: configuredOkta,
            onAuthenticated: { _ in XCTFail("onAuthenticated should not fire on failure") }
        )
        sut.username = "user@acmebank.com"
        sut.password = "secret"

        await sut.performSignIn()

        XCTAssertEqual(
            sut.errorMessage,
            "Couldn't reach Okta — check your connection and try again."
        )
    }

    func test_performSignIn_mfaRequired_setsExactCopy() async {
        let fake = FakeAuthService()
        fake.nextSignInResult = .failure(AuthError.mfaRequired)

        let sut = LoginViewModel(
            authService: fake,
            oktaConfig: configuredOkta,
            onAuthenticated: { _ in XCTFail("onAuthenticated should not fire on failure") }
        )
        sut.username = "user@acmebank.com"
        sut.password = "secret"

        await sut.performSignIn()

        XCTAssertEqual(
            sut.errorMessage,
            "MFA is required but not supported in this build."
        )
    }

    // MARK: - Error banner clears on field edit

    func test_editingUsername_clearsErrorMessage() {
        let sut = LoginViewModel()
        sut.errorMessage = "Something went wrong."

        sut.username = "n"

        XCTAssertNil(sut.errorMessage)
    }

    func test_editingPassword_clearsErrorMessage() {
        let sut = LoginViewModel()
        sut.errorMessage = "Something went wrong."

        sut.password = "p"

        XCTAssertNil(sut.errorMessage)
    }

    func test_usernameDidChange_clearsErrorMessage() {
        let sut = LoginViewModel()
        sut.errorMessage = "boom"
        sut.usernameDidChange()
        XCTAssertNil(sut.errorMessage)
    }

    func test_passwordDidChange_clearsErrorMessage() {
        let sut = LoginViewModel()
        sut.errorMessage = "boom"
        sut.passwordDidChange()
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Double-tap protection

    func test_performSignIn_doubleTap_doesNotFireTwoConcurrentSignIns() async {
        let fake = FakeAuthService()
        fake.nextSignInResult = .success(makeSession())

        // Gate the in-flight call so we can fire a second performSignIn
        // while the first is still suspended.
        let gate = AsyncGate()
        fake.signInGate = { await gate.wait() }

        let sut = LoginViewModel(
            authService: fake,
            oktaConfig: configuredOkta,
            onAuthenticated: { _ in }
        )
        sut.username = "user@acmebank.com"
        sut.password = "secret"

        let first = Task { await sut.performSignIn() }

        // Wait until the first call has entered the fake (isSigningIn is true).
        await waitForCondition(timeout: 2.0) { sut.isSigningIn }
        XCTAssertEqual(fake.signInCallCount, 1)

        // Second tap while the first is still in flight — must be a no-op.
        await sut.performSignIn()
        XCTAssertEqual(
            fake.signInCallCount,
            1,
            "Second performSignIn while one is in flight must NOT call AuthService again"
        )

        gate.open()
        await first.value

        XCTAssertFalse(sut.isSigningIn)
        XCTAssertEqual(fake.signInCallCount, 1)
    }

    // MARK: - Happy path forwards form values + invokes onAuthenticated

    func test_performSignIn_success_invokesOnAuthenticated_withForwardedFormValues() async {
        let fake = FakeAuthService()
        let expectedSession = makeSession(userId: "00uXYZ")
        fake.nextSignInResult = .success(expectedSession)

        var receivedSession: UserSession?
        let sut = LoginViewModel(
            authService: fake,
            oktaConfig: configuredOkta,
            onAuthenticated: { receivedSession = $0 }
        )
        sut.username = "user@acmebank.com"
        sut.password = "secret123"
        sut.keepSignedIn = true

        await sut.performSignIn()

        XCTAssertEqual(fake.receivedUsername, "user@acmebank.com")
        XCTAssertEqual(fake.receivedPassword, "secret123")
        XCTAssertEqual(fake.receivedKeepSignedIn, true)
        XCTAssertEqual(receivedSession, expectedSession)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isSigningIn)
    }

    // MARK: - signInTapped fire-and-forget wrapper

    func test_signInTapped_eventuallyCallsAuthService_whenConfigured() async {
        let fake = FakeAuthService()
        fake.nextSignInResult = .success(makeSession())
        let sut = LoginViewModel(
            authService: fake,
            oktaConfig: configuredOkta,
            onAuthenticated: { _ in }
        )
        sut.username = "user@acmebank.com"
        sut.password = "secret"

        sut.signInTapped()

        await waitForCondition(timeout: 2.0) { fake.signInCallCount == 1 }
        await waitForCondition(timeout: 2.0) { !sut.isSigningIn }
        XCTAssertEqual(fake.signInCallCount, 1)
    }

    // MARK: - Helpers

    /// Polls `condition` until it returns `true` or the timeout elapses.
    /// Used to wait for `@Published` state changes set inside an async
    /// task to become observable to the test.
    private func waitForCondition(
        timeout: TimeInterval,
        _ condition: () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 5_000_000) // 5 ms
        }
        XCTFail("Condition not met within \(timeout)s", file: file, line: line)
    }
}

// MARK: - AsyncGate

/// Tiny single-shot async gate. Producer calls `await wait()`; consumer
/// calls `open()` to release. Used by the fake AuthService to hold a
/// `signIn` call open while the test asserts mid-flight state.
private final class AsyncGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            lock.lock()
            if isOpen {
                lock.unlock()
                cont.resume()
            } else {
                waiters.append(cont)
                lock.unlock()
            }
        }
    }

    func open() {
        lock.lock()
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        lock.unlock()
        for cont in pending { cont.resume() }
    }
}
