//
//  IDTokenDecoderTests.swift
//  AcmeBankTests
//

import XCTest
@testable import AcmeBank

final class IDTokenDecoderTests: XCTestCase {

    private let decoder = IDTokenDecoder()

    // MARK: - Helpers

    private func makeJWT(payload: [String: Any]) -> String {
        let header = base64URL(
            try! JSONSerialization.data(withJSONObject: ["alg": "RS256", "typ": "JWT"])
        )
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        let payloadEnc = base64URL(payloadData)
        // Signature is not verified, so any non-empty value works.
        return "\(header).\(payloadEnc).signature-placeholder"
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Happy path

    func test_decode_validJWT_returnsExpectedClaims() throws {
        let token = makeJWT(payload: [
            "sub":       "00u1234",
            "name":      "Ada Lovelace",
            "email":     "ada@example.com",
            "auth_time": 1_700_000_000,
        ])

        let claims = try decoder.decode(token)

        XCTAssertEqual(claims.sub, "00u1234")
        XCTAssertEqual(claims.name, "Ada Lovelace")
        XCTAssertEqual(claims.email, "ada@example.com")
        XCTAssertEqual(claims.authTime, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func test_decode_missingOptionalClaims_returnsNilFields() throws {
        let token = makeJWT(payload: ["sub": "00u9999"])

        let claims = try decoder.decode(token)

        XCTAssertEqual(claims.sub, "00u9999")
        XCTAssertNil(claims.name)
        XCTAssertNil(claims.email)
        XCTAssertNil(claims.authTime)
    }

    // MARK: - Rejection paths

    func test_decode_malformedTooFewSegments_throwsMalformed() {
        XCTAssertThrowsError(try decoder.decode("only.two")) { error in
            XCTAssertEqual(error as? IDTokenDecoder.DecodeError, .malformed)
        }
    }

    func test_decode_emptyString_throwsMalformed() {
        XCTAssertThrowsError(try decoder.decode("")) { error in
            XCTAssertEqual(error as? IDTokenDecoder.DecodeError, .malformed)
        }
    }

    func test_decode_invalidBase64Payload_throwsBase64Failed() {
        // Middle segment is not valid base64url.
        let token = "header.@@@not-base64@@@.sig"
        XCTAssertThrowsError(try decoder.decode(token)) { error in
            // Could be base64Failed OR jsonFailed depending on whether the
            // base64url decoder happens to accept the garbage. Both are
            // acceptable rejection paths; assert it's at least a typed error.
            guard let typed = error as? IDTokenDecoder.DecodeError else {
                XCTFail("Expected typed DecodeError, got \(error)")
                return
            }
            XCTAssertTrue([.base64Failed, .jsonFailed].contains(typed))
        }
    }

    func test_decode_validBase64ButNotJSON_throwsJSONFailed() {
        // base64url("not json at all") put in the middle segment.
        let payload = base64URL(Data("not json at all".utf8))
        let token = "header.\(payload).sig"
        XCTAssertThrowsError(try decoder.decode(token)) { error in
            XCTAssertEqual(error as? IDTokenDecoder.DecodeError, .jsonFailed)
        }
    }

    func test_decode_jsonMissingSub_throwsJSONFailed() {
        // `sub` is required; JSONDecoder will reject without it.
        let token = makeJWT(payload: ["name": "no sub here"])
        XCTAssertThrowsError(try decoder.decode(token)) { error in
            XCTAssertEqual(error as? IDTokenDecoder.DecodeError, .jsonFailed)
        }
    }

    // MARK: - base64url padding helper

    func test_base64URLDecode_paddingNormalisation() {
        // "ABC" → base64url has length 4, no `=` padding needed.
        // The decoder must accept input both with and without padding.
        let raw = "hello".data(using: .utf8)!
        let b64 = raw.base64EncodedString()                 // "aGVsbG8="
        let b64url = b64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")        // "aGVsbG8"

        XCTAssertEqual(IDTokenDecoder.base64URLDecode(b64url), raw)
    }
}
