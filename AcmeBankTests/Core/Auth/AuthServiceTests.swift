//
//  AuthServiceTests.swift
//  AcmeBankTests
//

import XCTest
@testable import AcmeBank

final class AuthServiceTests: XCTestCase {

    // MARK: - Test fakes

    private final class FakeFlow: DirectAuthFlow {
        var nextOutcome: Result<DirectAuthOutcome, Error> =
            .failure(NSError(domain: "test", code: -1))
        private(set) var receivedUsername: String?
        private(set) var receivedPassword: String?
        private(set) var callCount = 0

        func signIn(username: String, password: String) async throws -> DirectAuthOutcome {
            receivedUsername = username
            receivedPassword = password
            callCount += 1
            return try nextOutcome.get()
        }
    }

    private final class FakeKeychain: KeychainStoring {
        var idToken: String?
        var accessToken: String?
        var refreshToken: String?
        var storedRefreshOnDisk: String?
        var clearAllCount = 0
        var loadRefreshResult: Result<String, Error> =
            .failure(KeychainError.itemNotFound)

        func storeIDToken(_ token: String) throws      { idToken = token }
        func storeAccessToken(_ token: String) throws  { accessToken = token }
        func storeRefreshToken(_ token: String) throws { refreshToken = token; storedRefreshOnDisk = token }
        func loadRefreshToken() throws -> String       { try loadRefreshResult.get() }
        func clearAll() throws {
            clearAllCount += 1
            idToken = nil; accessToken = nil; refreshToken = nil; storedRefreshOnDisk = nil
        }
    }

    private final class FakeTransport: TokenRefreshTransport {
        var nextResult: Result<(Data, URLResponse), Error> =
            .failure(URLError(.notConnectedToInternet))
        private(set) var receivedRequest: URLRequest?

        func post(_ request: URLRequest) async throws -> (Data, URLResponse) {
            receivedRequest = request
            return try nextResult.get()
        }
    }

    // MARK: - Fixtures

    private let issuer = URL(string: "https://example.okta.com/oauth2/default")!
    private let clientID = "0oa1234567890abcdef"
    private let redirectURI = URL(string: "com.acmebank.mobile:/callback")!
    private let scopes = "openid profile offline_access"
    private let fixedNow = Date(timeIntervalSince1970: 2_000_000_000)
    private let fixedDevice = "Test Device"

    private func makeIDToken(
        sub: String = "00uABCDEF",
        name: String = "Ada Lovelace",
        email: String = "ada@example.com",
        authTime: TimeInterval? = 1_700_000_000
    ) -> String {
        var payload: [String: Any] = ["sub": sub, "name": name, "email": email]
        if let authTime { payload["auth_time"] = authTime }

        let headerData  = try! JSONSerialization.data(withJSONObject: ["alg": "RS256", "typ": "JWT"])
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        return "\(b64url(headerData)).\(b64url(payloadData)).sig"
    }

    private func b64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func makeSubject(
        flow: FakeFlow,
        keychain: FakeKeychain = FakeKeychain(),
        transport: FakeTransport = FakeTransport()
    ) -> (AuthService, FakeKeychain, FakeTransport) {
        let service = AuthService(
            issuer: issuer,
            clientID: clientID,
            redirectURI: redirectURI,
            scopes: scopes,
            keychain: keychain,
            decoder: IDTokenDecoder(),
            flowFactory: { flow },
            transport: transport,
            deviceNameProvider: { self.fixedDevice },
            now: { self.fixedNow }
        )
        return (service, keychain, transport)
    }

    // MARK: - signIn: happy paths

    func test_signIn_success_returnsUserSessionFromClaims() async throws {
        let idToken = makeIDToken()
        let flow = FakeFlow()
        flow.nextOutcome = .success(.success(OAuthTokens(
            idToken: idToken,
            accessToken: "access-abc",
            refreshToken: "refresh-xyz"
        )))

        let (service, keychain, _) = makeSubject(flow: flow)

        let session = try await service.signIn(
            username: "ada", password: "pw", keepSignedIn: true
        )

        XCTAssertEqual(flow.receivedUsername, "ada")
        XCTAssertEqual(flow.receivedPassword, "pw")

        XCTAssertEqual(session.userId,      "00uABCDEF")
        XCTAssertEqual(session.displayName, "Ada Lovelace")
        XCTAssertEqual(session.email,       "ada@example.com")
        XCTAssertEqual(session.accessToken, "access-abc")
        XCTAssertEqual(session.authTimestamp, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(session.deviceName, fixedDevice)

        XCTAssertEqual(keychain.idToken,      idToken)
        XCTAssertEqual(keychain.accessToken,  "access-abc")
        XCTAssertEqual(keychain.refreshToken, "refresh-xyz")
    }

    func test_signIn_keepSignedInFalse_doesNotPersistRefreshToken() async throws {
        let flow = FakeFlow()
        flow.nextOutcome = .success(.success(OAuthTokens(
            idToken: makeIDToken(),
            accessToken: "access-abc",
            refreshToken: "refresh-xyz"
        )))

        let (service, keychain, _) = makeSubject(flow: flow)

        _ = try await service.signIn(
            username: "ada", password: "pw", keepSignedIn: false
        )

        XCTAssertNotNil(keychain.idToken)
        XCTAssertNotNil(keychain.accessToken)
        XCTAssertNil(keychain.refreshToken,
            "Refresh token must NOT be persisted when keepSignedIn == false.")
    }

    func test_signIn_missingAuthTime_fallsBackToNow() async throws {
        let flow = FakeFlow()
        flow.nextOutcome = .success(.success(OAuthTokens(
            idToken: makeIDToken(authTime: nil),
            accessToken: "access-abc",
            refreshToken: nil
        )))

        let (service, _, _) = makeSubject(flow: flow)

        let session = try await service.signIn(
            username: "ada", password: "pw", keepSignedIn: false
        )

        XCTAssertEqual(session.authTimestamp, fixedNow)
    }

    // MARK: - signIn: error mapping

    func test_signIn_invalidCredentials_mapsToInvalidCredentials() async {
        let flow = FakeFlow()
        flow.nextOutcome = .failure(
            NSError(domain: "okta", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "invalid_grant: bad password",
            ])
        )

        let (service, _, _) = makeSubject(flow: flow)

        await assertAsyncThrows(
            try await service.signIn(username: "ada", password: "wrong", keepSignedIn: false),
            equals: .invalidCredentials
        )
    }

    func test_signIn_mfaRequiredStatus_mapsToMFARequired() async {
        let flow = FakeFlow()
        flow.nextOutcome = .success(.mfaRequired)

        let (service, _, _) = makeSubject(flow: flow)

        await assertAsyncThrows(
            try await service.signIn(username: "ada", password: "pw", keepSignedIn: false),
            equals: .mfaRequired
        )
    }

    func test_signIn_urlError_mapsToNetwork() async {
        let flow = FakeFlow()
        flow.nextOutcome = .failure(URLError(.notConnectedToInternet))

        let (service, _, _) = makeSubject(flow: flow)

        await assertAsyncThrows(
            try await service.signIn(username: "ada", password: "pw", keepSignedIn: false),
            equals: .network
        )
    }

    func test_signIn_unknownError_mapsToUnknown() async {
        let flow = FakeFlow()
        flow.nextOutcome = .failure(
            NSError(domain: "okta", code: 999, userInfo: [
                NSLocalizedDescriptionKey: "something opaque",
            ])
        )

        let (service, _, _) = makeSubject(flow: flow)

        await assertAsyncThrows(
            try await service.signIn(username: "ada", password: "pw", keepSignedIn: false),
            equals: .unknown
        )
    }

    // MARK: - signIn: keychain failures swallowed (lesson-driven)

    func test_signIn_keychainStoreFailure_doesNotPropagate() async throws {
        // A keychain.save failure must NOT make signIn throw — see the
        // lesson on post-SDK-success failures.
        final class ExplodingKeychain: KeychainStoring {
            func storeIDToken(_ token: String) throws      { throw KeychainError.unexpectedStatus(-34018) }
            func storeAccessToken(_ token: String) throws  { throw KeychainError.unexpectedStatus(-34018) }
            func storeRefreshToken(_ token: String) throws { throw KeychainError.unexpectedStatus(-34018) }
            func loadRefreshToken() throws -> String       { throw KeychainError.itemNotFound }
            func clearAll() throws {}
        }

        let flow = FakeFlow()
        flow.nextOutcome = .success(.success(OAuthTokens(
            idToken: makeIDToken(),
            accessToken: "access-abc",
            refreshToken: "refresh-xyz"
        )))

        let service = AuthService(
            issuer: issuer,
            clientID: clientID,
            redirectURI: redirectURI,
            scopes: scopes,
            keychain: ExplodingKeychain(),
            flowFactory: { flow },
            transport: FakeTransport(),
            deviceNameProvider: { self.fixedDevice },
            now: { self.fixedNow }
        )

        // Must NOT throw.
        let session = try await service.signIn(
            username: "ada", password: "pw", keepSignedIn: true
        )
        XCTAssertEqual(session.userId, "00uABCDEF")
    }

    // MARK: - refresh: happy path

    func test_refresh_success_returnsUserSessionAndReWritesTokens() async throws {
        let idToken = makeIDToken(sub: "00uREFRESHED", name: "Ada R", email: "ada@r.example")
        let body: [String: Any] = [
            "access_token":  "access-new",
            "id_token":      idToken,
            "refresh_token": "refresh-new",
            "token_type":    "Bearer",
            "expires_in":    3600,
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let response = HTTPURLResponse(
            url: issuer.appendingPathComponent("v1/token"),
            statusCode: 200, httpVersion: nil, headerFields: nil
        )!

        let transport = FakeTransport()
        transport.nextResult = .success((data, response))

        let (service, keychain, _) = makeSubject(
            flow: FakeFlow(),
            keychain: FakeKeychain(),
            transport: transport
        )

        let session = try await service.refresh(refreshToken: "refresh-old")

        XCTAssertEqual(session.userId,      "00uREFRESHED")
        XCTAssertEqual(session.displayName, "Ada R")
        XCTAssertEqual(session.email,       "ada@r.example")
        XCTAssertEqual(session.accessToken, "access-new")
        XCTAssertEqual(keychain.idToken,      idToken)
        XCTAssertEqual(keychain.accessToken,  "access-new")
        XCTAssertEqual(keychain.refreshToken, "refresh-new")

        // Request shape sanity.
        let request = try XCTUnwrap(transport.receivedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/x-www-form-urlencoded"
        )
        let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(bodyString.contains("grant_type=refresh_token"))
        XCTAssertTrue(bodyString.contains("refresh_token=refresh-old"))
        XCTAssertTrue(bodyString.contains("client_id=\(clientID)"))
    }

    func test_refresh_responseWithoutNewRefreshToken_keepsOldOne() async throws {
        let body: [String: Any] = [
            "access_token": "access-new",
            "id_token":     makeIDToken(),
            "token_type":   "Bearer",
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let response = HTTPURLResponse(url: issuer, statusCode: 200, httpVersion: nil, headerFields: nil)!

        let transport = FakeTransport()
        transport.nextResult = .success((data, response))

        let (service, keychain, _) = makeSubject(
            flow: FakeFlow(),
            keychain: FakeKeychain(),
            transport: transport
        )

        _ = try await service.refresh(refreshToken: "still-good")

        XCTAssertEqual(keychain.refreshToken, "still-good",
            "If the IdP doesn't issue a new refresh token, the existing one must remain stored.")
    }

    // MARK: - refresh: failure mapping + cache clearing

    func test_refresh_transportFailure_mapsToNetworkAndClearsKeychain() async {
        let transport = FakeTransport()
        transport.nextResult = .failure(URLError(.notConnectedToInternet))

        let (service, keychain, _) = makeSubject(
            flow: FakeFlow(),
            keychain: FakeKeychain(),
            transport: transport
        )

        await assertAsyncThrows(
            try await service.refresh(refreshToken: "anything"),
            equals: .network
        )
        XCTAssertEqual(keychain.clearAllCount, 1,
            "On refresh transport failure, AuthService must clear the stored refresh token.")
    }

    func test_refresh_400_mapsToInvalidCredentialsAndClearsKeychain() async throws {
        let response = HTTPURLResponse(url: issuer, statusCode: 400, httpVersion: nil, headerFields: nil)!
        let transport = FakeTransport()
        transport.nextResult = .success((Data(), response))

        let (service, keychain, _) = makeSubject(
            flow: FakeFlow(),
            keychain: FakeKeychain(),
            transport: transport
        )

        await assertAsyncThrows(
            try await service.refresh(refreshToken: "stale"),
            equals: .invalidCredentials
        )
        XCTAssertEqual(keychain.clearAllCount, 1)
    }

    func test_refresh_500_mapsToNetwork() async {
        let response = HTTPURLResponse(url: issuer, statusCode: 500, httpVersion: nil, headerFields: nil)!
        let transport = FakeTransport()
        transport.nextResult = .success((Data(), response))

        let (service, _, _) = makeSubject(
            flow: FakeFlow(),
            keychain: FakeKeychain(),
            transport: transport
        )

        await assertAsyncThrows(
            try await service.refresh(refreshToken: "x"),
            equals: .network
        )
    }

    // MARK: - Helpers

    /// Small async-throws assertion: runs the autoclosure, expects a typed
    /// AuthError, and reports nicely if it didn't throw or threw the wrong
    /// case.
    private func assertAsyncThrows<T>(
        _ expression: @autoclosure () async throws -> T,
        equals expected: AuthError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected to throw \(expected), but did not throw", file: file, line: line)
        } catch let error as AuthError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Expected AuthError.\(expected), got \(error)", file: file, line: line)
        }
    }
}
