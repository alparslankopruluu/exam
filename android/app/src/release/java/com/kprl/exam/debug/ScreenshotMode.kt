package com.kprl.exam.debug

import android.content.Context
import android.content.Intent

/** Release builds never seed screenshot state. */
object ScreenshotMode {
    val screen: String? = null
    val examId: String? = null
    val language: String? = null

    @Suppress("UNUSED_PARAMETER")
    fun prepare(context: Context, intent: Intent?) = Unit
}
