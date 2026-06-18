import XCTest
import SwiftUI
import UIKit
@testable import AcmeBank

/// "Snapshot" tests for `LoginView` — implemented as structural render tests.
///
/// These tests instantiate `LoginView` with a given `LoginViewModel` state,
/// host it in a `UIHostingController`, and assert that:
///   1. The view renders without crashing (no crash = structural integrity).
///   2. The ViewModel holds the exact state that drives the rendering.
///
/// This approach is CI-safe: there are no PNG reference files to maintain and
/// no pixel-comparison that can drift between Xcode / simulator versions.
/// For pixel-accurate visual review, see the screenshots attached to the PR.
///
/// States covered:
///   (a) Default / empty — both fields blank, sign-in disabled.
///   (b) Both fields filled — sign-in enabled.
///   (c) Error banner visible — `errorMessage` is set.
///   (d) Password revealed — `isPasswordVisible` is `true`.
final class LoginViewSnapshotTests: XCTestCase {

    // MARK: - (a) Default / empty state

    func test_defaultEmptyState_rendersWithoutCrash() {
        let vm = LoginViewModel()

        let view = LoginView(viewModel: vm)
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        // ViewModel in expected initial state
        XCTAssertEqual(vm.username, "")
        XCTAssertEqual(vm.password, "")
        XCTAssertFalse(vm.isSignInEnabled)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isPasswordVisible)
        XCTAssertFalse(vm.keepSignedIn)
    }

    // MARK: - (b) Both fields filled — sign-in enabled

    func test_filledFieldsState_rendersWithoutCrash() {
        let vm = LoginViewModel()
        vm.username = "user@acmebank.com"
        vm.password = "password123"

        let view = LoginView(viewModel: vm)
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        // Sign-in should be enabled
        XCTAssertTrue(vm.isSignInEnabled)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isPasswordVisible)
    }

    // MARK: - (c) Error banner visible

    func test_errorBannerState_rendersWithoutCrash() {
        let vm = LoginViewModel()
        vm.username = "user@acmebank.com"
        vm.password = "wrongpassword"
        vm.errorMessage = "Your username or password is incorrect. Please try again."

        let view = LoginView(viewModel: vm)
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        // Error message should be present
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(
            vm.errorMessage,
            "Your username or password is incorrect. Please try again."
        )
        XCTAssertTrue(vm.isSignInEnabled)
    }

    // MARK: - (d) Password revealed

    func test_passwordRevealedState_rendersWithoutCrash() {
        let vm = LoginViewModel()
        vm.username = "user@acmebank.com"
        vm.password = "password123"
        vm.isPasswordVisible = true

        let view = LoginView(viewModel: vm)
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        XCTAssertTrue(vm.isPasswordVisible)
        XCTAssertTrue(vm.isSignInEnabled)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - ErrorBannerView renders correctly for nil vs non-nil message

    func test_errorBannerView_withMessage_rendersWithoutCrash() {
        let view = ErrorBannerView(message: "Login failed.")
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 100)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        // No assertion needed beyond "did not crash"
    }

    func test_errorBannerView_withNilMessage_rendersWithoutCrash() {
        let view = ErrorBannerView(message: nil)
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 100)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        // No assertion needed beyond "did not crash"
    }

    // MARK: - AcmeBankLogoView renders without crash

    func test_logoView_rendersWithoutCrash() {
        let view = AcmeBankLogoView()
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }

    // MARK: - OktaHeaderView and OktaFooterView render without crash

    func test_oktaHeaderView_rendersWithoutCrash() {
        let view = OktaHeaderView()
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 44)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }

    func test_oktaFooterView_rendersWithoutCrash() {
        let view = OktaFooterView()
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 44)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }
}
