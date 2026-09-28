package com.kprl.exam.platform

import android.content.Context
import com.kprl.exam.platform.analytics.AppAnalytics
import com.kprl.exam.platform.analytics.FirebaseAppAnalytics
import com.kprl.exam.platform.firebase.FirebaseBootstrap
import com.google.firebase.messaging.FirebaseMessaging
import com.kprl.exam.platform.notifications.PushTokenRegistrar
import com.kprl.exam.platform.remote.RemoteFeatureFlags

object AppServices {
    lateinit var analytics: AppAnalytics
        private set

    lateinit var flags: RemoteFeatureFlags
        private set

    fun initialize(context: Context) {
        val firebaseReady = FirebaseBootstrap.initialize(context)
        analytics = FirebaseAppAnalytics.create(context, firebaseReady)
        flags = RemoteFeatureFlags.create(firebaseReady)
        flags.refresh()
        com.kprl.exam.platform.account.AuthService.start()
        FirebaseBootstrap.ensureAnonymousSession(firebaseReady) {
            FirebaseMessaging.getInstance().token
                .addOnSuccessListener { token ->
                    PushTokenRegistrar.register(context, token)
                }
        }
    }
}
