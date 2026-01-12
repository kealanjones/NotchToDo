import Foundation

/// Minimal façade around Supabase's REST/Storage endpoints. We defer
/// third-party SDK dependencies until we confirm requirements, but keep an
/// ergonomic surface area for higher-level sync code.
public final class SupabaseService {
    public struct Configuration {
        public let projectURL: URL
        public let anonKey: String
        public let storageBucket: String
        
        public init(projectURL: URL, anonKey: String, storageBucket: String) {
            self.projectURL = projectURL
            self.anonKey = anonKey
            self.storageBucket = storageBucket
        }
    }

    public static let iso8601FormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    public enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    public enum ServiceError: Error {
        case invalidConfiguration
        case invalidResponse(status: Int, body: String)
        case missingCredentials
    }

    private let configuration: Configuration
    private let urlSession: URLSession
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    public init(configuration: Configuration, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        jsonDecoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = SupabaseService.parseISO8601Date(string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date string: \(string)"
            )
        }
        jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
        jsonEncoder.dateEncodingStrategy = .custom { date, encoder in
            let string = SupabaseService.iso8601FormatterWithFractional.string(from: date)
            var container = encoder.singleValueContainer()
            try container.encode(string)
        }
    }

    public func makeRequest(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        accessToken: String? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(url: configuration.projectURL, resolvingAgainstBaseURL: false) else {
            throw ServiceError.invalidConfiguration
        }
        components.path = "/rest/v1/\(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw ServiceError.invalidConfiguration
        }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue(configuration.anonKey, forHTTPHeaderField: "Authorization")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try jsonEncoder.encode(AnyEncodable(body))
        }

        // Verbose request log (without body)
        let methodLabel = request.httpMethod ?? "<METHOD>"
        DebugLog.log("Supabase request: \(methodLabel) \(request.url?.absoluteString ?? "<url>")", category: .sync)

        return request
    }

    public func perform<T: Decodable>(_ request: URLRequest, decode: T.Type) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            DebugLog.log("Supabase request failed [\(status)]: \(body)", category: .sync)
            throw ServiceError.invalidResponse(status: status, body: body)
        }

        // Success log (status, method, url)
        let status = httpResponse.statusCode
        let methodLabel = request.httpMethod ?? "<METHOD>"
        DebugLog.log("Supabase OK [\(status)]: \(methodLabel) \(request.url?.absoluteString ?? "<url>")", category: .sync)

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            DebugLog.log("Supabase decode failed (\(T.self)): \(error) — body: \(body)", category: .sync)
            throw error
        }
    }

    public func perform(_ request: URLRequest) async throws {
        let _: EmptyResponse = try await perform(request, decode: EmptyResponse.self)
    }

    // MARK: - Auth

    public func makeAuthRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]
    ) throws -> URLRequest {
        guard var components = URLComponents(url: configuration.projectURL, resolvingAgainstBaseURL: false) else {
            throw ServiceError.invalidConfiguration
        }
        components.path = "/auth/v1/\(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw ServiceError.invalidConfiguration
        }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        DebugLog.log("Supabase auth request: POST \(request.url?.absoluteString ?? "<url>")", category: .sync)
        return request
    }

    public func performAuth<T: Decodable>(_ request: URLRequest, decode: T.Type) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            DebugLog.log("Supabase auth failed [\(status)]: \(body)", category: .sync)
            throw ServiceError.invalidResponse(status: status, body: body)
        }
        DebugLog.log("Supabase auth OK [\((response as? HTTPURLResponse)?.statusCode ?? -1)]: POST \(request.url?.absoluteString ?? "<url>")", category: .sync)
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            DebugLog.log("Supabase auth decode failed (\(T.self)): \(error) — body: \(body)", category: .sync)
            throw error
        }
    }

    // MARK: - Storage

    public func storageUploadURL(for path: String) -> URL {
        configuration.projectURL
            .appendingPathComponent("storage/v1/object")
            .appendingPathComponent("\(configuration.storageBucket)/\(path)")
    }
}

// MARK: - Helpers

public struct EmptyResponse: Decodable {}

private extension SupabaseService {
    static func parseISO8601Date(_ string: String) -> Date? {
        if let date = iso8601FormatterWithFractional.date(from: string) {
            return date
        }
        return iso8601Formatter.date(from: string)
    }
}

extension SupabaseService.ServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Supabase configuration is incomplete."
        case .missingCredentials:
            return "Supabase credentials are missing."
        case .invalidResponse(let status, let body):
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if let message = SupabaseService.extractErrorMessage(from: trimmedBody) {
                return "Supabase responded with \(status): \(message)"
            } else if !trimmedBody.isEmpty {
                return "Supabase responded with \(status): \(trimmedBody)"
            } else {
                return "Supabase responded with status code \(status)."
            }
        }
    }
}

private extension SupabaseService {
    static func extractErrorMessage(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let message = json["message"] as? String { return message }
        if let errorDescription = json["error_description"] as? String { return errorDescription }
        if let error = json["error"] as? String { return error }
        return nil
    }
}

private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ encodable: any Encodable) {
        encodeClosure = encodable.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
