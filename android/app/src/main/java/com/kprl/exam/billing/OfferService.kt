package com.kprl.exam.billing

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.functions.FirebaseFunctionsException
import java.time.LocalDate

/** Server-issued bonus on credit packs (+bonusPercent credits) until expiresAtMillis. */
data class CreditBoost(val bonusPercent: Int, val expiresAtMillis: Long)

/** Prize drawn by the server for today's gift wheel spin. */
data class WheelResult(val prize: String, val segment: Int, val credits: Int, val offerExpiresAtMillis: Long?)

object OfferService {
    /** The credit bonus returned by the last `fetch`, if still running. */
    @Volatile
    var creditBoost: CreditBoost? = null
        private set

    /** Today in the device's calendar, the key for "one spin per day". */
    val localDay: String get() = LocalDate.now().toString()

    private fun prefs(context: Context) = context.getSharedPreferences("gift_wheel", Context.MODE_PRIVATE)

    fun spunToday(context: Context): Boolean = prefs(context).getString("lastSpinDay", null) == localDay

    fun markSpun(context: Context) = prefs(context).edit().putString("lastSpinDay", localDay).apply()

    fun isAlreadySpun(error: Throwable): Boolean =
        (error as? FirebaseFunctionsException)?.code == FirebaseFunctionsException.Code.ALREADY_EXISTS

    /** Spins the gift wheel; the server draws and grants the prize. */
    fun spinWheel(context: Context, onResult: (Result<WheelResult>) -> Unit) {
        FirebaseFunctions.getInstance()
            .getHttpsCallable("spinGiftWheel")
            .call(mapOf("localDay" to localDay))
            .addOnSuccessListener { result ->
                markSpun(context)
                val data = result.data as? Map<*, *>
                val prize = data?.get("prize") as? String
                val segment = (data?.get("segment") as? Number)?.toInt()
                if (prize == null || segment == null) {
                    onResult(Result.failure(IllegalStateException("Unexpected wheel response.")))
                } else {
                    onResult(Result.success(WheelResult(
                        prize, segment,
                        (data["credits"] as? Number)?.toInt() ?: 0,
                        (data["offerExpiresAt"] as? Number)?.toLong()
                    )))
                }
            }
            .addOnFailureListener { error ->
                if (isAlreadySpun(error)) markSpun(context)
                onResult(Result.failure(error))
            }
    }

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
                val data = result.data as? Map<*, *>
                creditBoost = (data?.get("creditBoost") as? Map<*, *>)?.let { boost ->
                    val percent = (boost["bonusPercent"] as? Number)?.toInt()
                    val expires = (boost["expiresAt"] as? Number)?.toLong()
                    if (percent != null && expires != null) CreditBoost(percent, expires) else null
                }
                val offer = data?.get("offer") as? Map<*, *>
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
