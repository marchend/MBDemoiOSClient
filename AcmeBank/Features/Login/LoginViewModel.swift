import Foundation

/// ViewModel for the Login screen.
///
/// Holds all form state as `@Published` properties so `LoginView` can bind
/// to them reactively. Closure properties (`onSignIn`, `onNeedHelp`) let the
/// owning coordinator inject navigation without coupling the ViewModel to
/// SwiftUI or UIKit.
final class LoginViewModel: ObservableObject {

    // MARK: - Published form state

    @Published var username: String = ""
    @Published var password: String = ""
    @Published var keepSignedIn: Bool = false
    @Published var isPasswordVisible: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Computed state

    /// Sign-in button is enabled only when both fields contain text.
    var isSignInEnabled: Bool {
        !username.isEmpty && !password.isEmpty
    }

    // MARK: - Closure injection points (set by the coordinator)

    /// Called when the user taps "Sign in". Passes (username, password, keepSignedIn).
    var onSignIn: (String, String, Bool) -> Void = { _, _, _ in }

    /// Called when the user taps "Need help?".
    var onNeedHelp: () -> Void = {}

    // MARK: - Actions

    /// Forwards the current form values to the `onSignIn` closure.
    func signInTapped() {
        onSignIn(username, password, keepSignedIn)
    }

    /// Toggles password field visibility.
    func togglePasswordVisibility() {
        isPasswordVisible.toggle()
    }
}
