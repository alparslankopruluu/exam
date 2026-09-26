import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

struct EntitlementSnapshot: Hashable {
    let premium: Bool
    let credits: Int

    static let empty = EntitlementSnapshot(premium: false, credits: 0)
}

@MainActor
final class EntitlementService {
    func fetch() async -> EntitlementSnapshot {
        guard FirebaseApp.app() != nil,
              let uid = Auth.auth().currentUser?.uid else {
            return .empty
        }

        do {
            async let entitlementTask = Firestore.firestore()
                .document("users/\(uid)/entitlements/premium")
                .getDocument()

            async let userTask = Firestore.firestore()
                .document("users/\(uid)")
                .getDocument()

            let (entitlement, user) = try await (entitlementTask, userTask)
            let data = entitlement.data() ?? [:]
            let active = data["active"] as? Bool == true
            let expires = (data["expiresAt"] as? Timestamp)?.dateValue()
            let premium = active && (expires == nil || expires! > Date())

            return EntitlementSnapshot(
                premium: premium,
                credits: user.data()?["credits"] as? Int ?? 0
            )
        } catch {
            return .empty
        }
    }
}
