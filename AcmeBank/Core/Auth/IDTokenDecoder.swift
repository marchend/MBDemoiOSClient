//
//  IDTokenDecoder.swift
//  AcmeBank
//
//  Minimal JWT *payload* decoder. We are NOT verifying signatures here —
//  the SDK / IdP has already validated the token by the time we touch it,
//  and signature verification is explicitly out of scope for this PR.
//
//  Approach:
//  1. Split the compact JWS string on `.` and take the middle segment.
//  2. Convert base64url → base64 (`-`→`+`, `_`→`/`, pad with `=`).
//  3. JSON-decode into a `Claims` struct.
//

import Foundation

public struct IDTokenDecoder {

    public struct Claims: Equatable, Decodable {
        public let sub: String
        public let name: String?
        public let email: String?
        /// `auth_time` is seconds-since-epoch in the JWT; surfaced as `Date`.
        public let authTime: Date?

        private enum CodingKeys: String, CodingKey {
            case sub, name, email
            case authTime = "auth_time"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.sub = try c.decode(String.self, forKey: .sub)
            self.name = try c.decodeIfPresent(String.self, forKey: .name)
            self.email = try c.decodeIfPresent(String.self, forKey: .email)
            if let ts = try c.decodeIfPresent(TimeInterval.self, forKey: .authTime) {
                self.authTime = Date(timeIntervalSince1970: ts)
            } else {
                self.authTime = nil
            }
        }

        // Memberwise init for tests and fixtures.
        public init(sub: String, name: String?, email: String?, authTime: Date?) {
            self.sub = sub
            self.name = name
            self.email = email
            self.authTime = authTime
        }
    }

    public enum DecodeError: Error, Equatable {
        case malformed
        case base64Failed
        case jsonFailed
    }

    public init() {}

    public func decode(_ token: String) throws -> Claims {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else {
            throw DecodeError.malformed
        }

        let payloadSegment = String(segments[1])
        guard !payloadSegment.isEmpty else { throw DecodeError.malformed }

        guard let data = Self.base64URLDecode(payloadSegment) else {
            throw DecodeError.base64Failed
        }

        do {
            return try JSONDecoder().decode(Claims.self, from: data)
        } catch {
            throw DecodeError.jsonFailed
        }
    }

    /// Convert base64url to base64 with padding then decode. Returns nil
    /// if the input is not valid base64url.
    static func base64URLDecode(_ s: String) -> Data? {
        var base64 = s
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let mod = base64.count % 4
        if mod > 0 {
            base64.append(String(repeating: "=", count: 4 - mod))
        }
        return Data(base64Encoded: base64)
    }
}
