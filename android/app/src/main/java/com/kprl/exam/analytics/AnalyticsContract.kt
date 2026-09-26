package com.kprl.exam.analytics

object AnalyticsEvents {
    const val ONBOARDING_STARTED = "onboarding_started"
    const val COUNTRY_SELECTED = "country_selected"
    const val EXAM_SELECTED = "exam_selected"
    const val GOAL_SELECTED = "goal_selected"
    const val DIAGNOSTIC_STARTED = "diagnostic_started"
    const val DIAGNOSTIC_COMPLETED = "diagnostic_completed"
    const val PLAN_GENERATED = "plan_generated"

    const val PAYWALL_VIEWED = "paywall_viewed"
    const val PLAN_SELECTED = "subscription_plan_selected"
    const val TRIAL_STARTED = "trial_started"
    const val PURCHASE_COMPLETED = "purchase_completed"
    const val PURCHASE_FAILED = "purchase_failed"
    const val PAYWALL_CLOSED = "paywall_closed"

    const val DAILY_MISSION_STARTED = "daily_mission_started"
    const val DAILY_MISSION_COMPLETED = "daily_mission_completed"
    const val QUESTION_ANSWERED = "question_answered"
    const val EXPLANATION_REQUESTED = "explanation_requested"
    const val AI_TUTOR_STARTED = "ai_tutor_started"
    const val VOICE_TUTOR_STARTED = "voice_tutor_started"
    const val MATERIAL_ADDED = "material_added"
    const val QUIZ_GENERATED = "quiz_generated"
    const val MOCK_STARTED = "mock_started"
    const val MOCK_COMPLETED = "mock_completed"
    const val STREAK_EXTENDED = "streak_extended"
}

object AnalyticsParams {
    const val COUNTRY_CODE = "country_code"
    const val EXAM_ID = "exam_id"
    const val CONTENT_PACK_ID = "content_pack_id"
    const val LANGUAGE_CODE = "language_code"
    const val PLACEMENT = "placement"
    const val PRODUCT_ID = "product_id"
    const val SUBJECT_ID = "subject_id"
    const val TOPIC_ID = "topic_id"
    const val DIFFICULTY = "difficulty"
    const val ANSWER_CORRECT = "answer_correct"
    const val RESPONSE_TIME_MS = "response_time_ms"
    const val SESSION_TYPE = "session_type"
    const val PREMIUM_STATUS = "premium_status"
}
