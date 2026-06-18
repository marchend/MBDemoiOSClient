//
//  KeychainStoreTests.swift
//  AcmeBankTests
//

import XCTest
import Security
@testable import AcmeBank

final class KeychainStoreTests: XCTestCase {

    private var service: String!
    private var store: KeychainStore!

    override func setUp() {
        super.setUp()
        // Unique service name per test so parallel/sequential runs don't
        // collide and one test's leftover doesn't break another's load.
        service = "com.acmebank.tests.\(UUID().uuidString)"
        store   = KeychainStore(service: service)
    }

    override func tearDown() {
        try? store.clearAll()
        store = nil
        service = nil
        super.tearDown()
    }

    // MARK: - Round-trip

    func test_storeAndLoadRefreshToken_roundTrip() throws {
        try store.storeRefreshToken("refresh-abc-123")
        let loaded = try store.loadRefreshToken()
        XCTAssertEqual(loaded, "refresh-abc-123")
    }

    func test_storeAllThreeTokens_independentlyOverwriteable() throws {
        try store.storeIDToken("id-1")
        try store.storeAccessToken("access-1")
        try store.storeRefreshToken("refresh-1")

        // Overwrite refresh; ID + access should be unaffected.
        try store.storeRefreshToken("refresh-2")

        XCTAssertEqual(try store.loadRefreshToken(), "refresh-2")
    }

    func test_clearAll_removesRefreshToken() throws {
        try store.storeRefreshToken("refresh-xyz")
        try store.clearAll()

        XCTAssertThrowsError(try store.loadRefreshToken()) { error in
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
        }
    }

    func test_clearAll_isIdempotent_evenWithNothingStored() {
        XCTAssertNoThrow(try store.clearAll())
        XCTAssertNoThrow(try store.clearAll())
    }

    func test_loadRefreshToken_whenAbsent_throwsItemNotFound() {
        XCTAssertThrowsError(try store.loadRefreshToken()) { error in
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
        }
    }

    // MARK: - kSecUseDataProtectionKeychain flag

    func test_baseQuery_includesDataProtectionKeychainFlag() {
        let query = store.baseQuery(account: .refreshToken)
        let flag  = query[kSecUseDataProtectionKeychain as String] as? Bool

        XCTAssertEqual(flag, true,
            "All keychain queries must include kSecUseDataProtectionKeychain: true so CI simulator builds (CODE_SIGNING_ALLOWED=NO) can read/write items.")
    }

    func test_baseQuery_usesProvidedServiceName() {
        let query = store.baseQuery(account: .idToken)
        XCTAssertEqual(query[kSecAttrService as String] as? String, service)
        XCTAssertEqual(query[kSecAttrAccount as String] as? String, "id_token")
        XCTAssertEqual(query[kSecClass as String] as? CFString, kSecClassGenericPassword)
    }

    func test_baseQuery_differentAccountsHaveDifferentRawValues() {
        let idQuery      = store.baseQuery(account: .idToken)
        let accessQuery  = store.baseQuery(account: .accessToken)
        let refreshQuery = store.baseQuery(account: .refreshToken)

        XCTAssertNotEqual(
            idQuery[kSecAttrAccount as String] as? String,
            accessQuery[kSecAttrAccount as String] as? String
        )
        XCTAssertNotEqual(
            accessQuery[kSecAttrAccount as String] as? String,
            refreshQuery[kSecAttrAccount as String] as? String
        )
    }
}
