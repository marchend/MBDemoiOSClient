//
//  RootView.swift
//  AcmeBank
//
//  Auth-state switcher. Observes `AppCoordinator.session`:
//    - `nil`     \u2192 present `LoginView` wired to the coordinator's
//                  `AuthServicing` + `OktaConfig`. On a successful
//                  sign-in, `onAuthenticated` writes the resulting
//                  `UserSession` back to the coordinator, which causes
//                  this view to re-render with the landing screen.
//    - non-nil   \u2192 present `LandingView(session:)`.
//
//  This is the only place where `LoginView` / `LandingView` are chosen
//  between; feature views never know about each other.
//
//  ViewModel ownership:
//  - The `LoginViewModel` is held as a `@StateObject` on `RootView`
//    itself, constructed exactly once when SwiftUI first instantiates
//    the view. This avoids the `makeLoginViewModel()`-from-`body`
//    anti-pattern, where every `body` re-evaluation would allocate a
//    fresh ViewModel + `[weak coordinator]` closure. While
//    `@StateObject(wrappedValue:)` in `LoginView` would normally
//    discard those duplicates, doing so silently masks the risk that a
//    future change to the view tree (a parent `.id()`, a sibling
//    branch insertion) could shift `LoginView`'s structural identity
//    and cause SwiftUI to adopt a freshly allocated ViewModel
//    mid-flight \u2014 silently dropping the in-progress sign-in task. By
//    owning the ViewModel here we make its lifetime stable across
//    re-renders.
//

import SwiftUI

struct RootView: View {

    @ObservedObject var coordinator: AppCoordinator

    /// Owned once by `RootView`; survives every `body` re-evaluation
    /// (dynamic type, scene-phase, environment-object updates, etc.)
    /// and is destroyed only when `RootView` itself leaves the
    /// hierarchy. See file header for the rationale.
    @StateObject private var loginViewModel: LoginViewModel

    init(coordinator: AppCoordinator) {
        self._coordinator = ObservedObject(wrappedValue: coordinator)
        // `StateObject(wrappedValue:)` invokes the autoclosure exactly
        // once per `RootView` lifetime, even though `init` itself can
        // run on every re-render. The `[weak coordinator]` capture
        // keeps the closure from extending the coordinator's lifetime
        // past the view's.
        self._loginViewModel = StateObject(
            wrappedValue: LoginViewModel(
                authService: coordinator.authService,
                oktaConfig: coordinator.oktaConfig,
                onAuthenticated: { [weak coordinator] session in
                    coordinator?.session = session
                }
            )
        )
    }

    var body: some View {
        if let session = coordinator.session {
            LandingView(session: session)
        } else {
            LoginView(viewModel: loginViewModel)
        }
    }
}
