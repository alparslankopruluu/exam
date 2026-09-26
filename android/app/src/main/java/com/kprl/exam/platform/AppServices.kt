package com.kprl.exam.platform

import android.content.Context
import com.kprl.exam.platform.analytics.AppAnalytics
import com.kprl.exam.platform.analytics.FirebaseAppAnalytics
import com.kprl.exam.platform.firebase.FirebaseBootstrap
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
        FirebaseBootstrap.ensureAnonymousSession(firebaseReady)
    }
}
