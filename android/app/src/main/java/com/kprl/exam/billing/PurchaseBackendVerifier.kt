package com.kprl.exam.billing

import com.google.firebase.FirebaseApp
import com.google.firebase.functions.FirebaseFunctions

class PurchaseBackendVerifier {
    fun verifyGoogle(
        purchaseToken: String,
        productId: String,
        packageName: String,
        productType: String,
        onResult: (Boolean) -> Unit
    ) {
        if (runCatching { FirebaseApp.getInstance() }.isFailure) {
            onResult(false)
            return
        }

        FirebaseFunctions.getInstance()
            .getHttpsCallable("verifyStorePurchase")
            .call(
                mapOf(
                    "platform" to "google",
                    "purchaseToken" to purchaseToken,
                    "productId" to productId,
                    "packageName" to packageName,
                    "productType" to productType
                )
            )
            .addOnSuccessListener { result ->
                val data = result.data as? Map<*, *>
                onResult(data?.get("verified") == true)
            }
            .addOnFailureListener {
                onResult(false)
            }
    }
}
