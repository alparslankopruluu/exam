package com.kprl.exam.billing

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.*

class GooglePlayBillingService(
    private val context: Context,
    private val verifier: PurchaseBackendVerifier = PurchaseBackendVerifier()
) : PurchasesUpdatedListener {

    object ProductIds {
        const val PREMIUM_ANNUAL = "premium_annual"
        const val PREMIUM_MONTHLY = "premium_monthly"
        const val AI_CREDITS_SMALL = "ai_credits_small"
        const val AI_CREDITS_MEDIUM = "ai_credits_medium"
        const val AI_CREDITS_LARGE = "ai_credits_large"

        val CREDIT_PACKS = listOf(AI_CREDITS_SMALL, AI_CREDITS_MEDIUM, AI_CREDITS_LARGE)
        val SUBSCRIPTIONS = setOf(PREMIUM_ANNUAL, PREMIUM_MONTHLY)

        /** Offer tag for the store-configured free trial on the annual base plan. */
        const val TRIAL_OFFER_TAG = "trial"
    }

    private val productDetails = mutableMapOf<String, ProductDetails>()

    private val billingClient = BillingClient.newBuilder(context)
        .setListener(this)
        .enablePendingPurchases(
            PendingPurchasesParams.newBuilder()
                .enableOneTimeProducts()
                .build()
        )
        .build()

    private var purchaseResultListener: ((Boolean, String?) -> Unit)? = null

    /** [onError] fires when Play Billing is unavailable or the connection drops. */
    fun start(onError: (() -> Unit)? = null, onReady: (() -> Unit)? = null) {
        if (billingClient.isReady) {
            onReady?.invoke()
            return
        }

        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    restorePurchases()
                    onReady?.invoke()
                } else {
                    onError?.invoke()
                }
            }

            override fun onBillingServiceDisconnected() {
                onError?.invoke()
            }
        })
    }

    fun close() {
        billingClient.endConnection()
    }

    fun loadOffer(onLoaded: (StoreOfferPresentation) -> Unit) {
        queryProducts(
            BillingClient.ProductType.SUBS,
            listOf(ProductIds.PREMIUM_ANNUAL, ProductIds.PREMIUM_MONTHLY)
        ) { subscriptions ->
            subscriptions.forEach { productDetails[it.productId] = it }

            val annual = subscriptions.firstOrNull { it.productId == ProductIds.PREMIUM_ANNUAL }
            val monthly = subscriptions.firstOrNull { it.productId == ProductIds.PREMIUM_MONTHLY }

            onLoaded(
                StoreOfferPresentation(
                    annual = annual.toPlanPresentation("Annual", recommended = true),
                    monthly = monthly.toPlanPresentation("Monthly", recommended = false)
                )
            )
        }

    }

    fun loadCreditPacks(onLoaded: (List<CreditPackPresentation>) -> Unit) {
        queryProducts(BillingClient.ProductType.INAPP, ProductIds.CREDIT_PACKS) { products ->
            products.forEach { productDetails[it.productId] = it }
            onLoaded(
                ProductIds.CREDIT_PACKS.mapNotNull { id ->
                    val price = productDetails[id]?.oneTimePurchaseOfferDetailsList?.firstOrNull()?.formattedPrice
                    price?.let { CreditPackPresentation(id, it) }
                }
            )
        }
    }

    /**
     * Resolves store prices for a server-issued offer. Returns null when Play
     * does not return the tagged offer (not configured, or user not eligible),
     * so the paywall never advertises a discount it cannot charge.
     */
    fun present(offer: ActiveOffer): OfferPresentation? {
        val details = productDetails[offer.productId] ?: return null
        val tag = offer.googleOfferTag ?: return null
        val tagged = details.subscriptionOfferDetails?.firstOrNull { tag in it.offerTags } ?: return null
        val offerPrice = tagged.pricingPhases.pricingPhaseList.firstOrNull { it.priceAmountMicros > 0 } ?: return null
        val basePrice = details.basePlanOffer()?.pricingPhases?.pricingPhaseList?.lastOrNull()?.formattedPrice ?: return null
        return OfferPresentation(offer, offerPrice.formattedPrice, basePrice)
    }

    fun purchase(
        activity: Activity,
        productId: String,
        offerTag: String? = null,
        onResult: (Boolean, String?) -> Unit = { _, _ -> }
    ) {
        val details = productDetails[productId] ?: run {
            onResult(false, "Product not loaded")
            return
        }

        val paramsBuilder = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(details)

        // Pick the offer deliberately: the server-issued tag, else the trial (Play
        // only lists offers the user is eligible for), else the plain base plan.
        // Never "first offer", which could expose unrelated discounts.
        val offerToken = details.subscriptionOfferDetails?.let { offers ->
            offerTag?.let { tag -> offers.firstOrNull { tag in it.offerTags } }
                ?: offers.firstOrNull { ProductIds.TRIAL_OFFER_TAG in it.offerTags }
                ?: details.basePlanOffer()
        }?.offerToken
            ?: details.oneTimePurchaseOfferDetailsList
                ?.firstOrNull()
                ?.offerToken

        if (!offerToken.isNullOrBlank()) {
            paramsBuilder.setOfferToken(offerToken)
        }

        purchaseResultListener = onResult

        val result = billingClient.launchBillingFlow(
            activity,
            BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(listOf(paramsBuilder.build()))
                .build()
        )

        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            purchaseResultListener?.invoke(false, result.debugMessage)
            purchaseResultListener = null
        }
    }

    fun restorePurchases() {
        if (!billingClient.isReady) return

        listOf(
            BillingClient.ProductType.SUBS,
            BillingClient.ProductType.INAPP
        ).forEach { type ->
            billingClient.queryPurchasesAsync(
                QueryPurchasesParams.newBuilder()
                    .setProductType(type)
                    .build()
            ) { result, purchases ->
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    purchases.forEach { processPurchase(it, type) }
                }
            }
        }
    }

    override fun onPurchasesUpdated(
        billingResult: BillingResult,
        purchases: MutableList<Purchase>?
    ) {
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                purchases.orEmpty().forEach { purchase ->
                    val type = if (purchase.products.any { it in ProductIds.SUBSCRIPTIONS }) {
                        BillingClient.ProductType.SUBS
                    } else {
                        BillingClient.ProductType.INAPP
                    }
                    processPurchase(purchase, type)
                }
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                purchaseResultListener?.invoke(false, "cancelled")
                purchaseResultListener = null
            }
            else -> {
                purchaseResultListener?.invoke(false, billingResult.debugMessage)
                purchaseResultListener = null
            }
        }
    }

    private fun processPurchase(purchase: Purchase, productType: String) {
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return

        val productId = purchase.products.firstOrNull() ?: return

        verifier.verifyGoogle(
            purchaseToken = purchase.purchaseToken,
            productId = productId,
            packageName = context.packageName,
            productType = productType
        ) { verified ->
            if (!verified) {
                purchaseResultListener?.invoke(false, "verification_failed")
                purchaseResultListener = null
                return@verifyGoogle
            }

            if (productId in ProductIds.CREDIT_PACKS) {
                billingClient.consumeAsync(
                    ConsumeParams.newBuilder()
                        .setPurchaseToken(purchase.purchaseToken)
                        .build()
                ) { result, _ ->
                    purchaseResultListener?.invoke(
                        result.responseCode == BillingClient.BillingResponseCode.OK,
                        result.debugMessage
                    )
                    purchaseResultListener = null
                }
            } else if (!purchase.isAcknowledged) {
                billingClient.acknowledgePurchase(
                    AcknowledgePurchaseParams.newBuilder()
                        .setPurchaseToken(purchase.purchaseToken)
                        .build()
                ) { result ->
                    purchaseResultListener?.invoke(
                        result.responseCode == BillingClient.BillingResponseCode.OK,
                        result.debugMessage
                    )
                    purchaseResultListener = null
                }
            } else {
                purchaseResultListener?.invoke(true, null)
                purchaseResultListener = null
            }
        }
    }

    private fun queryProducts(
        productType: String,
        ids: List<String>,
        onResult: (List<ProductDetails>) -> Unit
    ) {
        if (!billingClient.isReady) {
            onResult(emptyList())
            return
        }

        val products = ids.map { id ->
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(id)
                .setProductType(productType)
                .build()
        }

        billingClient.queryProductDetailsAsync(
            QueryProductDetailsParams.newBuilder()
                .setProductList(products)
                .build()
        ) { result, queryResult ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                onResult(queryResult.productDetailsList)
            } else {
                onResult(emptyList())
            }
        }
    }

    private fun ProductDetails?.toPlanPresentation(
        title: String,
        recommended: Boolean
    ): StorePlanPresentation {
        if (this == null) {
            return StorePlanPresentation(
                productId = if (recommended) ProductIds.PREMIUM_ANNUAL else ProductIds.PREMIUM_MONTHLY,
                title = title,
                localizedPrice = null,
                hasTrial = false,
                recommended = recommended
            )
        }

        val trial = subscriptionOfferDetails?.firstOrNull { ProductIds.TRIAL_OFFER_TAG in it.offerTags }
        val hasTrial = trial?.pricingPhases?.pricingPhaseList.orEmpty().any { it.priceAmountMicros == 0L }
        val basePrice = basePlanOffer()?.pricingPhases?.pricingPhaseList?.lastOrNull()?.formattedPrice

        return StorePlanPresentation(
            productId = productId,
            title = title,
            localizedPrice = basePrice,
            hasTrial = hasTrial,
            recommended = recommended
        )
    }

    /** The base plan itself is the offer entry without an offerId. */
    private fun ProductDetails.basePlanOffer(): ProductDetails.SubscriptionOfferDetails? =
        subscriptionOfferDetails?.firstOrNull { it.offerId == null }
}
