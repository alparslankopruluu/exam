import Foundation
import SwiftData

struct MasterySnapshot: Hashable {
    let skillId: String
    let examId: String
    let score: Double
    let attempts: Int
    let correctCount: Int
    let averageResponseMs: Double
    let lastSeenAt: Date
    let nextReviewAt: Date
}

struct ErrorDNAItem: Hashable {
    let skillId: String
    let errorType: String
    let count: Int
}

struct PlanTask: Identifiable, Hashable {
    let id: String
    let type: String
    let skillId: String?
    let title: String
    let estimatedMinutes: Int
    let priority: Double
    let completed: Bool

    init(
        id: String = UUID().uuidString,
        type: String,
        skillId: String?,
        title: String,
        estimatedMinutes: Int,
        priority: Double,
        completed: Bool = false
    ) {
        self.id = id
        self.type = type
        self.skillId = skillId
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.priority = priority
        self.completed = completed
    }
}

struct MistakeDetail: Identifiable, Hashable {
    let id: String
    let questionId: String
    let skillId: String
    let errorType: String
    let selectedAnswer: String?
    let correctAnswer: String?
    let createdAt: Date
}

struct StudyProgressSummary: Hashable {
    let masteryPercent: Int
    let sessions: Int
    let questions: Int
    let correct: Int
    let studyMinutes: Int
}

@MainActor
final class LearningStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func recordAnswer(
        examId: String,
        skillId: String,
        questionId: String,
        correct: Bool,
        responseTimeMs: Int,
        selectedAnswer: String?,
        correctAnswer: String?,
        errorType: String = "concept"
    ) throws {
        let all = try context.fetch(FetchDescriptor<MasteryRecord>())
        let record = all.first { $0.skillId == skillId }
            ?? MasteryRecord(skillId: skillId, examId: examId)

        if record.modelContext == nil {
            context.insert(record)
        }

        let attempts = record.attempts + 1
        let newScore = min(max(record.score * 0.8 + (correct ? 1 : 0) * 0.2, 0), 1)
        let average = record.attempts == 0
            ? Double(responseTimeMs)
            : record.averageResponseMs + (Double(responseTimeMs) - record.averageResponseMs) / Double(attempts)

        record.examId = examId
        record.attempts = attempts
        record.correctCount += correct ? 1 : 0
        record.score = newScore
        record.averageResponseMs = average
        record.lastSeenAt = .now

        let hours: Int
        if !correct { hours = 8 }
        else if newScore < 0.65 { hours = 24 }
        else if newScore < 0.8 { hours = 72 }
        else { hours = 24 * 7 }

        record.nextReviewAt = Calendar.current.date(byAdding: .hour, value: hours, to: .now) ?? .now

        if !correct {
            context.insert(
                MistakeRecord(
                    examId: examId,
                    questionId: questionId,
                    skillId: skillId,
                    errorType: errorType,
                    selectedAnswer: selectedAnswer,
                    correctAnswer: correctAnswer
                )
            )
        }

        try context.save()
    }

    func weakSkills(examId: String, limit: Int = 8) throws -> [MasterySnapshot] {
        try context.fetch(FetchDescriptor<MasteryRecord>())
            .filter { $0.examId == examId }
            .sorted {
                if $0.score == $1.score { return $0.nextReviewAt < $1.nextReviewAt }
                return $0.score < $1.score
            }
            .prefix(limit)
            .map(snapshot)
    }

    func dueSkills(examId: String, now: Date = .now) throws -> [MasterySnapshot] {
        try context.fetch(FetchDescriptor<MasteryRecord>())
            .filter { $0.examId == examId && $0.nextReviewAt <= now }
            .sorted { $0.nextReviewAt < $1.nextReviewAt }
            .prefix(20)
            .map(snapshot)
    }

    func errorDNA(examId: String) throws -> [ErrorDNAItem] {
        let mistakes = try context.fetch(FetchDescriptor<MistakeRecord>())
            .filter { $0.examId == examId && !$0.resolved }

        let grouped = Dictionary(grouping: mistakes) {
            $0.skillId + "|" + $0.errorType
        }

        return grouped.map { key, values in
            let pieces = key.split(separator: "|", maxSplits: 1).map(String.init)
            return ErrorDNAItem(
                skillId: pieces.first ?? "",
                errorType: pieces.count > 1 ? pieces[1] : "concept",
                count: values.count
            )
        }
        .sorted { $0.count > $1.count }
    }

    func saveSession(
        examId: String,
        sessionType: String,
        startedAt: Date,
        completedAt: Date,
        correctCount: Int,
        totalCount: Int
    ) throws {
        context.insert(
            StudySessionRecord(
                examId: examId,
                sessionType: sessionType,
                startedAt: startedAt,
                completedAt: completedAt,
                correctCount: correctCount,
                totalCount: totalCount,
                durationSeconds: max(0, Int(completedAt.timeIntervalSince(startedAt)))
            )
        )
        try context.save()
    }

    func mistakes(examId: String, limit: Int = 100) throws -> [MistakeDetail] {
        try context.fetch(FetchDescriptor<MistakeRecord>())
            .filter { $0.examId == examId && !$0.resolved }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map {
                MistakeDetail(
                    id: $0.id,
                    questionId: $0.questionId,
                    skillId: $0.skillId,
                    errorType: $0.errorType,
                    selectedAnswer: $0.selectedAnswer,
                    correctAnswer: $0.correctAnswer,
                    createdAt: $0.createdAt
                )
            }
    }

    func resolveMistake(id: String) throws {
        let rows = try context.fetch(FetchDescriptor<MistakeRecord>())
        if let row = rows.first(where: { $0.id == id }) {
            row.resolved = true
            try context.save()
        }
    }

    func progressSummary(examId: String) throws -> StudyProgressSummary {
        let masteryRows = try context.fetch(FetchDescriptor<MasteryRecord>())
            .filter { $0.examId == examId }
        let mastery = masteryRows.isEmpty
            ? 0
            : Int((masteryRows.map(\.score).reduce(0, +) / Double(masteryRows.count)) * 100)

        let sessions = try context.fetch(FetchDescriptor<StudySessionRecord>())
            .filter { $0.examId == examId }

        return StudyProgressSummary(
            masteryPercent: min(max(mastery, 0), 100),
            sessions: sessions.count,
            questions: sessions.map(\.totalCount).reduce(0, +),
            correct: sessions.map(\.correctCount).reduce(0, +),
            studyMinutes: sessions.map(\.durationSeconds).reduce(0, +) / 60
        )
    }

    func plan(dayKey: String) throws -> [PlanTask] {
        try context.fetch(FetchDescriptor<DailyPlanRecord>())
            .filter { $0.dayKey == dayKey }
            .sorted {
                if $0.completed != $1.completed { return !$0.completed }
                return $0.priority > $1.priority
            }
            .map {
                PlanTask(
                    id: $0.id,
                    type: $0.taskType,
                    skillId: $0.skillId,
                    title: $0.title,
                    estimatedMinutes: $0.estimatedMinutes,
                    priority: $0.priority,
                    completed: $0.completed
                )
            }
    }

    func markPlanCompleted(id: String) throws {
        let rows = try context.fetch(FetchDescriptor<DailyPlanRecord>())
        if let row = rows.first(where: { $0.id == id }) {
            row.completed = true
            try context.save()
        }
    }

    func savePlan(dayKey: String, tasks: [PlanTask]) throws {
        let existing = try context.fetch(FetchDescriptor<DailyPlanRecord>())
            .filter { $0.dayKey == dayKey }

        existing.forEach(context.delete)

        tasks.forEach { task in
            context.insert(
                DailyPlanRecord(
                    id: task.id,
                    dayKey: dayKey,
                    taskType: task.type,
                    skillId: task.skillId,
                    title: task.title,
                    estimatedMinutes: task.estimatedMinutes,
                    priority: task.priority
                )
            )
        }

        try context.save()
    }

    private func snapshot(_ record: MasteryRecord) -> MasterySnapshot {
        MasterySnapshot(
            skillId: record.skillId,
            examId: record.examId,
            score: record.score,
            attempts: record.attempts,
            correctCount: record.correctCount,
            averageResponseMs: record.averageResponseMs,
            lastSeenAt: record.lastSeenAt,
            nextReviewAt: record.nextReviewAt
        )
    }
}
