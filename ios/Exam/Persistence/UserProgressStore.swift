import Foundation

struct UserProgressSnapshot: Hashable {
    let xp: Int
    let streak: Int
    let totalSessions: Int
    let totalQuestions: Int
    let reminderHour: Int
}

struct UserProgressStore {
    private let defaults = UserDefaults.standard

    /// Local calendar day of the last completed study session.
    func lastStudyDay() -> Date? {
        defaults.object(forKey: "progress.lastStudyDay") as? Date
    }

    func snapshot() -> UserProgressSnapshot {
        UserProgressSnapshot(
            xp: defaults.integer(forKey: "progress.xp"),
            streak: defaults.integer(forKey: "progress.streak"),
            totalSessions: defaults.integer(forKey: "progress.sessions"),
            totalQuestions: defaults.integer(forKey: "progress.questions"),
            reminderHour: defaults.object(forKey: "progress.reminderHour") == nil
                ? 19
                : defaults.integer(forKey: "progress.reminderHour")
        )
    }

    @discardableResult
    func recordSession(correct: Int, total: Int, durationSeconds: Int) -> UserProgressSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let previous = defaults.object(forKey: "progress.lastStudyDay") as? Date
        let oldStreak = defaults.integer(forKey: "progress.streak")

        let streak: Int
        if let previous {
            let previousDay = calendar.startOfDay(for: previous)
            let days = calendar.dateComponents([.day], from: previousDay, to: today).day ?? 0
            if days == 0 {
                streak = max(oldStreak, 1)
            } else if days == 1 {
                streak = oldStreak + 1
            } else {
                streak = 1
            }
        } else {
            streak = 1
        }

        let earnedXP = max(
            5,
            correct * 12 + max(0, total - correct) * 3 + durationSeconds / 60
        )

        defaults.set(defaults.integer(forKey: "progress.xp") + earnedXP, forKey: "progress.xp")
        defaults.set(streak, forKey: "progress.streak")
        defaults.set(defaults.integer(forKey: "progress.sessions") + 1, forKey: "progress.sessions")
        defaults.set(defaults.integer(forKey: "progress.questions") + total, forKey: "progress.questions")
        defaults.set(today, forKey: "progress.lastStudyDay")

        return snapshot()
    }

    func setReminderHour(_ hour: Int) {
        defaults.set(min(max(hour, 0), 23), forKey: "progress.reminderHour")
    }

    func reset() {
        [
            "progress.xp",
            "progress.streak",
            "progress.sessions",
            "progress.questions",
            "progress.lastStudyDay",
            "progress.reminderHour"
        ].forEach(defaults.removeObject(forKey:))
    }
}
