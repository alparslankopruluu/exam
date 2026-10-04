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

/// Server-issued bonus on credit packs (+bonusPercent credits) until expiresAt.
struct CreditBoost: Hashable {
    let bonusPercent: Int
    let expiresAt: Date
}

/// Prize drawn by the server for today's gift wheel spin.
struct WheelResult: Hashable {
    let prize: String
    let segment: Int
    let credits: Int
    let offerExpiresAt: Date?
}

@MainActor
final class OfferService {
    static let shared = OfferService()

    /// The credit bonus returned by the last `fetch`, if still running.
    private(set) var creditBoost: CreditBoost?

    private init() {}

    /// Today in the device's calendar, the key for "one spin per day".
    static var localDay: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }

    static var spunToday: Bool {
        UserDefaults.standard.string(forKey: "wheel.lastSpinDay") == localDay
    }

    /// True when the server refused a spin because today's was already used.
    static func isAlreadySpun(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == FunctionsErrorDomain && ns.code == FunctionsErrorCode.alreadyExists.rawValue
    }

    /// Spins the gift wheel; the server draws and grants the prize.
    func spinWheel() async throws -> WheelResult {
        let result = try await Functions.functions().httpsCallable("spinGiftWheel").call(["localDay": Self.localDay])
        UserDefaults.standard.set(Self.localDay, forKey: "wheel.lastSpinDay")
        guard let data = result.data as? [String: Any],
              let prize = data["prize"] as? String,
              let segment = (data["segment"] as? NSNumber)?.intValue else {
            throw AIGatewayError.message("Unexpected wheel response.")
        }
        let expires = (data["offerExpiresAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        return WheelResult(prize: prize, segment: segment, credits: (data["credits"] as? NSNumber)?.intValue ?? 0, offerExpiresAt: expires)
    }

    func fetch(daysToExam: Int? = nil) async -> ActiveOffer? {
        guard FirebaseApp.app() != nil else { return nil }

        var payload: [String: Any] = ["platform": "apple"]
        if let daysToExam { payload["daysToExam"] = daysToExam }

        do {
            let result = try await Functions.functions().httpsCallable("getActiveOffer").call(payload)
            guard let data = result.data as? [String: Any] else { return nil }
            if let boost = data["creditBoost"] as? [String: Any],
               let percent = (boost["bonusPercent"] as? NSNumber)?.intValue,
               let expires = (boost["expiresAt"] as? NSNumber)?.doubleValue {
                creditBoost = CreditBoost(bonusPercent: percent, expiresAt: Date(timeIntervalSince1970: expires / 1000))
            } else {
                creditBoost = nil
            }
            guard let offer = data["offer"] as? [String: Any] else { return nil }
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
