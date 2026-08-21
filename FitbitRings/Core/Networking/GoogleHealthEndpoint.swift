import Foundation

struct GoogleHealthEndpoint {
    private let baseURL = URL(string: "https://health.googleapis.com/v4")!

    func request(path: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidURL(path)
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw NetworkError.invalidURL(path)
        }

        return URLRequest(url: url)
    }
}
