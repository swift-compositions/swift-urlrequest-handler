import Foundation
import Synchronization

@testable import URLRequestHandler

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

enum Fixture {
    typealias Session = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static func request(_ url: String, method: String? = nil) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        if let method {
            request.httpMethod = method
        }
        return request
    }

    static func session(statusCode: Int, body: String = "") -> Session {
        { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(body.utf8), response)
        }
    }

    static func handler() -> URLRequest.Handler {
        URLRequest.Handler()
    }

    static func handler(debug: Bool) -> URLRequest.Handler {
        URLRequest.Handler(debug: debug, decoder: JSONDecoder())
    }

    static func handlerWithISO8601Decoder(debug: Bool) -> URLRequest.Handler {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return URLRequest.Handler(debug: debug, decoder: decoder)
    }

    static func handlerConvertingFromSnakeCase() -> URLRequest.Handler {
        var handler = URLRequest.Handler()
        handler.decoder.keyDecodingStrategy = .convertFromSnakeCase
        return handler
    }

    static func handlerDecodingSecondsSince1970WithDefaultKeys() -> URLRequest.Handler {
        let handler = URLRequest.Handler()
        handler.decoder.dateDecodingStrategy = .secondsSince1970
        handler.decoder.keyDecodingStrategy = .useDefaultKeys
        return handler
    }

    static func decodeISO8601<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: Data(json.utf8))
    }

    static func encodeISO8601String<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return String(data: try encoder.encode(value), encoding: .utf8)!
    }

    static func roundTripISO8601<T: Codable>(_ value: T) throws -> T {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    static func isNotInTheFuture(_ timestamp: Date) -> Bool {
        timestamp <= Date()
    }
}

extension Fixture {
    final class SessionProbe: Sendable {
        let data = Data("test".utf8)
        nonisolated(unsafe) let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        private let requestedURLs = Mutex<[String?]>([])

        var session: Session {
            { [self] request in
                requestedURLs.withLock { $0.append(request.url?.absoluteString) }
                return (data, response)
            }
        }

        var requestedURLStrings: [String?] {
            requestedURLs.withLock { $0 }
        }

        func returnedData(_ data: Data) -> Bool {
            data == self.data
        }

        func returnedResponse(_ response: URLResponse) -> Bool {
            response == self.response
        }
    }
}
