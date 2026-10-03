import Foundation

struct StorePlanPresentation: Hashable {
    let productId: String
    let title: String
    let localizedPrice: String?
    /// Length of the free trial in days, when the account is eligible for one.
    let trialDays: Int?
    let recommended: Bool

    var hasTrial: Bool { trialDays != nil }
}

struct StoreOfferPresentation: Hashable {
    let annual: StorePlanPresentation
    let monthly: StorePlanPresentation

    static let placeholder = StoreOfferPresentation(
        annual: StorePlanPresentation(
            productId: "premium_annual",
            title: "Annual",
            localizedPrice: nil,
            trialDays: nil,
            recommended: true
        ),
        monthly: StorePlanPresentation(
            productId: "premium_monthly",
            title: "Monthly",
            localizedPrice: nil,
            trialDays: nil,
            recommended: false
        )
    )
}

struct CreditPackPresentation: Hashable, Identifiable {
    let productId: String
    let localizedPrice: String

    var id: String { productId }
}

/// A server-issued offer with store-resolved prices, ready for the paywall.
struct OfferPresentation: Hashable {
    let offer: ActiveOffer
    let localizedPrice: String
    let regularPrice: String
}

/// Hosted legal pages (store/legal/build.py), linked from the paywall as App Review requires.
enum LegalLinks {
    static let terms = URL(string: "https://examly-study.web.app/terms")!
    static let privacy = URL(string: "https://examly-study.web.app/privacy")!
}
