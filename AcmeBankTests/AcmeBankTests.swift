import XCTest
@testable import AcmeBank

final class AcmeBankTests: XCTestCase {
    /// Bootstrap proof-of-life: test target compiles + links against the app
    /// module. Real behaviour tests belong in feature stories.
    ///
    /// PR 4 replaced the `ContentView` bootstrap stub with `RootView`
    /// (auth-state switcher), so the proof-of-life smoke now instantiates
    /// an `AppCoordinator` + `RootView`. We only care that init succeeds
    /// \u2014 no view-hierarchy walking, no rendering assertions (see the
    /// project's recorded lesson on bootstrap iOS tests).
    ///
    /// `AppCoordinator` is `@MainActor`-isolated, so the test is too.
    @MainActor
    func test_rootView_initializes() {
        let coordinator = AppCoordinator(
            oktaConfig: .notConfigured(reason: "bootstrap test"),
            authService: nil,
            keychain: KeychainStore(service: "com.acmebank.mobile.auth.bootstrap-test")
        )
        _ = RootView(coordinator: coordinator)
    }
}
