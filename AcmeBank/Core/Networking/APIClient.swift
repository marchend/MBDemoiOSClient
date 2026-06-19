//
//  APIClient.swift
//  AcmeBank
//
//  Reusable authenticated HTTP transport seam over `URLSession`. This is
//  the building block that feature repositories (e.g. `BFFHomeRepository`)
//  will compose; it intentionally exposes NO feature-specific endpoints.
//
//  Contract:
//  - `APIClient.get(path:bearerToken:decoder:)` issues a GET against
//    `baseURL + path` with `Authorization: Bearer <token>` and
//    `Accept: application/json` headers.
//  - 2xx + decodable body → returns the decoded `T`.
//  - 401             → throws `APIError.unauthorized`.
//  - 5xx             → throws `APIError.serverError(status)`.
//  - Other non-2xx   → also throws `APIError.serverError(status)` for now;
//                       feature code can refine when it has a use case.
//  - Transport error → throws `APIError.networkError(underlying)`.
//  - Decode failure  → throws `APIError.decodingError(underlying)`.
//  - Missing/empty base URL → throws `APIError.invalidConfiguration`
//                              (raised by `APIBaseURLProvider`).
//
//  Why a `baseURL` closure rather than a stored `URL`:
//  We want a late, throwing resolution so a misconfigured Info.plist
//  doesn't crash app startup — it surfaces at the first request as
//  `APIError.invalidConfiguration`. The default closure delegates to
//  `APIBaseURLProvider.load()`; tests inject a fixed URL or a closure
//  that throws.
//
//  Test seam:
//  The concrete `URLSessionAPIClient` accepts an injected `URLSession`,
//  so tests pass a session configured with `URLProtocolStub` and never
//  hit the network. See `AcmeBankTests/Core/Networking/URLProtocolStub.swift`.
//

import Foundation

// MARK: - Protocol

public protocol APIClient {
    /// Issue an authenticated GET against `path` (relative to the BFF base
    /// URL), decoding the response body into `T`.
    ///
    /// - Parameters:
    ///   - path: Path component appended to the base URL. May start with
    ///           `/` or not — both are handled.
    ///   - bearerToken: Access token used for `Authorization: Bearer ...`.
    ///   - decoder: JSON decoder to apply to the response body. Caller
    ///              configures snake-case / date strategy as needed.
    /// - Returns: The decoded `T` on 2xx.
    /// - Throws: `APIError` — see file header for the routing rules.
    func get<T: Decodable>(
        path: String,
        bearerToken: String,
        decoder: JSONDecoder
    ) async throws -> T
}

// MARK: - URLSession implementation

public final class URLSessionAPIClient: APIClient {

    private let session: URLSession
    private let baseURLProvider: () throws -> URL

    /// Designated init.
    ///
    /// - Parameters:
    ///   - session: `URLSession` to use. Tests inject a session configured
    ///              with `URLProtocolStub`; production uses `.shared`.
    ///   - baseURLProvider: Closure that resolves the BFF base URL. Default
    ///                      reads `API_BASE_URL` from `Info.plist` via
    ///                      `APIBaseURLProvider.load()`. Throwing here
    ///                      surfaces as `APIError.invalidConfiguration` at
    ///                      the first request rather than at startup.
    public init(
        session: URLSession = .shared,
        baseURLProvider: @escaping () throws -> URL = APIBaseURLProvider.load
    ) {
        self.session = session
        self.baseURLProvider = baseURLProvider
    }

    public func get<T: Decodable>(
        path: String,
        bearerToken: String,
        decoder: JSONDecoder
    ) async throws -> T {
        // 1. Build URL.
        let baseURL: URL
        do {
            baseURL = try baseURLProvider()
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.invalidConfiguration
        }

        let normalisedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: normalisedPath, relativeTo: baseURL)?.absoluteURL else {
            throw APIError.invalidConfiguration
        }

        // 2. Build request with required headers.
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // 3. Perform request — map transport failures to .networkError.
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        // 4. Inspect status code → route to APIError cases.
        //    A non-HTTP response is theoretically possible (e.g. file://)
        //    and should be treated as a transport-shaped failure.
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(
                URLError(.badServerResponse)
            )
        }

        switch http.statusCode {
        case 200..<300:
            break
        case 401:
            throw APIError.unauthorized
        default:
            // 4xx (other than 401) and 5xx both map to .serverError. The
            // routing-level distinction we care about TODAY is only
            // "401 → sign out" vs "everything else → generic error";
            // feature code can refine if a use case appears.
            throw APIError.serverError(http.statusCode)
        }

        // 5. Decode.
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
