package com.kprl.exam.platform.notifications

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.functions.FirebaseFunctions
import java.util.Locale
import java.util.TimeZone

object PushTokenRegistrar {
    fun register(
        context: Context,
        token: String,
        examId: String? = null,
        examName: String? = null,
        localReminderHour: Int = 19
    ) {
        if (runCatching { FirebaseApp.getInstance() }.isFailure) return

        val now = System.currentTimeMillis()
        val offsetMinutes = TimeZone.getDefault().getOffset(now) / 60_000
        val utcMinute = ((localReminderHour * 60 - offsetMinutes) % 1440 + 1440) % 1440
        val bucket = utcMinute / 15

        FirebaseFunctions.getInstance()
            .getHttpsCallable("registerPushToken")
            .call(
                mapOf(
                    "token" to token,
                    "platform" to "android",
                    "language" to Locale.getDefault().toLanguageTag(),
                    "timeZone" to TimeZone.getDefault().id,
                    "reminderBucket" to bucket,
                    "examId" to examId,
                    "examName" to examName
                )
            )
    }
}
