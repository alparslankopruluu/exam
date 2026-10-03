import Foundation

/// Data the app prepares for the home-screen widgets. Labels are already
/// localized so the widget extension does not load locale files.
struct WidgetSnapshot: Codable, Equatable {
    struct Question: Codable, Equatable {
        let id: String
        let topic: String
        let prompt: String
        let options: [String]
        let correctIndex: Int
        let explanation: String
    }

    struct Labels: Codable, Equatable {
        let streak: String
        let tasksDone: String
        let reviewsDue: String
        let allDone: String
        let questionTitle: String
        let correct: String
        let incorrect: String
        let openApp: String
    }

    let examName: String
    let streak: Int
    let tasksCompleted: Int
    let tasksTotal: Int
    let dueReviews: Int
    let nextTaskTitle: String?
    let question: Question?
    let labels: Labels
    let updatedAt: Date

    static let appGroup = "group.com.techtactoe.examly"
    private static let snapshotKey = "widget.snapshot"
    private static let answerKey = "widget.answer"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults?.set(data, forKey: Self.snapshotKey)
    }

    /// The option chosen in the widget, keyed by question id so a new
    /// question starts unanswered.
    static func answer(for questionId: String) -> Int? {
        guard let stored = defaults?.dictionary(forKey: answerKey),
              stored["id"] as? String == questionId else { return nil }
        return stored["choice"] as? Int
    }

    static func saveAnswer(questionId: String, choice: Int) {
        defaults?.set(["id": questionId, "choice": choice], forKey: answerKey)
    }

    static let placeholder = WidgetSnapshot(
        examName: "Exam",
        streak: 3,
        tasksCompleted: 1,
        tasksTotal: 3,
        dueReviews: 2,
        nextTaskTitle: "Quick practice",
        question: Question(
            id: "placeholder",
            topic: "Math",
            prompt: "What is 12 × 8?",
            options: ["86", "96", "108", "112"],
            correctIndex: 1,
            explanation: "12 × 8 = 96."
        ),
        labels: Labels(
            streak: "day streak",
            tasksDone: "tasks done",
            reviewsDue: "reviews due",
            allDone: "All done for today",
            questionTitle: "Question of the day",
            correct: "Correct!",
            incorrect: "Not quite",
            openApp: "Open"
        ),
        updatedAt: .now
    )
}

#if canImport(ActivityKit)
import ActivityKit

/// Live Activity for a running focus session (lock screen and Dynamic Island).
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the phase ends; the system counts down to it without app updates.
        let endsAt: Date
    }

    /// Localized phase label, e.g. "Focus time".
    let title: String
    let exam: String
}
#endif
