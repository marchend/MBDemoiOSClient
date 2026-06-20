//
//  APIClientTests.swift
//  AcmeBankTests
//
//  Exhaustive coverage of every routing branch in `URLSessionAPIClient.get`:
//  - 2xx happy path with valid JSON
//  - 401 → .unauthorized
//  - 500 → .serverError(500)
//  - transport failure → .networkError
//  - decode failure → .decodingError
//  - missing base URL → .invalidConfiguration
//  - request headers: Authorization (Bearer) + Accept always present
//
//  Tests use `URLProtocolStub` so no live network is involved.
//

import XCTest
@testable import AcmeBank

final class APIClientTests: XCTestCase {

    // MARK: - Fixtures

    private let baseURL = URL(string: "https://bff.example.com/")!
    private let bearer = "test-access-token"
    private let path = "v1/home"

    private struct Greeting: Decodable, Equatable {
        let message: String
    }

    private func makeClient(
        baseURL: URL? = nil,
        baseURLError: APIError? = nil
    ) -> URLSessionAPIClient {
        let session = URLProtocolStub.makeSession()
        let provider: () throws -> URL = {
            if let err = baseURLError { throw err }
            return baseURL ?? URL(string: "https://bff.example.com/")!
        }
        return URLSessionAPIClient(session: session, baseURLProvider: provider)
    }

    private func httpResponse(status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: baseURL.appendingPathComponent(path),
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
    }

    // MARK: - XCTestCase lifecycle

    override func setUp() {
        super.setUp()
        URLProtocolStub.tearDown()
    }

    override func tearDown() {
        URLProtocolStub.tearDown()
        super.tearDown()
    }

    // MARK: - Happy path

    func test_get_2xxWithValidJSON_returnsDecodedModel() async throws {
        let body = #"{"message":"hello"}"#.data(using: .utf8)!
        URLProtocolStub.stub(data: body, response: httpResponse(status: 200))

        let client = makeClient()
        let result: Greeting = try await client.get(
            path: path,
            bearerToken: bearer,
            decoder: JSONDecoder()
        )

        XCTAssertEqual(result, Greeting(message: "hello"))
    }

    // MARK: - HTTP status routing

    func test_get_401_throwsUnauthorized() async {
        URLProtocolStub.stub(data: Data(), response: httpResponse(status: 401))

        let client = makeClient()
        do {
            let _: Greeting = try await client.get(
                path: path, bearerToken: bearer, decoder: JSONDecoder()
            )
            XCTFail("Expected APIError.unauthorized")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Expected APIError.unauthorized, got \(error)")
        }
    }

    func test_get_500_throwsServerErrorWithStatus() async {
        URLProtocolStub.stub(data: Data(), response: httpResponse(status: 500))

        let client = makeClient()
        do {
            let _: Greeting = try await client.get(
                path: path, bearerToken: bearer, decoder: JSONDecoder()
            )
            XCTFail("Expected APIError.serverError(500)")
        } catch let error as APIError {
            XCTAssertEqual(error, .serverError(500))
        } catch {
            XCTFail("Expected APIError.serverError(500), got \(error)")
        }
    }

    func test_get_403_throwsServerErrorWithStatus() async {
        // Non-401 4xx also routes through .serverError today — see APIClient
        // file header for the rationale.
        URLProtocolStub.stub(data: Data(), response: httpResponse(status: 403))

        let client = makeClient()
        do {
            let _: Greeting = try await client.get(
                path: path, bearerToken: bearer, decoder: JSONDecoder()
            )
            XCTFail("Expected APIError.serverError(403)")
        } catch let error as APIError {
            XCTAssertEqual(error, .serverError(403))
        } catch {
            XCTFail("Expected APIError.serverError(403), got \(error)")
        }
    }

    // MARK: - Transport failures

    func test_get_transportFailure_throwsNetworkError() async {
        let underlying = URLError(.notConnectedToInternet)
        URLProtocolStub.stub(error: underlying)

        let client = makeClient()
        do {
            let _: Greeting = try await client.get(
                path: path, bearerToken: bearer, decoder: JSONDecoder()
            )
            XCTFail("Expected APIError.networkError")
        } catch let APIError.networkError(inner) {
            XCTAssertEqual((inner as? URLError)?.code, .notConnectedToInternet)
        } catch {
            XCTFail("Expected APIError.networkError, got \(error)")
        }
    }

    // MARK: - Decode failure

    func test_get_2xxWithMalformedJSON_throwsDecodingError() async {
        // 2xx body that does NOT match `Greeting` shape.
        let body = #"{"unexpected":true}"#.data(using: .utf8)!
        URLProtocolStub.stub(data: body, response: httpResponse(status: 200))

        let client = makeClient()
        do {
            let _: Greeting = try await client.get(
                path: path, bearerToken: bearer, decoder: JSONDecoder()
            )
            XCTFail("Expected APIError.decodingError")
        } catch let APIError.decodingError(inner) {
            XCTAssertTrue(inner is DecodingError, "Underlying error should be a DecodingError, got \(inner)")
        } catch {
            XCTFail("Expected APIError.decodingError, got \(error)")
        }
    }

    // MARK: - Invalid configuration

    func test_get_missingBaseURL_throwsInvalidConfiguration() async {
        let client = makeClient(baseURLError: .invalidConfiguration)
        do {
            let _: Greeting = try await client.get(
                path: path, bearerToken: bearer, decoder: JSONDecoder()
            )
            XCTFail("Expected APIError.invalidConfiguration")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidConfiguration)
        } catch {
            XCTFail("Expected APIError.invalidConfiguration, got \(error)")
        }
    }

    // MARK: - Header assertions

    func test_get_setsBearerAndAcceptHeaders() async throws {
        let body = #"{"message":"hi"}"#.data(using: .utf8)!
        URLProtocolStub.stub(data: body, response: httpResponse(status: 200))

        var observedRequest: URLRequest?
        URLProtocolStub.requestObserver = { observedRequest = $0 }

        let client = makeClient()
        let _: Greeting = try await client.get(
            path: path,
            bearerToken: bearer,
            decoder: JSONDecoder()
        )

        guard let request = observedRequest else {
            return XCTFail("URLProtocolStub did not observe a request")
        }
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer \(bearer)"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Accept"),
            "application/json"
        )
    }

    func test_get_buildsURLByAppendingPathToBaseURL() async throws {
        let body = #"{"message":"hi"}"#.data(using: .utf8)!
        URLProtocolStub.stub(data: body, response: httpResponse(status: 200))

        var observedRequest: URLRequest?
        URLProtocolStub.requestObserver = { observedRequest = $0 }

        let client = makeClient()
        // Leading slash on the path must not produce a double slash.
        let _: Greeting = try await client.get(
            path: "/v1/home",
            bearerToken: bearer,
            decoder: JSONDecoder()
        )

        XCTAssertEqual(
            observedRequest?.url?.absoluteString,
            "https://bff.example.com/v1/home"
        )
    }

    // MARK: - APIBaseURLProvider direct tests

    func test_baseURLProvider_missingKey_throwsInvalidConfiguration() {
        XCTAssertThrowsError(try APIBaseURLProvider.load(from: [:])) { error in
            XCTAssertEqual(error as? APIError, .invalidConfiguration)
        }
    }

    func test_baseURLProvider_sentinelValue_throwsInvalidConfiguration() {
        let info: [String: Any] = ["API_BASE_URL": APIBaseURLProvider.sentinel]
        XCTAssertThrowsError(try APIBaseURLProvider.load(from: info)) { error in
            XCTAssertEqual(error as? APIError, .invalidConfiguration)
        }
    }

    func test_baseURLProvider_emptyString_throwsInvalidConfiguration() {
        let info: [String: Any] = ["API_BASE_URL": ""]
        XCTAssertThrowsError(try APIBaseURLProvider.load(from: info)) { error in
            XCTAssertEqual(error as? APIError, .invalidConfiguration)
        }
    }

    func test_baseURLProvider_malformedURL_throwsInvalidConfiguration() {
        let info: [String: Any] = ["API_BASE_URL": "not a url"]
        XCTAssertThrowsError(try APIBaseURLProvider.load(from: info)) { error in
            XCTAssertEqual(error as? APIError, .invalidConfiguration)
        }
    }

    func test_baseURLProvider_validURL_returnsParsedURL() throws {
        let info: [String: Any] = ["API_BASE_URL": "https://bff.example.com/api/"]
        let url = try APIBaseURLProvider.load(from: info)
        XCTAssertEqual(url.absoluteString, "https://bff.example.com/api/")
    }
}
