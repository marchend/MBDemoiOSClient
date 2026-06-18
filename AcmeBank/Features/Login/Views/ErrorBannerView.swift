import SwiftUI

/// Inline error banner shown when an optional error message string is set.
///
/// Renders nothing (zero height) when `message` is `nil`, so it can be
/// placed unconditionally in the layout without affecting spacing when
/// there is no error.
struct ErrorBannerView: View {
    /// The message to display. Pass `nil` to hide the banner entirely.
    let message: String?

    var body: some View {
        if let message {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.white)
                    .font(.body)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.acmeError)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Error: \(message)")
        }
    }
}

#Preview("With error") {
    ErrorBannerView(message: "Your username or password is incorrect. Please try again.")
        .padding()
}

#Preview("No error") {
    ErrorBannerView(message: nil)
        .padding()
}
