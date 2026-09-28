import Foundation

struct StorePlanPresentation: Hashable {
    let productId: String
    let title: String
    let localizedPrice: String?
    let hasTrial: Bool
    let recommended: Bool
}

struct StoreOfferPresentation: Hashable {
    let annual: StorePlanPresentation
    let monthly: StorePlanPresentation

    static let placeholder = StoreOfferPresentation(
        annual: StorePlanPresentation(
            productId: "premium_annual",
            title: "Annual",
            localizedPrice: nil,
            hasTrial: false,
            recommended: true
        ),
        monthly: StorePlanPresentation(
            productId: "premium_monthly",
            title: "Monthly",
            localizedPrice: nil,
            hasTrial: false,
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
