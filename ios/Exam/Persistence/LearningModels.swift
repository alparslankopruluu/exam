import Foundation
import SwiftData

@Model
final class MasteryRecord {
    @Attribute(.unique) var skillId: String
    var examId: String
    var score: Double
    var attempts: Int
    var correctCount: Int
    var averageResponseMs: Double
    var lastSeenAt: Date
    var nextReviewAt: Date

    init(
        skillId: String,
        examId: String,
        score: Double = 0.5,
        attempts: Int = 0,
        correctCount: Int = 0,
        averageResponseMs: Double = 0,
        lastSeenAt: Date = .now,
        nextReviewAt: Date = .now
    ) {
        self.skillId = skillId
        self.examId = examId
        self.score = score
        self.attempts = attempts
        self.correctCount = correctCount
        self.averageResponseMs = averageResponseMs
        self.lastSeenAt = lastSeenAt
        self.nextReviewAt = nextReviewAt
    }
}

@Model
final class MistakeRecord {
    @Attribute(.unique) var id: String
    var examId: String
    var questionId: String
    var skillId: String
    var errorType: String
    var selectedAnswer: String?
    var correctAnswer: String?
    var createdAt: Date
    var resolved: Bool

    init(
        id: String = UUID().uuidString,
        examId: String,
        questionId: String,
        skillId: String,
        errorType: String,
        selectedAnswer: String?,
        correctAnswer: String?,
        createdAt: Date = .now,
        resolved: Bool = false
    ) {
        self.id = id
        self.examId = examId
        self.questionId = questionId
        self.skillId = skillId
        self.errorType = errorType
        self.selectedAnswer = selectedAnswer
        self.correctAnswer = correctAnswer
        self.createdAt = createdAt
        self.resolved = resolved
    }
}

@Model
final class StudySessionRecord {
    @Attribute(.unique) var id: String
    var examId: String
    var sessionType: String
    var startedAt: Date
    var completedAt: Date?
    var correctCount: Int
    var totalCount: Int
    var durationSeconds: Int

    init(
        id: String = UUID().uuidString,
        examId: String,
        sessionType: String,
        startedAt: Date = .now,
        completedAt: Date? = nil,
        correctCount: Int = 0,
        totalCount: Int = 0,
        durationSeconds: Int = 0
    ) {
        self.id = id
        self.examId = examId
        self.sessionType = sessionType
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.correctCount = correctCount
        self.totalCount = totalCount
        self.durationSeconds = durationSeconds
    }
}

@Model
final class MaterialRecord {
    @Attribute(.unique) var id: String
    var title: String
    var mimeType: String
    var localURL: String?
    var remotePath: String?
    var summary: String?
    var indexed: Bool
    var createdAt: Date

    init(
        id: String,
        title: String,
        mimeType: String,
        localURL: String? = nil,
        remotePath: String? = nil,
        summary: String? = nil,
        indexed: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.mimeType = mimeType
        self.localURL = localURL
        self.remotePath = remotePath
        self.summary = summary
        self.indexed = indexed
        self.createdAt = createdAt
    }
}

@Model
final class DailyPlanRecord {
    @Attribute(.unique) var id: String
    var dayKey: String
    var taskType: String
    var skillId: String?
    var title: String
    var estimatedMinutes: Int
    var completed: Bool
    var priority: Double

    init(
        id: String = UUID().uuidString,
        dayKey: String,
        taskType: String,
        skillId: String?,
        title: String,
        estimatedMinutes: Int,
        completed: Bool = false,
        priority: Double
    ) {
        self.id = id
        self.dayKey = dayKey
        self.taskType = taskType
        self.skillId = skillId
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.completed = completed
        self.priority = priority
    }
}
