import Foundation
import FirebaseCore
import FirebaseAuth
@preconcurrency import FirebaseFunctions

@MainActor
final class AccountService {
    func deleteAccount() async throws {
        guard FirebaseApp.app() != nil else {
            throw AIGatewayError.firebaseUnavailable
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Functions.functions().httpsCallable("deleteAccount").call { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    do {
                        try Auth.auth().signOut()
                        continuation.resume(returning: ())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}
