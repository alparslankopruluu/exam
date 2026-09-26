package com.kprl.exam.platform.analytics

import android.content.Context
import android.os.Bundle
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.crashlytics.FirebaseCrashlytics

interface AppAnalytics {
    fun event(name: String, params: Map<String, Any?> = emptyMap())
    fun userProperty(name: String, value: String?)
    fun nonFatal(error: Throwable, context: Map<String, String> = emptyMap())
}

private object NoOpAnalytics : AppAnalytics {
    override fun event(name: String, params: Map<String, Any?>) = Unit
    override fun userProperty(name: String, value: String?) = Unit
    override fun nonFatal(error: Throwable, context: Map<String, String>) = Unit
}

class FirebaseAppAnalytics private constructor(
    private val analytics: FirebaseAnalytics,
    private val crashlytics: FirebaseCrashlytics
) : AppAnalytics {
    override fun event(name: String, params: Map<String, Any?>) {
        val bundle = Bundle()
        params.forEach { (key, value) ->
            when (value) {
                is String -> bundle.putString(key, value)
                is Int -> bundle.putLong(key, value.toLong())
                is Long -> bundle.putLong(key, value)
                is Float -> bundle.putDouble(key, value.toDouble())
                is Double -> bundle.putDouble(key, value)
                is Boolean -> bundle.putLong(key, if (value) 1 else 0)
            }
        }
        analytics.logEvent(name, bundle)
    }

    override fun userProperty(name: String, value: String?) {
        analytics.setUserProperty(name, value)
    }

    override fun nonFatal(error: Throwable, context: Map<String, String>) {
        context.forEach { (key, value) -> crashlytics.setCustomKey(key, value) }
        crashlytics.recordException(error)
    }

    companion object {
        fun create(context: Context, firebaseReady: Boolean): AppAnalytics {
            if (!firebaseReady) return NoOpAnalytics
            return runCatching {
                FirebaseAppAnalytics(
                    FirebaseAnalytics.getInstance(context),
                    FirebaseCrashlytics.getInstance()
                )
            }.getOrElse { NoOpAnalytics }
        }
    }
}
