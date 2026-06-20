//
//  APIError.swift
//  AcmeBank
//
//  Typed errors surfaced by `APIClient`. The cases are deliberately routing-
//  oriented: each one tells the caller WHAT TO DO, not just what happened.
//
//  - `.unauthorized`        → the bearer token is missing/expired/revoked.
//                             Caller should sign the user out (or attempt a
//                             refresh-then-retry) instead of showing a
//                             generic error banner.
//  - `.serverError(Int)`    → BFF returned 5xx. Caller may retry with
//                             backoff or surface "service unavailable".
//  - `.networkError(Error)` → transport failure (no connection, TLS, etc.).
//                             Underlying error is preserved for logging
//                             only — never display its `.localizedDescription`
//                             to users (Apple's strings vary by locale and
//                             leak internals).
//  - `.decodingError(Error)`→ HTTP succeeded but the body didn't match the
//                             expected `Decodable` shape. Almost always a
//                             BFF/contract bug — log it loudly.
//  - `.invalidConfiguration`→ `API_BASE_URL` missing from Info.plist or
//                             malformed. Hard developer error: the build is
//                             broken, not the user.
//

import Foundation

public enum APIError: Error {
    case unauthorized
    case serverError(Int)
    case networkError(Error)
    case decodingError(Error)
    case invalidConfiguration
}

extension APIError: Equatable {
    /// `Equatable` is convenient for unit tests that assert which error
    /// branch fired. Associated `Error` values are compared by
    /// `localizedDescription`/`NSError` bridging, which is sufficient for
    /// the test-stub `URLError`s and `DecodingError`s we throw.
    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized):
            return true
        case let (.serverError(l), .serverError(r)):
            return l == r
        case let (.networkError(l), .networkError(r)):
            return (l as NSError) == (r as NSError)
        case let (.decodingError(l), .decodingError(r)):
            return (l as NSError) == (r as NSError)
        case (.invalidConfiguration, .invalidConfiguration):
            return true
        default:
            return false
        }
    }
}
