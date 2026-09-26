package com.kprl.exam.platform.persistence

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class LearningDatabase(context: Context) :
    SQLiteOpenHelper(context, "exam_learning.db", null, VERSION) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE mastery (
                skill_id TEXT PRIMARY KEY,
                exam_id TEXT NOT NULL,
                score REAL NOT NULL,
                attempts INTEGER NOT NULL,
                correct_count INTEGER NOT NULL,
                average_response_ms REAL NOT NULL,
                last_seen_at INTEGER NOT NULL,
                next_review_at INTEGER NOT NULL
            )
            """.trimIndent()
        )

        db.execSQL(
            """
            CREATE TABLE mistakes (
                id TEXT PRIMARY KEY,
                exam_id TEXT NOT NULL,
                question_id TEXT NOT NULL,
                skill_id TEXT NOT NULL,
                error_type TEXT NOT NULL,
                selected_answer TEXT,
                correct_answer TEXT,
                created_at INTEGER NOT NULL,
                resolved INTEGER NOT NULL DEFAULT 0
            )
            """.trimIndent()
        )

        db.execSQL(
            """
            CREATE TABLE study_sessions (
                id TEXT PRIMARY KEY,
                exam_id TEXT NOT NULL,
                session_type TEXT NOT NULL,
                started_at INTEGER NOT NULL,
                completed_at INTEGER,
                correct_count INTEGER NOT NULL,
                total_count INTEGER NOT NULL,
                duration_seconds INTEGER NOT NULL
            )
            """.trimIndent()
        )

        db.execSQL(
            """
            CREATE TABLE materials (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                mime_type TEXT NOT NULL,
                local_uri TEXT,
                remote_path TEXT,
                summary TEXT,
                indexed INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL
            )
            """.trimIndent()
        )

        db.execSQL(
            """
            CREATE TABLE daily_plan (
                id TEXT PRIMARY KEY,
                day_key TEXT NOT NULL,
                task_type TEXT NOT NULL,
                skill_id TEXT,
                title TEXT NOT NULL,
                estimated_minutes INTEGER NOT NULL,
                completed INTEGER NOT NULL DEFAULT 0,
                priority REAL NOT NULL
            )
            """.trimIndent()
        )

        db.execSQL("CREATE INDEX idx_mastery_exam_score ON mastery(exam_id, score)")
        db.execSQL("CREATE INDEX idx_mistakes_exam_skill ON mistakes(exam_id, skill_id, resolved)")
        db.execSQL("CREATE INDEX idx_plan_day ON daily_plan(day_key, completed, priority)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    companion object {
        private const val VERSION = 1
    }
}
