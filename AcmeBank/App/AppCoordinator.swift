//
//  AppCoordinator.swift
//  AcmeBank
//
//  Composition-root coordinator. Owns the optional `UserSession` that
//  drives `RootView`'s auth-state switch, plus the (optional)
//  `AuthServicing` used to (a) try a cold-launch refresh-token grant
//  and (b) feed the `LoginView` ViewModel.
//
//  Why an `ObservableObject` and not a singleton:
//  - `AppCoordinator` is constructed once at `@main` AcmeBankApp time
//    and injected into the SwiftUI environment. Views read it via
//    `@EnvironmentObject` / `@ObservedObject`; there are no global
//    accessors. This keeps tests honest (every test builds its own
//    coordinator with fakes).
//
//  Why `@MainActor` on the class:
//  - `session` is `@Published`; mutations must come from the main
//    actor to drive SwiftUI updates from the main thread. Pinning the
//    class lets the cold-launch refresh Task assign `session` without
//    a hop, and removes "publishing changes from background threads"
//    runtime warnings.
//
//  Cold-launch refresh contract:
//  - If `OktaConfig` is `.configured` AND `KeychainStore.loadRefreshToken()`
//    returns a non-nil token, we kick off `authService.refresh(...)`.
//    Success \u2192 `session` is populated and `RootView` renders the
//    `LandingView` directly (no login screen flash).
//    Failure \u2192 `session` stays nil. `AuthService.refresh` is already
//    responsible for clearing the keychain on a 4xx (stale token); we
//    do NOT clear it again here on transport failures, because the
//    refresh token may still be valid and a flaky launch must not
//    destroy a "keep me signed in" session.
//  - `.notConfigured` short-circuits the entire refresh path \u2014 no
//    AuthService, no keychain read, no Task.
//

import Foundation
import Combine
import os

@MainActor
public final class AppCoordinator: ObservableObject {

    /// Observed by `RootView`. `nil` \u2192 show `LoginView`; non-nil \u2192 show `LandingView`.
    @Published public var session: UserSession?

    /// Build-time Okta configuration outcome, captured at construction
    /// time. Used by `RootView` to (a) decide whether to wire a real
    /// `AuthServicing` into the `LoginViewModel` and (b) show the
    /// not-configured banner when the user taps Sign In on a build with
    /// no Okta secrets.
    public let oktaConfig: OktaConfig

    /// `nil` when `oktaConfig` is `.notConfigured`. The composition root
    /// (and unit tests) construct the concrete `AuthService` from the
    /// `.configured(...)` payload and pass it in here.
    public let authService: AuthServicing?

    /// Persistent token store, retained so `signOut()` can clear it.
    private let keychain: KeychainStoring

    /// Handle to the cold-launch refresh Task so tests can `await` it
    /// deterministically rather than poll. `nil` when the refresh path
    /// did not run (no token in keychain, or `.notConfigured`).
    public private(set) var bootstrapTask: Task<Void, Never>?

    /// Subsystem-scoped logger so sign-out failures are searchable in
    /// Console.app / `log stream --predicate 'subsystem == "..."'`
    /// during QA and staging without leaking to release stdout.
    private static let log = Logger(
        subsystem: "com.acmebank.AcmeBank",
        category: "AppCoordinator"
    )

    // MARK: - Init

    /// Designated init.
    ///
    /// - Parameters:
    ///   - oktaConfig: build-time Okta config outcome.
    ///   - authService: pass `nil` on the `.notConfigured` build path.
    ///   - keychain: the same `KeychainStoring` impl `AuthService` writes to.
    public init(
        oktaConfig: OktaConfig,
        authService: AuthServicing?,
        keychain: KeychainStoring
    ) {
        self.oktaConfig = oktaConfig
        self.authService = authService
        self.keychain = keychain
        self.bootstrapTask = startBootstrapIfNeeded()
    }

    // MARK: - Cold-launch refresh

    /// Returns the Task we kicked off so tests (and `init`) can store a
    /// handle to it. Returns `nil` when there is nothing to do:
    /// `.notConfigured`, missing `authService`, or no refresh token in
    /// the keychain.
    private func startBootstrapIfNeeded() -> Task<Void, Never>? {
        // `.notConfigured` short-circuits the whole refresh path.
        guard case .configured = oktaConfig else { return nil }
        guard let authService else { return nil }

        // Read the refresh token off the main actor synchronously \u2014
        // it's a single Keychain call and we need its result to decide
        // whether to spin up the Task at all.
        let refreshToken: String?
        do {
            refreshToken = try keychain.loadRefreshToken()
        } catch {
            // `itemNotFound` is the common case (user never opted into
            // "Keep me signed in"); any other failure is treated the
            // same \u2014 stay logged out. `AuthService` does NOT see the
            // error, so it can't accidentally wipe other keychain items.
            refreshToken = nil
        }

        guard let token = refreshToken, !token.isEmpty else { return nil }

        return Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let restored = try await authService.refresh(refreshToken: token)
                self.session = restored
            } catch {
                // `AuthService.refresh` already clears the keychain on a
                // 4xx (stale token). Transport failures leave the token
                // alone so a flaky cold launch doesn't sign the user out.
                // Either way: stay on the login screen.
                self.session = nil
            }
        }
    }

    // MARK: - Sign out

    /// Clears the in-memory session and the persisted refresh token. Not
    /// wired to a UI surface in this PR; exposed so future stories
    /// (Settings \u2192 "Sign out") can call it.
    ///
    /// Known failure mode \u2014 read before changing this method:
    /// `keychain.clearAll()` can throw in genuinely rare cases
    /// (`errSecNotAvailable` under low-memory pressure, or a sandbox
    /// entitlement mismatch on a future build target). If it does, the
    /// refresh token persists in the Keychain. We still clear
    /// `session` in memory so the UI reflects the user's intent, but
    /// the *next cold launch* will see the leftover refresh token,
    /// call `AuthService.refresh`, and \u2014 if the token is still valid
    /// \u2014 silently sign the user back in. For a banking app that is a
    /// material auth-state inconsistency.
    ///
    /// Mitigations in this PR:
    ///   - log the failure via `os.Logger` so it is visible in
    ///     Console.app during QA / staging without leaking to release
    ///     stdout;
    ///   - `assertionFailure` so debug builds trap immediately, giving
    ///     us a stack trace the first time this surfaces in CI;
    ///   - leave the in-memory `session` cleared so the UI does not
    ///     contradict the user's tap.
    ///
    /// Do NOT "simplify" this back to `try? keychain.clearAll()`. If
    /// the method ever needs to surface the failure to a UI caller,
    /// promote it to `throws` rather than re-hiding the error.
    public func signOut() {
        do {
            try keychain.clearAll()
        } catch {
            Self.log.error(
                "signOut: keychain.clearAll() failed; refresh token may persist and auto-sign-in on next launch. error=\(String(describing: error), privacy: .public)"
            )
            assertionFailure(
                "signOut: keychain.clearAll() failed: \(error). See AppCoordinator.signOut() docs for the auth-state inconsistency this can cause."
            )
        }
        session = nil
    }
}
