//
//  KeychainStore.swift
//  AcmeBank
//
//  Thin wrapper around the Security framework `SecItem*` C APIs for the
//  three tokens AuthService needs to persist: ID token, access token,
//  refresh token.
//
//  Why a wrapper:
//  - Centralises the `kSecUseDataProtectionKeychain: true` flag so the
//    simulator (which has `CODE_SIGNING_ALLOWED=NO` in this project)
//    can read/write keychain items without an entitlement.
//  - Hides `CFDictionary` / `Unmanaged` plumbing from callers.
//  - Behind a protocol so `AuthService` can be unit-tested with a fake.
//

import Foundation
import Security

/// Errors surfaced by the concrete `KeychainStore`. Note: per the lesson
/// in this codebase's memory, AuthService treats keychain failures as a
/// CACHE-MISS and never propagates them out of `signIn`. They still need
/// to be typed so tests and logs can assert on them.
public enum KeychainError: Error, Equatable {
    case unexpectedStatus(OSStatus)
    case itemNotFound
    case dataCorrupted
}

/// Abstraction so AuthService can be wired with a fake in tests.
public protocol KeychainStoring {
    func storeIDToken(_ token: String) throws
    func storeAccessToken(_ token: String) throws
    func storeRefreshToken(_ token: String) throws
    func loadRefreshToken() throws -> String
    func clearAll() throws
}

public final class KeychainStore: KeychainStoring {

    // Account keys under the same service identifier. Distinct strings so
    // each token can be added/removed independently.
    enum Account: String, CaseIterable {
        case idToken      = "id_token"
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
    }

    private let service: String

    /// `service` is parameterised so unit tests can use a unique service
    /// name per test and not collide with the real app's keychain items.
    public init(service: String = "com.acmebank.mobile.auth") {
        self.service = service
    }

    // MARK: - Public API

    public func storeIDToken(_ token: String) throws {
        try store(token, account: Account.idToken)
    }

    public func storeAccessToken(_ token: String) throws {
        try store(token, account: Account.accessToken)
    }

    public func storeRefreshToken(_ token: String) throws {
        try store(token, account: Account.refreshToken)
    }

    public func loadRefreshToken() throws -> String {
        try load(account: Account.refreshToken)
    }

    public func clearAll() throws {
        for account in Account.allCases {
            // Treat "not found" as success — clearing a key that was never
            // written is the caller's intent.
            do {
                try delete(account: account)
            } catch KeychainError.itemNotFound {
                continue
            }
        }
    }

    // MARK: - Internals

    /// Build the base query dictionary shared by every operation. ALL
    /// queries include `kSecUseDataProtectionKeychain: true` so the
    /// simulator (CI, `CODE_SIGNING_ALLOWED=NO`) can read/write items.
    func baseQuery(account: Account) -> [String: Any] {
        [
            kSecClass as String:                kSecClassGenericPassword,
            kSecAttrService as String:          service,
            kSecAttrAccount as String:          account.rawValue,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    private func store(_ value: String, account: Account) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataCorrupted
        }

        // Idempotent write: try to update first; if nothing's there, add.
        var query = baseQuery(account: account)
        let updateAttributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        default:
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    private func load(account: Account) throws -> String {
        var query = baseQuery(account: account)
        query[kSecReturnData as String]  = true
        query[kSecMatchLimit as String]  = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard
                let data = item as? Data,
                let string = String(data: data, encoding: .utf8)
            else {
                throw KeychainError.dataCorrupted
            }
            return string
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func delete(account: Account) throws {
        let query = baseQuery(account: account)
        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
