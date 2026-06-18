import SwiftUI

/// Placeholder destination for the "Open one" navigation link on the login screen.
///
/// This view is a stub — the real "Open Account" onboarding flow will be
/// implemented in a future PR. Displaying a clear "Coming soon" message
/// prevents a dead-end navigation target from shipping silently.
struct OpenAccountPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.acmeNavy)

            Text("Open an Account")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.primary)

            Text("Coming soon — this feature will let you open a new AcmeBank account directly from the app.")
                .font(.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.acmeBackground.ignoresSafeArea())
        .navigationTitle("Open an Account")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        OpenAccountPlaceholderView()
    }
}
