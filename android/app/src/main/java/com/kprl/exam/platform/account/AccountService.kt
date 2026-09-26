package com.kprl.exam.platform.account

import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.functions.FirebaseFunctions

class AccountService {
    fun deleteAccount(onResult: (Result<Unit>) -> Unit) {
        if (runCatching { FirebaseApp.getInstance() }.isFailure) {
            onResult(Result.failure(IllegalStateException("Firebase is not configured.")))
            return
        }

        FirebaseFunctions.getInstance()
            .getHttpsCallable("deleteAccount")
            .call()
            .addOnSuccessListener {
                FirebaseAuth.getInstance().signOut()
                onResult(Result.success(Unit))
            }
            .addOnFailureListener { error ->
                onResult(Result.failure(error))
            }
    }
}
