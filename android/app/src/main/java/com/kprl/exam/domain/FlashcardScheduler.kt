package com.kprl.exam.domain

import android.content.Context

enum class FlashcardRating { AGAIN, HARD, GOOD, EASY }

class FlashcardScheduler(context: Context) {
    private val prefs = context.getSharedPreferences("flashcard_schedule", Context.MODE_PRIVATE)

    fun isDue(cardId: String, now: Long = System.currentTimeMillis()): Boolean =
        prefs.getLong("due_$cardId", 0L) <= now

    fun review(cardId: String, rating: FlashcardRating) {
        val now = System.currentTimeMillis()
        val hours = when (rating) {
            FlashcardRating.AGAIN -> 1
            FlashcardRating.HARD -> 12
            FlashcardRating.GOOD -> 72
            FlashcardRating.EASY -> 24 * 7
        }
        prefs.edit().putLong("due_$cardId", now + hours * 60L * 60L * 1000L).apply()
    }
}
