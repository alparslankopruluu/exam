import Foundation

enum AnalyticsEvent {
    static let onboardingStarted = "onboarding_started"
    static let countrySelected = "country_selected"
    static let examSelected = "exam_selected"
    static let goalSelected = "goal_selected"
    static let diagnosticStarted = "diagnostic_started"
    static let diagnosticCompleted = "diagnostic_completed"
    static let planGenerated = "plan_generated"

    static let paywallViewed = "paywall_viewed"
    static let subscriptionPlanSelected = "subscription_plan_selected"
    static let trialStarted = "trial_started"
    static let purchaseCompleted = "purchase_completed"
    static let purchaseFailed = "purchase_failed"
    static let paywallClosed = "paywall_closed"

    static let dailyMissionStarted = "daily_mission_started"
    static let dailyMissionCompleted = "daily_mission_completed"
    static let questionAnswered = "question_answered"
    static let explanationRequested = "explanation_requested"
    static let aiTutorStarted = "ai_tutor_started"
    static let voiceTutorStarted = "voice_tutor_started"
    static let materialAdded = "material_added"
    static let quizGenerated = "quiz_generated"
    static let mockStarted = "mock_started"
    static let mockCompleted = "mock_completed"
    static let streakExtended = "streak_extended"
}

enum AnalyticsParam {
    static let countryCode = "country_code"
    static let examId = "exam_id"
    static let contentPackId = "content_pack_id"
    static let languageCode = "language_code"
    static let placement = "placement"
    static let productId = "product_id"
    static let subjectId = "subject_id"
    static let topicId = "topic_id"
    static let difficulty = "difficulty"
    static let answerCorrect = "answer_correct"
    static let responseTimeMs = "response_time_ms"
    static let sessionType = "session_type"
    static let premiumStatus = "premium_status"
}
