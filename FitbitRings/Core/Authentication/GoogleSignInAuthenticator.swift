#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import Foundation
import UIKit

final class GoogleSignInAuthenticator: AuthProviding {
    private let credentialStore: KeychainCredentialStore

    init(credentialStore: KeychainCredentialStore = KeychainCredentialStore()) {
        self.credentialStore = credentialStore
    }

    var currentUserEmail: String? {
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.currentUser?.profile?.email ?? credentialStore.email
        #else
        credentialStore.email
        #endif
    }

    @MainActor
    func restorePreviousSignIn() async -> Bool {
        #if canImport(GoogleSignIn)
        guard GoogleSignInConfiguration.validationError() == nil else {
            return false
        }

        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else {
            return false
        }

        do {
            _ = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            if let email = GIDSignIn.sharedInstance.currentUser?.profile?.email {
                credentialStore.email = email
            }
            return true
        } catch {
            credentialStore.email = nil
            return false
        }
        #else
        return false
        #endif
    }

    @MainActor
    func signIn(presenting viewController: UIViewController) async throws {
        #if canImport(GoogleSignIn)
        try GoogleSignInConfiguration.validate()

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: viewController,
            hint: nil,
            additionalScopes: GoogleHealthScopes.mvpReadScopes
        )

        try validateGrantedScopes(result.user.grantedScopes ?? [])
        credentialStore.email = result.user.profile?.email
        #else
        throw AuthenticationError.missingAccessToken
        #endif
    }

    func signOut() {
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
        credentialStore.email = nil
    }

    func accessToken() async throws -> String {
        #if canImport(GoogleSignIn)
        try GoogleSignInConfiguration.validate()

        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw AuthenticationError.missingAccessToken
        }

        let freshUser = try await user.refreshTokensIfNeeded()
        try validateGrantedScopes(freshUser.grantedScopes ?? [])

        guard let token = freshUser.accessToken.tokenString.nilIfEmpty else {
            throw AuthenticationError.missingAccessToken
        }

        return token
        #else
        throw AuthenticationError.missingAccessToken
        #endif
    }

    private func validateGrantedScopes(_ grantedScopes: [String]) throws {
        let granted = Set(grantedScopes)
        let missing = GoogleHealthScopes.mvpReadScopes.filter { !granted.contains($0) }
        guard missing.isEmpty else {
            throw AuthenticationError.missingScopes(missing)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
