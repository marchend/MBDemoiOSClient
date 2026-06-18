import SwiftUI

/// Root content view — presents `LoginView` as the app's initial screen.
///
/// `AcmeBankApp` places this view inside its `WindowGroup`, making it the
/// first screen a user sees on launch. When the coordinator layer is added
/// in a future PR, this file will be replaced by `RootView` (auth-state
/// switcher), but for now it directly hosts the login screen.
struct ContentView: View {
    var body: some View {
        LoginView()
    }
}

#Preview {
    ContentView()
}
