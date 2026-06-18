import XCTest
@testable import AcmeBank

final class LoginViewModelTests: XCTestCase {

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

    // MARK: - signInTapped / onSignIn closure

    func test_signInTapped_invokesOnSignInClosure_withCurrentFormValues() {
        let sut = LoginViewModel()
        sut.username = "user@acmebank.com"
        sut.password = "secret123"
        sut.keepSignedIn = true

        var receivedUsername: String?
        var receivedPassword: String?
        var receivedKeepSignedIn: Bool?
        sut.onSignIn = { u, p, k in
            receivedUsername = u
            receivedPassword = p
            receivedKeepSignedIn = k
        }

        sut.signInTapped()

        XCTAssertEqual(receivedUsername, "user@acmebank.com")
        XCTAssertEqual(receivedPassword, "secret123")
        XCTAssertEqual(receivedKeepSignedIn, true)
    }

    func test_signInTapped_invokesOnSignInClosure_withKeepSignedIn_false_byDefault() {
        let sut = LoginViewModel()
        sut.username = "user@acmebank.com"
        sut.password = "secret"

        var receivedKeepSignedIn: Bool?
        sut.onSignIn = { _, _, k in receivedKeepSignedIn = k }

        sut.signInTapped()

        XCTAssertEqual(receivedKeepSignedIn, false)
    }

    func test_signInTapped_doesNotCrash_whenOnSignInIsDefaultNoOp() {
        let sut = LoginViewModel()
        sut.username = "user@acmebank.com"
        sut.password = "secret"
        // onSignIn is the default no-op; tapping should not crash.
        sut.signInTapped()
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

    // MARK: - errorMessage initial state

    func test_errorMessage_startsAsNil() {
        let sut = LoginViewModel()
        XCTAssertNil(sut.errorMessage)
    }

    func test_errorMessage_canBeSetAndRead() {
        let sut = LoginViewModel()
        sut.errorMessage = "Something went wrong."
        XCTAssertEqual(sut.errorMessage, "Something went wrong.")
    }

    func test_errorMessage_canBeClearedToNil() {
        let sut = LoginViewModel()
        sut.errorMessage = "Some error"
        sut.errorMessage = nil
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - keepSignedIn initial state

    func test_keepSignedIn_startsAsFalse() {
        let sut = LoginViewModel()
        XCTAssertFalse(sut.keepSignedIn)
    }

    // MARK: - Default username / password

    func test_username_startsEmpty() {
        let sut = LoginViewModel()
        XCTAssertEqual(sut.username, "")
    }

    func test_password_startsEmpty() {
        let sut = LoginViewModel()
        XCTAssertEqual(sut.password, "")
    }
}
