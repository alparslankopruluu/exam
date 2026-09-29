import Foundation
import UIKit
import CryptoKit
import AuthenticationServices
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

enum AccountProvider: String {
    case email = "password"
    case google = "google.com"
    case apple = "apple.com"
}

struct AccountSnapshot: Equatable {
    var isSignedIn = false
    var isAnonymous = true
    var email: String?
    var providers: [AccountProvider] = []
}

enum AuthServiceError: LocalizedError {
    case firebaseUnavailable
    case missingPresenter
    case missingToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .firebaseUnavailable: return "Account services are not configured yet."
        case .missingPresenter: return "Could not open the sign-in screen."
        case .missingToken: return "Sign-in did not return a valid token."
        case .cancelled: return nil
        }
    }
}

/// Upgrades the anonymous Firebase session to a permanent account.
/// Linking keeps the same UID, so cloud study data stays attached to the user.
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var account = AccountSnapshot()

    private var listener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    private init() {}

    func start() {
        guard FirebaseApp.app() != nil, listener == nil else { return }
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.account = Self.snapshot(of: user) }
        }
    }

    // MARK: Email

    func continueWithEmail(email: String, password: String, createAccount: Bool) async throws {
        let auth = try requireAuth()
        if createAccount {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await linkOrSignIn(credential, auth: auth)
        } else {
            try await auth.signIn(withEmail: email, password: password)
        }
        refresh()
    }

    func sendPasswordReset(email: String) async throws {
        try await requireAuth().sendPasswordReset(withEmail: email)
    }

    // MARK: Google

    func continueWithGoogle() async throws {
        let auth = try requireAuth()
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthServiceError.firebaseUnavailable
        }
        guard let presenter = Self.topViewController() else {
            throw AuthServiceError.missingPresenter
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch let error as NSError where error.code == GIDSignInError.canceled.rawValue {
            throw AuthServiceError.cancelled
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthServiceError.missingToken
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await linkOrSignIn(credential, auth: auth)
        refresh()
    }

    func handleOpenURL(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: Apple

    /// Call from `SignInWithAppleButton`'s request closure.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Call from `SignInWithAppleButton`'s completion closure.
    func completeApple(_ result: Result<ASAuthorization, Error>) async throws {
        let auth = try requireAuth()
        let authorization: ASAuthorization
        switch result {
        case .success(let value):
            authorization = value
        case .failure(let error as ASAuthorizationError) where error.code == .canceled:
            throw AuthServiceError.cancelled
        case .failure(let error):
            throw error
        }

        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let tokenData = appleCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthServiceError.missingToken
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )
        currentNonce = nil
        try await linkOrSignIn(credential, auth: auth)
        refresh()
    }

    // MARK: Session

    /// Signs out of the permanent account and returns to a fresh anonymous session.
    func signOut() async throws {
        let auth = try requireAuth()
        GIDSignIn.sharedInstance.signOut()
        try auth.signOut()
        try await auth.signInAnonymously()
        refresh()
    }

    // MARK: Internals

    private func linkOrSignIn(_ credential: AuthCredential, auth: Auth) async throws {
        guard let user = auth.currentUser, user.isAnonymous else {
            try await auth.signIn(with: credential)
            return
        }

        do {
            try await user.link(with: credential)
        } catch let error as NSError where Self.isAlreadyLinkedElsewhere(error) {
            // The identity already owns an account (e.g. created on another device).
            // Switch to it; the anonymous session's cloud data is not merged.
            let existing = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential ?? credential
            try await auth.signIn(with: existing)
        }
    }

    private static func isAlreadyLinkedElsewhere(_ error: NSError) -> Bool {
        guard let code = AuthErrorCode(rawValue: error.code) else { return false }
        return code == .credentialAlreadyInUse || code == .emailAlreadyInUse
    }

    private func requireAuth() throws -> Auth {
        guard FirebaseApp.app() != nil else { throw AuthServiceError.firebaseUnavailable }
        return Auth.auth()
    }

    private func refresh() {
        guard FirebaseApp.app() != nil else { return }
        account = Self.snapshot(of: Auth.auth().currentUser)
    }

    private static func snapshot(of user: User?) -> AccountSnapshot {
        guard let user else { return AccountSnapshot() }
        return AccountSnapshot(
            isSignedIn: true,
            isAnonymous: user.isAnonymous,
            email: user.email,
            providers: user.providerData.compactMap { AccountProvider(rawValue: $0.providerID) }
        )
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
