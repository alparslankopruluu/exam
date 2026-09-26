import Foundation

struct StorePlanPresentation: Hashable {
    let productId: String
    let title: String
    let localizedPrice: String?
    let trialText: String?
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
            trialText: nil,
            recommended: true
        ),
        monthly: StorePlanPresentation(
            productId: "premium_monthly",
            title: "Monthly",
            localizedPrice: nil,
            trialText: nil,
            recommended: false
        )
    )
}
