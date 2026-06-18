import SwiftUI

// MARK: - Brand Colors

extension Color {
    /// AcmeBank primary brand colour — dark navy (#1B2A4A)
    static let acmeNavy = Color(red: 27 / 255, green: 42 / 255, blue: 74 / 255)

    /// Light background used throughout the login screen
    static let acmeBackground = Color(.systemBackground)

    /// Subtle border / divider colour
    static let acmeBorder = Color(.separator)

    /// Error red for the inline error banner
    static let acmeError = Color(.systemRed)
}

// MARK: - Typography helpers

extension Font {
    /// Large title, bold — screen headings
    static let acmeHeading: Font = .title.weight(.bold)

    /// Body text, regular weight
    static let acmeBody: Font = .body

    /// Small caption text
    static let acmeCaption: Font = .caption
}
