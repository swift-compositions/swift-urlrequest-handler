import Dependencies_Test_Support
import Testing

@testable import URLRequestHandler

@Suite(.dependencies)
struct Test {

    // MARK: - Basic Request Handling (Lines 49-71)

    @Test
    func `README Line 49-71: Basic Request Handling`() async throws {
        struct User: Decodable {
            let id: String
            let name: String
            let email: String
        }

        try await withDependencies {
            $0.defaultSession = Fixture.session(
                statusCode: 200,
                body: """
                    {"id": "123", "name": "John Doe", "email": "john@example.com"}
                    """
            )
        } operation: {
            @Dependency(\.defaultRequestHandler) var requestHandler

            let request = Fixture.request("https://api.example.com/users/123")

            let user: User = try await requestHandler(
                for: request,
                decodingTo: User.self
            )

            #expect(user.id == "123")
            #expect(user.name == "John Doe")
            #expect(user.email == "john@example.com")
        }
    }

    // MARK: - Envelope Response Pattern (Lines 73-93)

    @Test
    func `README Line 73-93: Envelope Response Pattern`() async throws {
        struct User: Decodable {
            let id: String
            let name: String
        }

        try await withDependencies {
            $0.defaultSession = Fixture.session(
                statusCode: 200,
                body: """
                    {
                      "success": true,
                      "data": { "id": "123", "name": "John" },
                      "message": "User fetched successfully",
                      "timestamp": "2024-01-01T00:00:00Z"
                    }
                    """
            )
        } operation: {
            @Dependency(\.defaultRequestHandler) var requestHandler

            let request = Fixture.request("https://api.example.com/user")

            let user: User = try await requestHandler(
                for: request,
                decodingTo: User.self
            )

            #expect(user.id == "123")
            #expect(user.name == "John")
        }
    }

    // MARK: - Custom JSON Decoder (Lines 95-106)

    @Test
    func `README Line 95-106: Custom JSON Decoder`() async throws {
        struct Response: Decodable {
            let id: String
        }

        try await withDependencies {
            $0.defaultSession = Fixture.session(
                statusCode: 200,
                body: """
                    {"id": "123"}
                    """
            )
        } operation: {
            let handler = Fixture.handlerDecodingSecondsSince1970WithDefaultKeys()

            let request = Fixture.request("https://api.example.com/test")

            let response: Response = try await handler(
                for: request,
                decodingTo: Response.self
            )

            #expect(response.id == "123")
        }
    }

    // MARK: - Void Requests (Lines 108-117)

    @Test
    func `README Line 108-117: Void Requests`() async throws {
        try await withDependencies {
            $0.defaultSession = Fixture.session(statusCode: 204)
        } operation: {
            @Dependency(\.defaultRequestHandler) var requestHandler

            let request = Fixture.request("https://api.example.com/logout", method: "POST")

            // Should not throw
            try await requestHandler(for: request)
        }
    }

    // MARK: - Error Handling (Lines 119-136)

    @Test
    func `README Line 119-136: Error Handling`() async throws {
        struct User: Decodable {
            let id: String
        }

        // Test HTTP Error
        try await withDependencies {
            $0.defaultSession = Fixture.session(
                statusCode: 404,
                body: """
                    {"message": "Not found"}
                    """
            )
        } operation: {
            @Dependency(\.defaultRequestHandler) var requestHandler

            let request = Fixture.request("https://api.example.com/user")

            do {
                let _ = try await requestHandler(
                    for: request,
                    decodingTo: User.self
                )
                Issue.record("Expected HTTP error")
            } catch RequestError.httpError(let statusCode, let message) {
                #expect(statusCode == 404)
                #expect(message.contains("Not found"))
            }
        }
    }

    // MARK: - Testing with Mocks (Lines 140-176)

    @Test
    func `README Line 140-176: Testing with Mocks`() async throws {
        struct User: Decodable {
            let id: String
            let name: String
        }

        try await withDependencies {
            $0.defaultSession = Fixture.session(
                statusCode: 200,
                body: """
                    {"id": "123", "name": "Test User"}
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
        }
    }

    // MARK: - Custom URLSession (Lines 178-193)

    @Test
    func `README Line 178-193: Custom URLSession`() async throws {
        struct Response: Decodable {
            let id: String
        }

        try await withDependencies {
            $0.defaultSession = Fixture.session(
                statusCode: 200,
                body: """
                    {"id": "123"}
                    """
            )
        } operation: {
            @Dependency(\.defaultRequestHandler) var handler

            let request = Fixture.request("https://api.example.com/test")
            let response: Response = try await handler(
                for: request,
                decodingTo: Response.self
            )

            #expect(response.id == "123")
        }
    }

    // MARK: - URLRequest.Handler API (Lines 198-208)

    @Test
    func `README Line 198-208: URLRequest.Handler API`() {
        let handler = Fixture.handler(debug: false)

        #expect(handler.debug == false)

        let handlerWithCustomDecoder = Fixture.handlerWithISO8601Decoder(debug: true)

        #expect(handlerWithCustomDecoder.debug == true)
    }

    // MARK: - RequestError Types (Lines 210-222)

    @Test
    func `README Line 210-222: Request Error Types`() {
        let invalidResponseError = RequestError.invalidResponse
        let httpError = RequestError.httpError(statusCode: 404, message: "Not found")
        let envelopeDataMissingError = RequestError.envelopeDataMissing

        #expect(invalidResponseError == .invalidResponse)

        if case .httpError(let code, let msg) = httpError {
            #expect(code == 404)
            #expect(msg == "Not found")
        }

        #expect(envelopeDataMissingError == .envelopeDataMissing)
    }

    // MARK: - Envelope Structure (Lines 224-239)

    @Test
    func `README Line 224-239: Envelope Structure`() throws {
        struct TestData: Codable, Equatable {
            let value: String
        }

        let envelope = Envelope<TestData>(
            success: true,
            data: TestData(value: "test"),
            message: "Success"
        )

        #expect(envelope.success == true)
        #expect(envelope.data == TestData(value: "test"))
        #expect(envelope.message == "Success")
        #expect(Fixture.isNotInTheFuture(envelope.timestamp))

        // Test encoding/decoding
        let decoded = try Fixture.roundTripISO8601(envelope)

        #expect(decoded.success == envelope.success)
        #expect(decoded.data == envelope.data)
        #expect(decoded.message == envelope.message)
    }
}
