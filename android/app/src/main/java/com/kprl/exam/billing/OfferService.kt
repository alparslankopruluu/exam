package com.kprl.exam.billing

import com.google.firebase.FirebaseApp
import com.google.firebase.functions.FirebaseFunctions

object OfferService {
    fun fetch(daysToExam: Int? = null, onResult: (ActiveOffer?) -> Unit) {
        if (runCatching { FirebaseApp.getInstance() }.isFailure) {
            onResult(null)
            return
        }

        val payload = buildMap<String, Any> {
            put("platform", "google")
            daysToExam?.let { put("daysToExam", it) }
        }

        FirebaseFunctions.getInstance()
            .getHttpsCallable("getActiveOffer")
            .call(payload)
            .addOnSuccessListener { result ->
                val offer = (result.data as? Map<*, *>)?.get("offer") as? Map<*, *>
                onResult(offer?.let(::parse)?.takeUnless { it.isExpired })
            }
            .addOnFailureListener { onResult(null) }
    }

    private fun parse(raw: Map<*, *>): ActiveOffer? {
        val kind = raw["kind"] as? String ?: return null
        val discount = (raw["discountPercent"] as? Number)?.toInt() ?: return null
        val expiresAt = (raw["expiresAt"] as? Number)?.toLong() ?: return null
        val productId = raw["productId"] as? String ?: return null
        return ActiveOffer(kind, discount, expiresAt, productId, raw["googleOfferTag"] as? String)
    }
}
