package com.kprl.exam.debug

import android.content.Context
import android.content.Intent

/** Release builds never seed screenshot state. */
object ScreenshotMode {
    val screen: String? = null

    @Suppress("UNUSED_PARAMETER")
    fun prepare(context: Context, intent: Intent?) = Unit
}
