package com.kprl.exam.platform.notifications

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.functions.FirebaseFunctions
import com.kprl.exam.platform.persistence.UserProgressStore
import java.util.Locale
import java.util.TimeZone

object PushTokenRegistrar {
    /**
     * Registers the device and the study state the server uses to choose
     * which reminder (if any) to send. Safe to call on every foreground.
     */
    fun register(
        context: Context,
        token: String,
        examId: String? = null,
        examName: String? = null,
        localReminderHour: Int? = null,
        dueReviews: Int? = null
    ) {
        if (runCatching { FirebaseApp.getInstance() }.isFailure) return

        val progressStore = UserProgressStore(context.applicationContext)
        val progress = progressStore.snapshot()
        val reminderHour = localReminderHour ?: progress.reminderHour
        val now = System.currentTimeMillis()
        val offsetMinutes = TimeZone.getDefault().getOffset(now) / 60_000
        val utcMinute = ((reminderHour * 60 - offsetMinutes) % 1440 + 1440) % 1440
        val bucket = utcMinute / 15

        val payload = buildMap<String, Any> {
            put("token", token)
            put("platform", "android")
            put("language", Locale.getDefault().toLanguageTag())
            put("timeZone", TimeZone.getDefault().id)
            put("reminderBucket", bucket)
            put("streak", progress.streak)
            examId?.let { put("examId", it) }
            examName?.let { put("examName", it) }
            dueReviews?.let { put("dueReviews", it) }
            progressStore.lastStudyDay()?.let { put("lastStudyDay", it) }
        }

        FirebaseFunctions.getInstance()
            .getHttpsCallable("registerPushToken")
            .call(payload)
    }
}
