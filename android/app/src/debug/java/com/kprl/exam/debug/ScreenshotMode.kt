package com.kprl.exam.debug

import android.content.Context
import android.content.Intent
import com.kprl.exam.data.ExamCatalog
import com.kprl.exam.data.StudySetup
import com.kprl.exam.platform.persistence.StudySetupStore
import java.time.LocalDate

/**
 * Debug-only state seeding for store screenshots, driven by intent extras:
 *   adb shell am start -n com.kprl.exam/.MainActivity \
 *     --es screenshotLanguage tr --es screenshotExam tr_yks --es screenshotScreen today
 * Screens: today, practice, tutor, library, session.
 */
object ScreenshotMode {
    var screen: String? = null
        private set

    fun prepare(context: Context, intent: Intent?) {
        val language = intent?.getStringExtra("screenshotLanguage") ?: return
        val exam = ExamCatalog.findExam(intent.getStringExtra("screenshotExam") ?: "intl_ielts") ?: return
        val country = ExamCatalog.findCountry(exam.countryCode ?: "OTHER") ?: return
        screen = intent.getStringExtra("screenshotScreen") ?: "today"

        val setupStore = StudySetupStore(context)
        setupStore.save(
            StudySetup(
                country = country,
                exam = exam,
                languageCode = language,
                goalKey = "target_score",
                dailyMinutes = 30,
                diagnosticPercent = 64
            )
        )
        setupStore.setOnboardingPaywallSeen(true)
        setupStore.setNotificationPrompted(true)
        setupStore.setExamDate(LocalDate.now().plusDays(47))

        context.getSharedPreferences("user_progress", Context.MODE_PRIVATE).edit()
            .putInt("streak", 12)
            .putInt("xp", 1840)
            .putInt("sessions", 38)
            .putInt("questions", 412)
            .putString("last_study_day", LocalDate.now().toString())
            .apply()
    }
}
