import Foundation
import AuthenticationServices
import FirebaseCore
import FirebaseAuth
import CryptoUtils

final class AppleAuthProvider: NSObject,
                               ASAuthorizationControllerDelegate,
                               ASAuthorizationControllerPresentationContextProviding {

    private var appleIDCredentialObtainContinuation: UnsafeContinuation<ASAuthorizationAppleIDCredential, Error>?

    private var currentNonce: String?

    func signIn() async throws {
        let appleIDCredential = try await self.obtainAppleIdCredential()

        guard let appleIDToken = appleIDCredential.identityToken else {
            throw AppleAuthProviderError.unableToReadAppleIDToken
        }

        guard let nonce = self.currentNonce else {
            throw AppleAuthProviderError.nonceIsMissed
        }

        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AppleAuthProviderError.unableToSerializeAppleIDToken
        }

        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                       rawNonce: nonce,
                                                       fullName: appleIDCredential.fullName)

        try await Auth.auth().signIn(with: credential)
    }

    func deleteUser() async throws {
        let appleIDCredential = try await self.obtainAppleIdCredential()

        guard let _ = self.currentNonce else {
            throw AppleAuthProviderError.nonceIsMissed
        }

        guard let appleAuthCode = appleIDCredential.authorizationCode else {
            throw AppleAuthProviderError.unableToFetchAuthorizationCode
        }

        guard let authCodeString = String(data: appleAuthCode, encoding: .utf8) else {
            throw AppleAuthProviderError.unableToSerializeAppleAuthCode
        }

        try await Auth.auth().revokeToken(withAuthorizationCode: authCodeString)
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    @MainActor
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }

    // MARK: - ASAuthorizationControllerDelegate

    @MainActor
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            self.appleIDCredentialObtainContinuation?.resume(throwing: AppleAuthProviderError.unableToReadAppleIDCredential)
            return
        }

        self.appleIDCredentialObtainContinuation?.resume(returning: appleIDCredential)
    }

    @MainActor
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        self.appleIDCredentialObtainContinuation?.resume(throwing: error)
    }

    // MARK: Private Methods

    private func obtainAppleIdCredential() async throws -> ASAuthorizationAppleIDCredential {
        let nonce = try RandomNonceStringProvider.randomNonceString()
        self.currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = SHA256Fabric.sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()

        return try await withUnsafeThrowingContinuation { continuation in
            self.appleIDCredentialObtainContinuation = continuation
        }
    }

}
