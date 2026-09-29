import Foundation
import FirebaseCore
@preconcurrency import FirebaseFunctions

struct ApplePromotionalOffer: Hashable {
    let offerId: String
    let keyId: String
    let nonce: String
    let timestamp: Int
    let signature: String
}

/// Server-issued offer. The expiry is fixed server-side, so a countdown is real.
struct ActiveOffer: Hashable {
    let kind: String
    let discountPercent: Int
    let expiresAt: Date
    let productId: String
    let applePromotionalOffer: ApplePromotionalOffer?

    var isExpired: Bool { expiresAt <= Date() }
}

@MainActor
final class OfferService {
    static let shared = OfferService()

    private init() {}

    func fetch(daysToExam: Int? = nil) async -> ActiveOffer? {
        guard FirebaseApp.app() != nil else { return nil }

        var payload: [String: Any] = ["platform": "apple"]
        if let daysToExam { payload["daysToExam"] = daysToExam }

        do {
            let result = try await Functions.functions().httpsCallable("getActiveOffer").call(payload)
            guard let data = result.data as? [String: Any],
                  let offer = data["offer"] as? [String: Any] else { return nil }
            return Self.parse(offer)
        } catch {
            return nil
        }
    }

    private static func parse(_ raw: [String: Any]) -> ActiveOffer? {
        guard let kind = raw["kind"] as? String,
              let discount = (raw["discountPercent"] as? NSNumber)?.intValue,
              let expiresMs = (raw["expiresAt"] as? NSNumber)?.doubleValue,
              let productId = raw["productId"] as? String else { return nil }

        var promo: ApplePromotionalOffer?
        if let p = raw["applePromotionalOffer"] as? [String: Any] {
            guard let offerId = p["offerId"] as? String,
                  let keyId = p["keyId"] as? String,
                  let nonce = p["nonce"] as? String,
                  let timestamp = (p["timestamp"] as? NSNumber)?.intValue,
                  let signature = p["signature"] as? String else { return nil }
            promo = ApplePromotionalOffer(offerId: offerId, keyId: keyId, nonce: nonce, timestamp: timestamp, signature: signature)
        }

        let offer = ActiveOffer(
            kind: kind,
            discountPercent: discount,
            expiresAt: Date(timeIntervalSince1970: expiresMs / 1000),
            productId: productId,
            applePromotionalOffer: promo
        )
        return offer.isExpired ? nil : offer
    }
}
