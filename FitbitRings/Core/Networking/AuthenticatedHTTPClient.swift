import Foundation

protocol HTTPClient {
    func send<T: Decodable>(_ request: URLRequest, decoding type: T.Type) async throws -> T
}

final class AuthenticatedHTTPClient: HTTPClient {
    private let session: URLSession
    private weak var authProvider: AuthProviding?
    private let decoder: JSONDecoder

    init(
        session: URLSession = .shared,
        authProvider: AuthProviding,
        decoder: JSONDecoder = JSONDecoder.googleHealthDecoder
    ) {
        self.session = session
        self.authProvider = authProvider
        self.decoder = decoder
    }

    func send<T: Decodable>(_ request: URLRequest, decoding type: T.Type) async throws -> T {
        guard let authProvider else {
            throw NetworkError.unauthenticated
        }

        var request = request
        request.setValue("Bearer \(try await authProvider.accessToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let googleError = try? decoder.decode(GoogleAPIErrorResponse.self, from: data)
            throw NetworkError.httpStatus(httpResponse.statusCode, googleError?.error.message)
        }

        return try decoder.decode(T.self, from: data)
    }
}

enum NetworkError: LocalizedError, Equatable {
    case unauthenticated
    case invalidResponse
    case invalidURL(String)
    case httpStatus(Int, String?)

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "You need to reconnect Google Health."
        case .invalidResponse:
            return "Google Health returned an invalid response."
        case .invalidURL(let path):
            return "Unable to build Google Health URL for \(path)."
        case .httpStatus(let status, let message):
            return message ?? "Google Health request failed with status \(status)."
        }
    }
}

struct GoogleAPIErrorResponse: Decodable {
    var error: GoogleAPIError
}

struct GoogleAPIError: Decodable {
    var code: Int?
    var message: String?
    var status: String?
}

extension JSONDecoder {
    static var googleHealthDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.googleHealth.date(from: value)
                ?? ISO8601DateFormatter.googleHealthNoFractions.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Google Health date: \(value)"
            )
        }
        return decoder
    }
}

extension ISO8601DateFormatter {
    static let googleHealthNoFractions: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let googleHealth: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
