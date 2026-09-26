import Foundation
import StoreKit

@MainActor
final class StoreKitBillingService {
    static let shared = StoreKitBillingService()

    enum ProductId {
        static let annual = "premium_annual"
        static let monthly = "premium_monthly"
        static let creditsSmall = "ai_credits_small"
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
            let loaded = try await Product.products(for: [
                ProductId.annual,
                ProductId.monthly,
                ProductId.creditsSmall
            ])
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

    func loadCreditPrice() async -> String? {
        if products[ProductId.creditsSmall] == nil {
            _ = await loadOffer()
        }
        return products[ProductId.creditsSmall]?.displayPrice
    }

    func purchase(productId: String) async -> Bool {
        if products[productId] == nil {
            _ = await loadOffer()
        }

        guard let product = products[productId] else { return false }

        do {
            let result = try await product.purchase()

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
                trialText: nil,
                recommended: recommended
            )
        }

        let hasTrial = product.subscription?.introductoryOffer?.paymentMode == .freeTrial

        return StorePlanPresentation(
            productId: product.id,
            title: title,
            localizedPrice: product.displayPrice,
            trialText: hasTrial ? "Free trial available" : nil,
            recommended: recommended
        )
    }
}
