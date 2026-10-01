import Dependencies_Test_Support
import Testing

@testable import URLRequestHandler

@Suite(.dependencies)
struct URLRequestHandlerTests {
    // MARK: - Basic Functionality Tests

    @Test
    func `Successful Direct Response`() async throws {
        try await withDependencies {
            $0.defaultSession = Fixture.session(
                statusCode: 200,
                body: """
                    {"id": "123", "name": "Test User", "email": "test@example.com"}
                    """
            )
        } operation: {
            @Dependency(\.defaultRequestHandler) var handler

            let request = Fixture.request("https://api.example.com/user")
            let user: User = try await handler(
                for: request,
                decodingTo: User.self
            )

            #expect(user.id == "123")
            #expect(user.name == "Test User")
            #expect(user.email == "test@example.com")
        }
    }

    @Test
    func `Successful Envelope Response`() async throws {
        try await withDependencies {
            $0.defaultSession = Fixture.session(
                statusCode: 200,
                body: """
                    {
                        "success": true,
                        "data": {"id": "456", "name": "Envelope User", "email": "envelope@example.com"},
                        "message": "User fetched successfully",
                        "timestamp": "2024-01-01T00:00:00Z"
                    }
                    """
            )
        } operation: {
            @Dependency(\.defaultRequestHandler) var handler

            let request = Fixture.request("https://api.example.com/user")
            let user: User = try await handler(
                for: request,
                decodingTo: User.self
            )

            #expect(user.id == "456")
            #expect(user.name == "Envelope User")
            #expect(user.email == "envelope@example.com")
        }
    }

    @Test
    func `Void Request`() async throws {
        try await withDependencies {
            $0.defaultSession = Fixture.session(statusCode: 204)
        } operation: {
            @Dependency(\.defaultRequestHandler) var handler

            let request = Fixture.request("https://api.example.com/logout")

            // Should not throw
            try await handler(for: request)
        }
    }

    // MARK: - Error Handling Tests

    @Test
    func `HTTPError`() async throws {
        try await withDependencies {
            $0.defaultSession = Fixture.session(
                statusCode: 404,
                body: """
                    {"message": "User not found"}
                    """
            )
        } operation: {
            @Dependency(\.defaultRequestHandler) var handler

            let request = Fixture.request("https://api.example.com/user/999")

            do {
                let _: User = try await handler(
                    for: request,
                    decodingTo: User.self
                )
                #expect(Bool(false), "Should have thrown an error")
            } catch let error as RequestError {
                if case .httpError(let statusCode, let message) = error {
                    #expect(statusCode == 404)
                    #expect(message == "User not found")
                } else {
                    #expect(Bool(false), "Wrong error type: \(error)")
                }
            }
        }
    }

    @Test
    func `Decoding Error`() async throws {
        try await withDependencies {
            $0.defaultSession = Fixture.session(
                statusCode: 200,
                body: """
                    {"invalid": "json structure"}
                    """
            )
        } operation: {
            @Dependency(\.defaultRequestHandler) var handler

            let request = Fixture.request("https://api.example.com/user")

            do {
                let _: User = try await handler(
                    for: request,
                    decodingTo: User.self
                )
                #expect(Bool(false), "Should have thrown a decoding error")
            } catch let error as RequestError {
                if case .decodingError(let context) = error {
                    #expect(context.attemptedType.contains("User"))
                    #expect(context.rawData?.contains("invalid") == true)
                } else {
                    #expect(Bool(false), "Wrong error type: \(error)")
                }
            }
        }
    }

    @Test
    func `Envelope With No Data`() async throws {
        try await withDependencies {
            $0.defaultSession = Fixture.session(
                statusCode: 200,
                body: """
                    {
                        "success": true,
                        "data": null,
                        "message": "No data available",
                        "timestamp": "2024-01-01T00:00:00Z"
                    }
                    """
            )
        } operation: {
            @Dependency(\.defaultRequestHandler) var handler

            let request = Fixture.request("https://api.example.com/user")

            do {
                let _: User = try await handler(
                    for: request,
                    decodingTo: User.self
                )
                #expect(Bool(false), "Should have thrown envelopeDataMissing error")
            } catch RequestError.envelopeDataMissing {
                // Expected error
            }
        }
    }

    // MARK: - URLSession Dependency Tests

    @Test
    func `Default Session Key`() async throws {
        let probe = Fixture.SessionProbe()

        try await withDependencies {
            $0.defaultSession = probe.session
        } operation: {
            @Dependency(\.defaultSession) var session

            let request = Fixture.request("https://example.com")
            let (data, response) = try await session(request)

            #expect(probe.requestedURLStrings == ["https://example.com"])
            #expect(probe.returnedData(data))
            #expect(probe.returnedResponse(response))
        }
    }

    // MARK: - Envelope Type Tests

    @Test
    func `Envelope Decoding`() throws {
        struct TestData: Decodable {
            let value: String
        }

        let envelope = try Fixture.decodeISO8601(
            Envelope<TestData>.self,
            json: """
                {
                    "success": true,
                    "data": {"value": "test"},
                    "message": "Success",
                    "timestamp": "2024-01-01T00:00:00Z"
                }
                """
        )

        #expect(envelope.success == true)
        #expect(envelope.data?.value == "test")
        #expect(envelope.message == "Success")
        #expect(envelope.timestamp != nil)
    }

    @Test
    func `Envelope Encoding`() throws {
        struct TestData: Codable {
            let value: String
        }

        let envelope = Envelope(
            success: true,
            data: TestData(value: "test"),
            message: "Test message"
        )

        let json = try Fixture.encodeISO8601String(envelope)

        #expect(json.contains("\"success\":true"))
        #expect(json.contains("\"value\":\"test\""))
        #expect(json.contains("\"message\":\"Test message\""))
        #expect(json.contains("\"timestamp\""))
    }

    // MARK: - Custom Decoder Tests

    @Test
    func `Custom Decoder`() async throws {
        try await withDependencies {
            $0.defaultSession = Fixture.session(
                statusCode: 200,
                body: """
                    {"user_id": "789", "user_name": "Snake Case User", "email_address": "snake@example.com"}
                    """
            )
        } operation: {
            let handler = Fixture.handlerConvertingFromSnakeCase()

            struct SnakeCaseUser: Decodable {
                let userId: String
                let userName: String
                let emailAddress: String
            }

            let request = Fixture.request("https://api.example.com/user")
            let user: SnakeCaseUser = try await handler(
                for: request,
                decodingTo: SnakeCaseUser.self
            )

            #expect(user.userId == "789")
            #expect(user.userName == "Snake Case User")
            #expect(user.emailAddress == "snake@example.com")
        }
    }
}

// MARK: - Test Models

private struct User: Decodable {
    let id: String
    let name: String
    let email: String
}
