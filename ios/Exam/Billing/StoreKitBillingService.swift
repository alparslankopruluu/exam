import Foundation
import StoreKit

@MainActor
final class StoreKitBillingService {
    static let shared = StoreKitBillingService()

    enum ProductId {
        static let annual = "premium_annual"
        static let monthly = "premium_monthly"
        static let annualOffer = "premium_annual_offer"
        static let creditsSmall = "ai_credits_small"
        static let creditsMedium = "ai_credits_medium"
        static let creditsLarge = "ai_credits_large"

        static let creditPacks = [creditsSmall, creditsMedium, creditsLarge]
        static let all = [annual, monthly, annualOffer] + creditPacks
    }

    private var products: [String: Product] = [:]
    private var transactionTask: Task<Void, Never>?

    private init() {
        transactionTask = observeTransactions()
    }

    deinit {
        transactionTask?.cancel()
    }

    func loadOffer() async -> StoreOfferPresentation {
        do {
            let loaded = try await Product.products(for: ProductId.all)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })

            return StoreOfferPresentation(
                annual: plan(
                    product: products[ProductId.annual],
                    title: "Annual",
                    recommended: true
                ),
                monthly: plan(
                    product: products[ProductId.monthly],
                    title: "Monthly",
                    recommended: false
                )
            )
        } catch {
            return .placeholder
        }
    }

    func loadCreditPacks() async -> [CreditPackPresentation] {
        if products[ProductId.creditsSmall] == nil {
            _ = await loadOffer()
        }
        return ProductId.creditPacks.compactMap { id in
            guard let product = products[id] else { return nil }
            return CreditPackPresentation(productId: id, localizedPrice: product.displayPrice)
        }
    }

    /// Resolves store prices for a server-issued offer. Returns nil when the
    /// store does not have the matching product or promotional offer, so the
    /// paywall never advertises a discount it cannot charge.
    func present(_ offer: ActiveOffer) async -> OfferPresentation? {
        if products[offer.productId] == nil {
            _ = await loadOffer()
        }
        guard let product = products[offer.productId],
              let regular = products[ProductId.annual] else { return nil }

        if let promo = offer.applePromotionalOffer {
            guard let storeOffer = product.subscription?.promotionalOffers.first(where: { $0.id == promo.offerId }) else {
                return nil
            }
            return OfferPresentation(offer: offer, localizedPrice: storeOffer.displayPrice, regularPrice: regular.displayPrice)
        }
        return OfferPresentation(offer: offer, localizedPrice: product.displayPrice, regularPrice: regular.displayPrice)
    }

    func purchase(productId: String, offer: ActiveOffer? = nil) async -> Bool {
        if products[productId] == nil {
            _ = await loadOffer()
        }

        guard let product = products[productId] else { return false }

        var options: Set<Product.PurchaseOption> = []
        if let promo = offer?.applePromotionalOffer, offer?.productId == productId,
           let signature = Data(base64Encoded: promo.signature),
           let nonce = UUID(uuidString: promo.nonce) {
            options.insert(.promotionalOffer(
                offerID: promo.offerId,
                keyID: promo.keyId,
                nonce: nonce,
                signature: signature,
                timestamp: promo.timestamp
            ))
        }

        do {
            let result = try await product.purchase(options: options)

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return false
                }

                let verified = await PurchaseBackendVerifier.shared.verifyApple(
                    transactionId: String(transaction.id),
                    productId: transaction.productID
                )

                if verified {
                    await transaction.finish()
                }
                return verified

            case .pending, .userCancelled:
                return false

            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            let verified = await PurchaseBackendVerifier.shared.verifyApple(
                transactionId: String(transaction.id),
                productId: transaction.productID
            )

            if verified {
                await transaction.finish()
            }
        }
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result else { continue }

                let verified = await PurchaseBackendVerifier.shared.verifyApple(
                    transactionId: String(transaction.id),
                    productId: transaction.productID
                )

                if verified {
                    await transaction.finish()
                }

                _ = self
            }
        }
    }

    private func plan(
        product: Product?,
        title: String,
        recommended: Bool
    ) -> StorePlanPresentation {
        guard let product else {
            return StorePlanPresentation(
                productId: recommended ? ProductId.annual : ProductId.monthly,
                title: title,
                localizedPrice: nil,
                hasTrial: false,
                recommended: recommended
            )
        }

        let hasTrial = product.subscription?.introductoryOffer?.paymentMode == .freeTrial

        return StorePlanPresentation(
            productId: product.id,
            title: title,
            localizedPrice: product.displayPrice,
            hasTrial: hasTrial,
            recommended: recommended
        )
    }
}
