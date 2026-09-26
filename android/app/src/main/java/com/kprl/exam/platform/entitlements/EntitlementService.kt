package com.kprl.exam.platform.entitlements

import com.google.firebase.FirebaseApp
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore

data class EntitlementSnapshot(
    val premium: Boolean = false,
    val credits: Int = 0
)

class EntitlementService {
    fun fetch(onResult: (EntitlementSnapshot) -> Unit) {
        if (runCatching { FirebaseApp.getInstance() }.isFailure) {
            onResult(EntitlementSnapshot())
            return
        }

        val uid = FirebaseAuth.getInstance().currentUser?.uid
        if (uid == null) {
            onResult(EntitlementSnapshot())
            return
        }

        val db = FirebaseFirestore.getInstance()

        db.document("users/$uid/entitlements/premium").get()
            .addOnSuccessListener { entitlement ->
                val active = entitlement.getBoolean("active") == true
                val expiresAt = entitlement.getTimestamp("expiresAt")
                val premium = active && (
                    expiresAt == null ||
                    expiresAt.toDate().time > System.currentTimeMillis()
                )

                db.document("users/$uid").get()
                    .addOnSuccessListener { user ->
                        onResult(
                            EntitlementSnapshot(
                                premium = premium,
                                credits = (user.getLong("credits") ?: 0L).toInt()
                            )
                        )
                    }
                    .addOnFailureListener {
                        onResult(EntitlementSnapshot(premium = premium))
                    }
            }
            .addOnFailureListener {
                onResult(EntitlementSnapshot())
            }
    }
}
