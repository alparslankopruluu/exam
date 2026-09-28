package com.kprl.exam.platform.notifications

import android.content.Intent
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Carries a route from a tapped notification to the visible screen.
 * Routes: "today", "review", "paywall".
 */
object DeepLinkRouter {
    const val EXTRA_ROUTE = "route"

    private val _pending = MutableStateFlow<String?>(null)
    val pending: StateFlow<String?> = _pending.asStateFlow()

    /** Reads the route from both our own notifications and FCM system-tray taps. */
    fun handle(intent: Intent?) {
        intent?.getStringExtra(EXTRA_ROUTE)?.let { _pending.value = it }
    }

    fun consume(): String? = _pending.value.also { _pending.value = null }
}
