import Foundation
import FirebaseCore
import FirebaseFunctions

@MainActor
final class PurchaseBackendVerifier {
    static let shared = PurchaseBackendVerifier()

    private init() {}

    func verifyApple(transactionId: String, productId: String) async -> Bool {
        guard FirebaseApp.app() != nil else { return false }

        do {
            let result = try await Functions.functions()
                .httpsCallable("verifyStorePurchase")
                .call([
                    "platform": "apple",
                    "transactionId": transactionId,
                    "productId": productId
                ])

            let data = result.data as? [String: Any]
            return data?["verified"] as? Bool == true
        } catch {
            return false
        }
    }
}
