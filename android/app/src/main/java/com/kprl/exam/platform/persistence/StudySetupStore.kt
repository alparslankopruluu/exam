package com.kprl.exam.platform.persistence

import android.content.Context
import com.kprl.exam.data.ExamCatalog
import com.kprl.exam.data.StudySetup
import java.time.LocalDate
import java.time.temporal.ChronoUnit

class StudySetupStore(context: Context) {
    private val prefs = context.getSharedPreferences("study_setup", Context.MODE_PRIVATE)

    fun save(setup: StudySetup) {
        prefs.edit()
            .putString("country_code", setup.country.code)
            .putString("exam_id", setup.exam.id)
            .putString("language_code", setup.languageCode)
            .putString("goal_key", setup.goalKey)
            .putInt("daily_minutes", setup.dailyMinutes)
            .putInt("diagnostic_percent", setup.diagnosticPercent)
            .apply()
    }

    fun load(): StudySetup? {
        val countryCode = prefs.getString("country_code", null) ?: return null
        val examId = prefs.getString("exam_id", null) ?: return null
        val country = ExamCatalog.findCountry(countryCode) ?: return null
        val exam = ExamCatalog.findExam(examId) ?: return null

        return StudySetup(
            country = country,
            exam = exam,
            languageCode = prefs.getString("language_code", null)
                ?: ExamCatalog.languageCode(),
            goalKey = prefs.getString("goal_key", "improve") ?: "improve",
            dailyMinutes = prefs.getInt("daily_minutes", 20),
            diagnosticPercent = prefs.getInt("diagnostic_percent", 50)
        )
    }

    /** Optional exam date; null means the learner does not know it yet. */
    fun examDate(): LocalDate? =
        prefs.getLong("exam_epoch_day", Long.MIN_VALUE).takeIf { it != Long.MIN_VALUE }?.let(LocalDate::ofEpochDay)

    fun setExamDate(date: LocalDate?) {
        prefs.edit().apply {
            if (date == null) remove("exam_epoch_day") else putLong("exam_epoch_day", date.toEpochDay())
        }.apply()
    }

    /** Whole days from today to the exam; null when unknown or already past. */
    fun daysToExam(today: LocalDate = LocalDate.now()): Int? =
        examDate()?.let { ChronoUnit.DAYS.between(today, it).toInt() }?.takeIf { it >= 0 }

    fun isOnboardingPaywallSeen(): Boolean =
        prefs.getBoolean("onboarding_paywall_seen", false)

    fun setOnboardingPaywallSeen(seen: Boolean) {
        prefs.edit().putBoolean("onboarding_paywall_seen", seen).apply()
    }

    fun isNotificationPrompted(): Boolean =
        prefs.getBoolean("notification_prompted", false)

    fun setNotificationPrompted(prompted: Boolean) {
        prefs.edit().putBoolean("notification_prompted", prompted).apply()
    }

    fun clear() {
        prefs.edit().clear().apply()
    }
}
