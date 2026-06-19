//
//  LandingView.swift
//  AcmeBank
//
//  Post-sign-in landing screen. Renders the authenticated user's name
//  and email from a `UserSession`. Deliberately minimal: no network
//  calls, no fixtures, no hard-coded sample names. The Home Dashboard,
//  TabBar, etc. land in later PRs.
//
//  Accessibility identifiers `welcomeGreeting` and `welcomeEmail` are
//  attached to the individual `Text` views (NOT the enclosing `VStack`)
//  so XCUITest can locate them \u2014 SwiftUI flattens the accessibility
//  tree of a container when an identifier is attached to it, which
//  hides the children from `app.staticTexts[id]` queries.
//

import SwiftUI

struct LandingView: View {

    let session: UserSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome, \(session.displayName)")
                .font(.title.weight(.bold))
                .foregroundStyle(Color.acmeNavy)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("welcomeGreeting")

            Text(session.email)
                .font(.body)
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier("welcomeEmail")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .background(Color.acmeBackground.ignoresSafeArea())
    }
}

#Preview {
    LandingView(
        session: UserSession(
            userId: "00uABCDEF",
            displayName: "Ada Lovelace",
            email: "ada@example.com",
            accessToken: "preview-access-token",
            authTimestamp: Date(),
            deviceName: "Preview Device"
        )
    )
}
