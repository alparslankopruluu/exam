package com.kprl.exam.platform.persistence

import android.content.Context
import com.kprl.exam.data.ExamCatalog
import com.kprl.exam.data.StudySetup

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

    fun isOnboardingPaywallSeen(): Boolean =
        prefs.getBoolean("onboarding_paywall_seen", false)

    fun setOnboardingPaywallSeen(seen: Boolean) {
        prefs.edit().putBoolean("onboarding_paywall_seen", seen).apply()
    }

    fun clear() {
        prefs.edit().clear().apply()
    }
}
