//
//  UserSession.swift
//  AcmeBank
//
//  Value type representing a successfully authenticated user. Built by
//  `AuthService` from the decoded ID-token claims plus the access token
//  returned by Okta.
//
//  Notes:
//  - `Codable` so coordinators can persist it for the lifetime of the
//    process if needed (NOT to UserDefaults — see CLAUDE.md).
//  - `Equatable` so SwiftUI views / ViewModels can diff session state.
//  - The refresh token is intentionally NOT a field on `UserSession`.
//    Refresh tokens live only inside the Keychain (and only when the
//    user opted into "Keep me signed in").
//

import Foundation

public struct UserSession: Codable, Equatable {
    /// `sub` claim from the ID token. Stable Okta user identifier.
    public let userId: String

    /// `name` claim from the ID token. Shown in the UI.
    public let displayName: String

    /// `email` claim from the ID token.
    public let email: String

    /// OAuth2 access token used by the networking layer as a Bearer credential.
    public let accessToken: String

    /// `auth_time` claim from the ID token if present, otherwise the
    /// wall-clock time at which `AuthService` built this session.
    public let authTimestamp: Date

    /// `UIDevice.current.name` captured at sign-in. Useful for "active
    /// devices" UI later; captured eagerly so the session is self-contained.
    public let deviceName: String

    public init(
        userId: String,
        displayName: String,
        email: String,
        accessToken: String,
        authTimestamp: Date,
        deviceName: String
    ) {
        self.userId = userId
        self.displayName = displayName
        self.email = email
        self.accessToken = accessToken
        self.authTimestamp = authTimestamp
        self.deviceName = deviceName
    }
}
