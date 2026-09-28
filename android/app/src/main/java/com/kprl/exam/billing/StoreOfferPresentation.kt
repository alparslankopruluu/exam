package com.kprl.exam.billing

data class StorePlanPresentation(
    val productId: String,
    val title: String,
    val localizedPrice: String?,
    val hasTrial: Boolean,
    val recommended: Boolean
)

data class StoreOfferPresentation(
    val annual: StorePlanPresentation = StorePlanPresentation(
        productId = "premium_annual",
        title = "Annual",
        localizedPrice = null,
        hasTrial = false,
        recommended = true
    ),
    val monthly: StorePlanPresentation = StorePlanPresentation(
        productId = "premium_monthly",
        title = "Monthly",
        localizedPrice = null,
        hasTrial = false,
        recommended = false
    )
)

data class CreditPackPresentation(
    val productId: String,
    val localizedPrice: String
)

/** Server-issued offer. The expiry is fixed server-side, so a countdown is real. */
data class ActiveOffer(
    val kind: String,
    val discountPercent: Int,
    val expiresAtMillis: Long,
    val productId: String,
    val googleOfferTag: String?
) {
    val isExpired: Boolean get() = expiresAtMillis <= System.currentTimeMillis()
}

/** A server-issued offer with store-resolved prices, ready for the paywall. */
data class OfferPresentation(
    val offer: ActiveOffer,
    val localizedPrice: String,
    val regularPrice: String
)
