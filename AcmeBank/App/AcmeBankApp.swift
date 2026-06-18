//
//  AcmeBankApp.swift
//  AcmeBank
//
//  `@main` SwiftUI entry point. Constructs the composition root
//  (`AppCoordinator`) from runtime config (`OktaConfig.load()`) and
//  hands it to `RootView`, which is the only view in the project that
//  knows about the auth-state switch.
//
//  The coordinator is built once and held by the `App` value via
//  `@StateObject` so the WindowGroup's view rebuilds (e.g. dynamic-type
//  changes, scene phase transitions) do not throw away the cold-launch
//  refresh state.
//

import SwiftUI

@main
struct AcmeBankApp: App {

    @StateObject private var coordinator: AppCoordinator = AcmeBankApp.makeCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
        }
    }

    /// Build the composition root.
    ///
    /// - `.configured(...)` builds a real `AuthService` wired to the
    ///   shared `KeychainStore`.
    /// - `.notConfigured(...)` skips the `AuthService` (passes `nil`)
    ///   so a build without Okta secrets still launches \u2014 it just
    ///   surfaces the not-configured banner when the user taps Sign In.
    private static func makeCoordinator() -> AppCoordinator {
        let oktaConfig = OktaConfig.load()
        let keychain = KeychainStore()
        let authService = AuthService(config: oktaConfig, keychain: keychain)
        return AppCoordinator(
            oktaConfig: oktaConfig,
            authService: authService,
            keychain: keychain
        )
    }
}
