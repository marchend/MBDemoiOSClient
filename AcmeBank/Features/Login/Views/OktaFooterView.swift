import SwiftUI

/// "Secured by Okta" footer strip shown at the bottom of the login screen.
struct OktaFooterView: View {
    var body: some View {
        HStack(spacing: 4) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(Color.acmeNavy)

            Text("Secured by")
                .font(.caption)
                .foregroundStyle(Color.secondary)

            Text("Okta")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.acmeNavy)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Secured by Okta")
    }
}

#Preview {
    OktaFooterView()
}
