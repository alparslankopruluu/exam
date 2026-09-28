package com.kprl.exam.platform.persistence

import android.content.Context
import java.time.LocalDate
import java.time.temporal.ChronoUnit

data class UserProgressSnapshot(
    val xp: Int,
    val streak: Int,
    val totalSessions: Int,
    val totalQuestions: Int,
    val reminderHour: Int
)

class UserProgressStore(context: Context) {
    private val prefs = context.getSharedPreferences("user_progress", Context.MODE_PRIVATE)

    fun snapshot(): UserProgressSnapshot = UserProgressSnapshot(
        xp = prefs.getInt("xp", 0),
        streak = prefs.getInt("streak", 0),
        totalSessions = prefs.getInt("sessions", 0),
        totalQuestions = prefs.getInt("questions", 0),
        reminderHour = prefs.getInt("reminder_hour", 19)
    )

    /** ISO local date (yyyy-MM-dd) of the last completed study session. */
    fun lastStudyDay(): String? = prefs.getString("last_study_day", null)

    fun recordSession(correct: Int, total: Int, durationSeconds: Int): UserProgressSnapshot {
        val previousDay = prefs.getString("last_study_day", null)
        val today = LocalDate.now()
        val oldStreak = prefs.getInt("streak", 0)

        val streak = if (previousDay == null) {
            1
        } else {
            val oldDate = runCatching { LocalDate.parse(previousDay) }.getOrNull()
            when {
                oldDate == null -> 1
                oldDate == today -> oldStreak.coerceAtLeast(1)
                ChronoUnit.DAYS.between(oldDate, today) == 1L -> oldStreak + 1
                else -> 1
            }
        }

        val earnedXp = (correct * 12 + (total - correct).coerceAtLeast(0) * 3 + durationSeconds / 60)
            .coerceAtLeast(5)

        prefs.edit()
            .putInt("xp", prefs.getInt("xp", 0) + earnedXp)
            .putInt("streak", streak)
            .putInt("sessions", prefs.getInt("sessions", 0) + 1)
            .putInt("questions", prefs.getInt("questions", 0) + total)
            .putString("last_study_day", today.toString())
            .apply()

        return snapshot()
    }

    fun setReminderHour(hour: Int) {
        prefs.edit().putInt("reminder_hour", hour.coerceIn(0, 23)).apply()
    }

    fun reset() {
        prefs.edit().clear().apply()
    }
}
