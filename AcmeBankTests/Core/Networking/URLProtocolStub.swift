//
//  URLProtocolStub.swift
//  AcmeBankTests
//
//  Reusable `URLProtocol` subclass that intercepts every request made
//  through a `URLSession` whose `URLSessionConfiguration.protocolClasses`
//  includes this type. The intercept lets unit tests run the full
//  `URLSession.data(for:)` code path inside `URLSessionAPIClient` without
//  touching the network — the canonical Apple-recommended pattern for
//  testing networking code.
//
//  Usage:
//
//      URLProtocolStub.stub(
//          data: jsonData,
//          response: HTTPURLResponse(url: ..., statusCode: 200, ...)!
//      )
//      let config = URLSessionConfiguration.ephemeral
//      config.protocolClasses = [URLProtocolStub.self]
//      let session = URLSession(configuration: config)
//      // ... pass `session` into URLSessionAPIClient ...
//
//  Notes:
//  - State is held in `static` storage because `URLProtocol` instances are
//    constructed by URLLoadingSystem internals; we can't reach in to set
//    instance properties.
//  - `tearDown()` MUST be called in `setUp()` of each test (or `tearDown()`)
//    to avoid cross-test contamination.
//  - `requestObserver` captures the last request for header assertions.
//

import Foundation
import XCTest

final class URLProtocolStub: URLProtocol {

    // MARK: - Stub state (static — see file header)

    /// Configured response payload for the next request.
    private struct Stub {
        let data: Data?
        let response: URLResponse?
        let error: Error?
    }

    private static var stub: Stub?

    /// Closure called with every intercepted `URLRequest` BEFORE the stub
    /// fires — used to assert on headers, method, URL, etc.
    static var requestObserver: ((URLRequest) -> Void)?

    // MARK: - Public configuration API

    /// Configure the stub to return `(data, response)` for the next request.
    static func stub(data: Data?, response: URLResponse) {
        stub = Stub(data: data, response: response, error: nil)
    }

    /// Configure the stub to fail with `error` (i.e. simulate a transport
    /// failure) for the next request.
    static func stub(error: Error) {
        stub = Stub(data: nil, response: nil, error: error)
    }

    /// Reset all stub state and observers. Call from `setUp`/`tearDown`.
    static func tearDown() {
        stub = nil
        requestObserver = nil
    }

    // MARK: - URLProtocol overrides

    override class func canInit(with request: URLRequest) -> Bool {
        // Intercept every request routed through a session that includes us
        // in its protocolClasses.
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        // Surface the request to the observer (e.g. for header assertions)
        // BEFORE responding so the test can fail fast with a clear message
        // if the request is malformed.
        URLProtocolStub.requestObserver?(request)

        guard let stub = URLProtocolStub.stub else {
            // No stub configured — fail loudly. Silent stalls here are the
            // single most painful debugging session in URLProtocol-based
            // tests.
            client?.urlProtocol(
                self,
                didFailWithError: NSError(
                    domain: "URLProtocolStub",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No stub configured. Call URLProtocolStub.stub(...) before issuing the request."]
                )
            )
            return
        }

        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let response = stub.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data = stub.data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // Nothing to clean up — single-shot stub.
    }
}

// MARK: - Convenience: build a URLSession wired to the stub

extension URLProtocolStub {
    /// Build an ephemeral `URLSession` whose only protocol class is this
    /// stub. Tests pass the returned session into `URLSessionAPIClient`.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }
}
