import Foundation
import UIKit

protocol AuthProviding: AnyObject {
    var currentUserEmail: String? { get }
    func restorePreviousSignIn() async -> Bool
    func signIn(presenting viewController: UIViewController) async throws
    func signOut()
    func accessToken() async throws -> String
}

enum AuthenticationError: LocalizedError {
    case missingPresenter
    case missingAccessToken
    case missingScopes([String])
    case invalidGoogleConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .missingPresenter:
            return "Unable to find a view controller for Google sign-in."
        case .missingAccessToken:
            return "Google did not return an access token."
        case .missingScopes(let scopes):
            return "Google Health permissions are missing: \(scopes.joined(separator: ", "))."
        case .invalidGoogleConfiguration(let message):
            return message
        }
    }
}

enum GoogleSignInConfiguration {
    private static let setupMessage = "Google Sign-In is not configured. Set GOOGLE_CLIENT_ID and REVERSED_GOOGLE_CLIENT_ID in the Fitbit Rings target build settings."

    static func validate(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) throws {
        if let error = validationError(infoDictionary: infoDictionary) {
            throw error
        }
    }

    static func validationError(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) -> AuthenticationError? {
        guard let clientID = trimmedString(for: "GIDClientID", in: infoDictionary),
              !isPlaceholder(clientID) else {
            return .invalidGoogleConfiguration(setupMessage)
        }

        let expectedScheme = callbackURLScheme(forClientID: clientID)
        let hasMatchingScheme = urlSchemes(in: infoDictionary).contains { scheme in
            scheme.caseInsensitiveCompare(expectedScheme) == .orderedSame
        }

        guard hasMatchingScheme else {
            return .invalidGoogleConfiguration(
                "Google Sign-In callback URL scheme is missing. Set REVERSED_GOOGLE_CLIENT_ID to \(expectedScheme)."
            )
        }

        return nil
    }

    static func callbackURLScheme(forClientID clientID: String) -> String {
        let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmedClientID
            .split(separator: ".")
            .map(String.init)

        guard components.count > 1 else {
            return trimmedClientID.lowercased()
        }

        return components.reversed().joined(separator: ".").lowercased()
    }

    private static func trimmedString(for key: String, in infoDictionary: [String: Any]?) -> String? {
        guard let value = infoDictionary?[key] as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isPlaceholder(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.hasPrefix("$(")
            || normalized.range(of: "REPLACE_WITH", options: .caseInsensitive) != nil
    }

    private static func urlSchemes(in infoDictionary: [String: Any]?) -> [String] {
        guard let urlTypes = infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else {
            return []
        }

        return urlTypes.flatMap { urlType in
            urlType["CFBundleURLSchemes"] as? [String] ?? []
        }
    }
}

enum GoogleHealthScopes {
    static let activityAndFitness = "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly"
    static let healthMetrics = "https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly"
    static let sleep = "https://www.googleapis.com/auth/googlehealth.sleep.readonly"

    static let mvpReadScopes = [
        activityAndFitness,
        healthMetrics,
        sleep
    ]
}
