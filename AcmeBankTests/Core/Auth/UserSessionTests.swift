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

    func test_codable_roundTrip_preservesAllFields() throws {
        let original = makeSession()

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserSession.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.userId,        original.userId)
        XCTAssertEqual(decoded.displayName,   original.displayName)
        XCTAssertEqual(decoded.email,         original.email)
        XCTAssertEqual(decoded.accessToken,   original.accessToken)
        XCTAssertEqual(decoded.authTimestamp, original.authTimestamp)
        XCTAssertEqual(decoded.deviceName,    original.deviceName)
    }

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
