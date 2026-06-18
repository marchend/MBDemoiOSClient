import Foundation

/// ViewModel for the Login screen.
///
/// Holds all form state as `@Published` properties so `LoginView` can bind
/// to them reactively. The ViewModel itself drives the Okta DirectAuth
/// sign-in via the injected `AuthServicing`; the owning coordinator
/// receives the resulting `UserSession` through the `onAuthenticated`
/// closure (decoupling routing from this layer).
///
/// Build-time configuration is observed through `OktaConfig`:
///   - `.configured(...)` → sign-in is performed via `authService`.
///   - `.notConfigured(...)` → `AuthService` is never called and the
///     error banner explains that the build is missing Okta keys. This
///     keeps the simulator / CI build usable without secrets and makes
///     the misconfiguration visible inside the app.
final class LoginViewModel: ObservableObject {

    // MARK: - Published form state

    /// Setting this clears any previous error banner so the user sees the
    /// banner disappear the moment they start correcting the input.
    /// `didSet` does not fire during `init`, so the empty-string default
    /// assignment is safe.
    @Published var username: String = "" {
        didSet { if username != oldValue { usernameDidChange() } }
    }

    @Published var password: String = "" {
        didSet { if password != oldValue { passwordDidChange() } }
    }

    @Published var keepSignedIn: Bool = false
    @Published var isPasswordVisible: Bool = false
    @Published var errorMessage: String? = nil

    /// `true` while an `AuthService.signIn` call is in flight. The view
    /// uses this to disable the fields + Sign-In button and swap the
    /// button label for a `ProgressView`.
    @Published var isSigningIn: Bool = false

    // MARK: - Computed state

    /// Sign-in button is enabled only when both fields contain text.
    var isSignInEnabled: Bool {
        !username.isEmpty && !password.isEmpty
    }

    // MARK: - Dependencies

    /// `nil` when `OktaConfig` is `.notConfigured` — the composition
    /// root passes `nil` for the unconfigured build path so this layer
    /// never tries to call into an SDK that has no client ID.
    private let authService: AuthServicing?
    private let oktaConfig: OktaConfig
    private let onAuthenticated: (UserSession) -> Void

    /// Handle for the in-flight `signInTapped` Task, retained so we can
    /// cancel it in `deinit` if the ViewModel is torn down mid-flight
    /// (e.g. a coordinator pops the login screen while Okta is still
    /// thinking). Without this, the unstructured `Task` would keep a
    /// strong reference to `self` — and to `onAuthenticated` — alive
    /// until the network call resolves, which is a real leak once the
    /// login screen is no longer a root view.
    private var signInTask: Task<Void, Never>?

    // MARK: - Closure injection points (set by the coordinator)

    /// Called when the user taps "Need help?".
    var onNeedHelp: () -> Void = {}

    // MARK: - Init

    /// Designated initialiser.
    ///
    /// - Parameters:
    ///   - authService: pass `nil` when `oktaConfig` is `.notConfigured`.
    ///     The ViewModel will refuse to call into auth in that case and
    ///     publish the not-configured banner copy instead.
    ///   - oktaConfig: build-time Okta configuration outcome. Defaults
    ///     to `.notConfigured` so the previews and snapshot tests that
    ///     call `LoginViewModel()` continue to work — they never tap
    ///     sign-in.
    ///   - onAuthenticated: invoked with the resulting `UserSession`
    ///     after a successful sign-in. The coordinator should use this
    ///     to swap the root to the post-login experience.
    init(
        authService: AuthServicing? = nil,
        oktaConfig: OktaConfig = .notConfigured(reason: "No OktaConfig was provided to LoginViewModel."),
        onAuthenticated: @escaping (UserSession) -> Void = { _ in }
    ) {
        self.authService = authService
        self.oktaConfig = oktaConfig
        self.onAuthenticated = onAuthenticated
    }

    deinit {
        // Cancel any in-flight sign-in task so we don't keep `self` and
        // `onAuthenticated` alive past dismissal. Safe to call on a
        // completed task — it's a no-op.
        signInTask?.cancel()
    }

    // MARK: - Actions

    /// Entry point bound to the Sign-In button. Kicks off the async
    /// sign-in flow on the main actor. We expose the async worker
    /// separately (`performSignIn`) so unit tests can `await` it
    /// deterministically without relying on Task scheduling.
    ///
    /// The task handle is retained on `signInTask` so `deinit` can
    /// cancel it if the ViewModel is torn down mid-flight; the closure
    /// captures `self` weakly to avoid an unstructured strong-reference
    /// cycle for the duration of the network call.
    func signInTapped() {
        signInTask?.cancel()
        signInTask = Task { [weak self] in
            await self?.performSignIn()
        }
    }

    /// Async sign-in worker. Pinned to `@MainActor` so the `@Published`
    /// writes (`isSigningIn`, `errorMessage`) drive SwiftUI updates from
    /// the main thread — SwiftUI logs "Publishing changes from
    /// background threads" otherwise. Exposed `internal` (not `private`)
    /// so the test target can await it directly.
    @MainActor
    func performSignIn() async {
        // Build-time guard: a build without Okta keys must surface the
        // misconfiguration in-app and must NOT call into AuthService.
        guard case .configured = oktaConfig else {
            errorMessage = "Okta is not configured on this build — see README."
            return
        }

        // Composition-root invariant: `.configured` MUST be paired with
        // a non-nil `authService`. The type system can't enforce this,
        // so we make a wiring bug loudly visible in debug builds rather
        // than silently surfacing the misleading "not configured" copy.
        guard let authService else {
            assertionFailure("authService is nil despite oktaConfig == .configured — composition-root wiring bug")
            errorMessage = Self.copy(for: .unknown)
            return
        }

        // Re-entrancy guard: prevents double-tap from issuing a second
        // network call while the first is still in flight.
        guard !isSigningIn else { return }

        isSigningIn = true
        defer { isSigningIn = false }

        // Snapshot the form values up-front so a late field edit can't
        // mutate what we send to Okta mid-flight.
        let snapshotUsername = username
        let snapshotPassword = password
        let snapshotKeepSignedIn = keepSignedIn

        do {
            let session = try await authService.signIn(
                username: snapshotUsername,
                password: snapshotPassword,
                keepSignedIn: snapshotKeepSignedIn
            )
            onAuthenticated(session)
        } catch let error as AuthError {
            errorMessage = Self.copy(for: error)
        } catch {
            // Defensive: AuthService is contracted to throw `AuthError`
            // only. If anything else escapes we still show the generic
            // copy rather than crash.
            errorMessage = Self.copy(for: .unknown)
        }
    }

    /// Called whenever the username field's text changes. Clears any
    /// previously displayed error banner so the user gets immediate
    /// feedback that they're correcting the input.
    func usernameDidChange() {
        errorMessage = nil
    }

    /// Called whenever the password field's text changes. Clears any
    /// previously displayed error banner (see `usernameDidChange`).
    func passwordDidChange() {
        errorMessage = nil
    }

    /// Toggles password field visibility.
    func togglePasswordVisibility() {
        isPasswordVisible.toggle()
    }

    // MARK: - AuthError → user-facing copy

    /// Single source of truth for the strings we render in the error
    /// banner. Kept here (not on `AuthError`) so the typed error stays
    /// presentation-agnostic and so the copy can be reviewed alongside
    /// the rest of the login UX in one place.
    private static func copy(for error: AuthError) -> String {
        switch error {
        case .invalidCredentials:
            return "Incorrect username or password. Please try again."
        case .network:
            return "Couldn't reach Okta — check your connection and try again."
        case .mfaRequired:
            return "MFA is required but not supported in this build."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}
