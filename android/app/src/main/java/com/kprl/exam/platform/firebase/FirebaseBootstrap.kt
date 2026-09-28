package com.kprl.exam.platform.firebase

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.crashlytics.FirebaseCrashlytics

object FirebaseBootstrap {
    /** False when the build has no google-services.json (local/dev builds). */
    fun isConfigured(): Boolean = runCatching { FirebaseApp.getInstance() }.isSuccess

    fun initialize(context: Context): Boolean {
        return try {
            val app = FirebaseApp.initializeApp(context)
            val ready = app != null || FirebaseApp.getApps(context).isNotEmpty()
            if (ready) {
                FirebaseCrashlytics.getInstance().isCrashlyticsCollectionEnabled = true
            }
            ready
        } catch (_: Throwable) {
            false
        }
    }

    fun ensureAnonymousSession(firebaseReady: Boolean, onReady: (() -> Unit)? = null) {
        if (!firebaseReady) return
        runCatching {
            val auth = FirebaseAuth.getInstance()
            if (auth.currentUser == null) {
                auth.signInAnonymously()
                    .addOnCompleteListener { if (it.isSuccessful) onReady?.invoke() }
            } else {
                onReady?.invoke()
            }
        }
    }
}
