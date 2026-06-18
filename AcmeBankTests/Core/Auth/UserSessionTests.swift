//
//  UserSessionTests.swift
//  AcmeBankTests
//

import XCTest
@testable import AcmeBank

final class UserSessionTests: XCTestCase {

    private func makeSession(
        userId: String = "00u123",
        displayName: String = "Ada Lovelace",
        email: String = "ada@example.com",
        accessToken: String = "access.token.value",
        authTimestamp: Date = Date(timeIntervalSince1970: 1_700_000_000),
        deviceName: String = "iPhone Simulator"
    ) -> UserSession {
        UserSession(
            userId: userId,
            displayName: displayName,
            email: email,
            accessToken: accessToken,
            authTimestamp: authTimestamp,
            deviceName: deviceName
        )
    }

    // NOTE: `UserSession` is intentionally not `Codable` — the access
    // token must never accidentally land on disk. See the doc comment
    // on `UserSession` for rationale. There is therefore no Codable
    // round-trip test here.

    func test_equality_identicalValues_areEqual() {
        XCTAssertEqual(makeSession(), makeSession())
    }

    func test_equality_anyFieldDifference_isNotEqual() {
        XCTAssertNotEqual(makeSession(userId: "a"),       makeSession(userId: "b"))
        XCTAssertNotEqual(makeSession(displayName: "a"),  makeSession(displayName: "b"))
        XCTAssertNotEqual(makeSession(email: "a@a"),      makeSession(email: "b@b"))
        XCTAssertNotEqual(makeSession(accessToken: "a"),  makeSession(accessToken: "b"))
        XCTAssertNotEqual(
            makeSession(authTimestamp: Date(timeIntervalSince1970: 1)),
            makeSession(authTimestamp: Date(timeIntervalSince1970: 2))
        )
        XCTAssertNotEqual(makeSession(deviceName: "a"),   makeSession(deviceName: "b"))
    }
}
