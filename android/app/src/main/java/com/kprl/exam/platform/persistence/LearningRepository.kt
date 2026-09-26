package com.kprl.exam.platform.persistence

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import java.util.UUID

data class MasterySnapshot(
    val skillId: String,
    val examId: String,
    val score: Double,
    val attempts: Int,
    val correctCount: Int,
    val averageResponseMs: Double,
    val lastSeenAt: Long,
    val nextReviewAt: Long
)

data class ErrorDNAItem(
    val skillId: String,
    val errorType: String,
    val count: Int
)

data class PlanTask(
    val id: String,
    val type: String,
    val skillId: String?,
    val title: String,
    val estimatedMinutes: Int,
    val priority: Double
)

class LearningRepository(private val database: LearningDatabase) {
    fun recordAnswer(
        examId: String,
        skillId: String,
        questionId: String,
        correct: Boolean,
        responseTimeMs: Long,
        selectedAnswer: String?,
        correctAnswer: String?,
        errorType: String = if (correct) "none" else "concept"
    ) {
        val db = database.writableDatabase
        val now = System.currentTimeMillis()
        db.beginTransaction()
        try {
            val previous = mastery(skillId)
            val attempts = (previous?.attempts ?: 0) + 1
            val correctCount = (previous?.correctCount ?: 0) + if (correct) 1 else 0
            val oldScore = previous?.score ?: 0.5
            val newScore = (oldScore * 0.8 + (if (correct) 1.0 else 0.0) * 0.2)
                .coerceIn(0.0, 1.0)
            val oldAverage = previous?.averageResponseMs ?: responseTimeMs.toDouble()
            val average = oldAverage + (responseTimeMs - oldAverage) / attempts.toDouble()
            val reviewDelayHours = when {
                !correct -> 8
                newScore < 0.65 -> 24
                newScore < 0.8 -> 72
                else -> 24 * 7
            }

            db.insertWithOnConflict(
                "mastery",
                null,
                ContentValues().apply {
                    put("skill_id", skillId)
                    put("exam_id", examId)
                    put("score", newScore)
                    put("attempts", attempts)
                    put("correct_count", correctCount)
                    put("average_response_ms", average)
                    put("last_seen_at", now)
                    put("next_review_at", now + reviewDelayHours * 60L * 60L * 1000L)
                },
                SQLiteDatabase.CONFLICT_REPLACE
            )

            if (!correct) {
                db.insert(
                    "mistakes",
                    null,
                    ContentValues().apply {
                        put("id", UUID.randomUUID().toString())
                        put("exam_id", examId)
                        put("question_id", questionId)
                        put("skill_id", skillId)
                        put("error_type", errorType)
                        put("selected_answer", selectedAnswer)
                        put("correct_answer", correctAnswer)
                        put("created_at", now)
                        put("resolved", 0)
                    }
                )
            }

            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun weakSkills(examId: String, limit: Int = 8): List<MasterySnapshot> {
        val result = mutableListOf<MasterySnapshot>()
        database.readableDatabase.query(
            "mastery", null, "exam_id = ?", arrayOf(examId),
            null, null, "score ASC, next_review_at ASC", limit.toString()
        ).use { cursor ->
            while (cursor.moveToNext()) result += cursor.toMastery()
        }
        return result
    }

    fun dueSkills(examId: String, now: Long = System.currentTimeMillis()): List<MasterySnapshot> {
        val result = mutableListOf<MasterySnapshot>()
        database.readableDatabase.query(
            "mastery", null, "exam_id = ? AND next_review_at <= ?",
            arrayOf(examId, now.toString()), null, null, "next_review_at ASC", "20"
        ).use { cursor ->
            while (cursor.moveToNext()) result += cursor.toMastery()
        }
        return result
    }

    fun errorDNA(examId: String): List<ErrorDNAItem> {
        val result = mutableListOf<ErrorDNAItem>()
        database.readableDatabase.rawQuery(
            """
            SELECT skill_id, error_type, COUNT(*) AS c
            FROM mistakes
            WHERE exam_id = ? AND resolved = 0
            GROUP BY skill_id, error_type
            ORDER BY c DESC
            LIMIT 20
            """.trimIndent(),
            arrayOf(examId)
        ).use { cursor ->
            while (cursor.moveToNext()) {
                result += ErrorDNAItem(cursor.getString(0), cursor.getString(1), cursor.getInt(2))
            }
        }
        return result
    }

    fun saveSession(
        examId: String,
        sessionType: String,
        startedAt: Long,
        completedAt: Long,
        correctCount: Int,
        totalCount: Int
    ) {
        database.writableDatabase.insert(
            "study_sessions",
            null,
            ContentValues().apply {
                put("id", UUID.randomUUID().toString())
                put("exam_id", examId)
                put("session_type", sessionType)
                put("started_at", startedAt)
                put("completed_at", completedAt)
                put("correct_count", correctCount)
                put("total_count", totalCount)
                put("duration_seconds", ((completedAt - startedAt) / 1000L).coerceAtLeast(0L))
            }
        )
    }

    fun savePlan(dayKey: String, tasks: List<PlanTask>) {
        val db = database.writableDatabase
        db.delete("daily_plan", "day_key = ?", arrayOf(dayKey))
        tasks.forEach { task ->
            db.insert(
                "daily_plan",
                null,
                ContentValues().apply {
                    put("id", task.id)
                    put("day_key", dayKey)
                    put("task_type", task.type)
                    put("skill_id", task.skillId)
                    put("title", task.title)
                    put("estimated_minutes", task.estimatedMinutes)
                    put("completed", 0)
                    put("priority", task.priority)
                }
            )
        }
    }

    private fun mastery(skillId: String): MasterySnapshot? =
        database.readableDatabase.query(
            "mastery", null, "skill_id = ?", arrayOf(skillId),
            null, null, null, "1"
        ).use { cursor -> if (cursor.moveToFirst()) cursor.toMastery() else null }

    private fun android.database.Cursor.toMastery() = MasterySnapshot(
        skillId = getString(getColumnIndexOrThrow("skill_id")),
        examId = getString(getColumnIndexOrThrow("exam_id")),
        score = getDouble(getColumnIndexOrThrow("score")),
        attempts = getInt(getColumnIndexOrThrow("attempts")),
        correctCount = getInt(getColumnIndexOrThrow("correct_count")),
        averageResponseMs = getDouble(getColumnIndexOrThrow("average_response_ms")),
        lastSeenAt = getLong(getColumnIndexOrThrow("last_seen_at")),
        nextReviewAt = getLong(getColumnIndexOrThrow("next_review_at"))
    )
}
