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

    fun start(onReady: (() -> Unit)? = null) {
        if (billingClient.isReady) {
            onReady?.invoke()
            return
        }

        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    restorePurchases()
                    onReady?.invoke()
                }
            }

            override fun onBillingServiceDisconnected() = Unit
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

        queryProducts(
            BillingClient.ProductType.INAPP,
            listOf(ProductIds.AI_CREDITS_SMALL)
        ) { oneTime ->
            oneTime.forEach { productDetails[it.productId] = it }
        }
    }

    fun loadCreditPrice(onLoaded: (String?) -> Unit) {
        val cached = productDetails[ProductIds.AI_CREDITS_SMALL]
        if (cached != null) {
            onLoaded(cached.oneTimePurchaseOfferDetailsList?.firstOrNull()?.formattedPrice)
            return
        }

        queryProducts(
            BillingClient.ProductType.INAPP,
            listOf(ProductIds.AI_CREDITS_SMALL)
        ) { products ->
            products.forEach { productDetails[it.productId] = it }
            onLoaded(
                products.firstOrNull()
                    ?.oneTimePurchaseOfferDetailsList
                    ?.firstOrNull()
                    ?.formattedPrice
            )
        }
    }

    fun purchase(
        activity: Activity,
        productId: String,
        onResult: (Boolean, String?) -> Unit = { _, _ -> }
    ) {
        val details = productDetails[productId] ?: run {
            onResult(false, "Product not loaded")
            return
        }

        val paramsBuilder = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(details)

        val offerToken = details.subscriptionOfferDetails
            ?.firstOrNull()
            ?.offerToken
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
                    val type = if (purchase.products.any {
                            it == ProductIds.PREMIUM_ANNUAL || it == ProductIds.PREMIUM_MONTHLY
                        }) {
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

            if (productId == ProductIds.AI_CREDITS_SMALL) {
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
                trialText = null,
                recommended = recommended
            )
        }

        val offer = subscriptionOfferDetails?.firstOrNull()
        val phases = offer?.pricingPhases?.pricingPhaseList.orEmpty()
        val paidPhase = phases.lastOrNull { it.priceAmountMicros > 0 } ?: phases.lastOrNull()
        val freePhase = phases.firstOrNull { it.priceAmountMicros == 0L }

        return StorePlanPresentation(
            productId = productId,
            title = title,
            localizedPrice = paidPhase?.formattedPrice,
            trialText = freePhase?.let { "Free trial available" },
            recommended = recommended
        )
    }
}
