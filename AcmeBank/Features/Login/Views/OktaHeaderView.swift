import SwiftUI

/// Static top strip showing the Okta-hosted domain indicator.
///
/// Mirrors the lock-icon + domain label + Okta logo strip that appears at
/// the top of browser-based Okta sign-in pages, giving users visual
/// assurance that they are on a trusted sign-in surface.
struct OktaHeaderView: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(Color.acmeNavy)

            Text("acmebank.okta.com")
                .font(.caption)
                .foregroundStyle(Color.acmeNavy)

            Spacer()

            Text("Okta")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.acmeNavy)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Secured sign-in page: acmebank.okta.com — Powered by Okta")
    }
}

#Preview {
    OktaHeaderView()
}
