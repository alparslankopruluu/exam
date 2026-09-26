package com.kprl.exam.billing

data class StorePlanPresentation(
    val productId: String,
    val title: String,
    val localizedPrice: String?,
    val trialText: String?,
    val recommended: Boolean
)

data class StoreOfferPresentation(
    val annual: StorePlanPresentation = StorePlanPresentation(
        productId = "premium_annual",
        title = "Annual",
        localizedPrice = null,
        trialText = null,
        recommended = true
    ),
    val monthly: StorePlanPresentation = StorePlanPresentation(
        productId = "premium_monthly",
        title = "Monthly",
        localizedPrice = null,
        trialText = null,
        recommended = false
    )
)
