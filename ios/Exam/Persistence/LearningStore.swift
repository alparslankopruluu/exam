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

    init(
        id: String = UUID().uuidString,
        type: String,
        skillId: String?,
        title: String,
        estimatedMinutes: Int,
        priority: Double
    ) {
        self.id = id
        self.type = type
        self.skillId = skillId
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.priority = priority
    }
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
