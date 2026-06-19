//
//  APIBaseURLProvider.swift
//  AcmeBank
//
//  Reads the BFF base URL from the app's Info.plist key `API_BASE_URL`.
//
//  The value is injected at build time by `Scripts/inject_okta_config.sh`
//  (the same Run Script phase that handles the Okta keys) from the
//  `API_BASE_URL` shell env var, falling back to the sentinel string
//  `__API_BASE_URL_UNSET__` when the var is not set. We treat the sentinel,
//  an empty string, and a missing key uniformly as "not configured" and
//  surface `APIError.invalidConfiguration` to the caller.
//
//  Design mirrors `OktaConfig`:
//  - `load()` reads `Bundle.main.infoDictionary`.
//  - `load(from:)` is the test seam — unit tests pass a dictionary
//    directly instead of mutating the main bundle.
//  - No `fatalError`, no force-unwraps. A misconfigured build must still
//    boot; the misconfiguration surfaces at the first networking call.
//

import Foundation

public enum APIBaseURLProvider {

    /// Info.plist key written by `Scripts/inject_okta_config.sh`.
    static let infoPlistKey = "API_BASE_URL"

    /// Sentinel the build script writes when `API_BASE_URL` is unset.
    /// Must stay byte-identical to the script.
    static let sentinel = "__API_BASE_URL_UNSET__"

    /// Resolve the BFF base URL from `Bundle.main.infoDictionary`. Throws
    /// `APIError.invalidConfiguration` when the key is missing, holds the
    /// build-script sentinel, is empty, or fails URL parsing.
    public static func load() throws -> URL {
        try load(from: Bundle.main.infoDictionary ?? [:])
    }

    /// Test-seam: resolve from an arbitrary dictionary so unit tests don't
    /// have to mutate `Bundle.main`.
    static func load(from info: [String: Any]) throws -> URL {
        guard let raw = info[infoPlistKey] as? String, !raw.isEmpty else {
            throw APIError.invalidConfiguration
        }
        if raw == sentinel {
            throw APIError.invalidConfiguration
        }
        guard let url = URL(string: raw), url.scheme != nil else {
            throw APIError.invalidConfiguration
        }
        return url
    }
}
