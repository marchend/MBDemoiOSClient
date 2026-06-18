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

import SwiftUI

struct RootView: View {

    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        if let session = coordinator.session {
            LandingView(session: session)
        } else {
            LoginView(viewModel: makeLoginViewModel())
        }
    }

    /// Build a `LoginViewModel` wired with the coordinator's auth
    /// service + Okta config, and whose `onAuthenticated` closure hands
    /// the resulting session back to the coordinator.
    ///
    /// `[weak coordinator]` so the closure doesn't extend the
    /// coordinator's lifetime past the SwiftUI view's lifetime.
    private func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(
            authService: coordinator.authService,
            oktaConfig: coordinator.oktaConfig,
            onAuthenticated: { [weak coordinator] session in
                coordinator?.session = session
            }
        )
    }
}
