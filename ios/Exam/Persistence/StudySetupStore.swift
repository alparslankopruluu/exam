import Foundation

@MainActor
enum StudySetupStore {
    static func save(_ setup: StudySetup) {
        UserDefaults.standard.set(setup.country.code, forKey: "study.country")
        UserDefaults.standard.set(setup.exam.id, forKey: "study.exam")
        UserDefaults.standard.set(setup.languageCode, forKey: "study.language")
        UserDefaults.standard.set(setup.goalKey, forKey: "study.goal")
        UserDefaults.standard.set(setup.dailyMinutes, forKey: "study.dailyMinutes")
        UserDefaults.standard.set(setup.diagnosticPercent, forKey: "study.diagnosticPercent")
    }

    static func load() -> StudySetup? {
        guard
            let countryCode = UserDefaults.standard.string(forKey: "study.country"),
            let examId = UserDefaults.standard.string(forKey: "study.exam"),
            let country = ExamCatalog.country(code: countryCode),
            let exam = ExamCatalog.exam(id: examId)
        else {
            return nil
        }

        return StudySetup(
            country: country,
            exam: exam,
            languageCode: UserDefaults.standard.string(forKey: "study.language") ?? ExamCatalog.languageCode,
            goalKey: UserDefaults.standard.string(forKey: "study.goal") ?? "improve",
            dailyMinutes: UserDefaults.standard.object(forKey: "study.dailyMinutes") == nil ? 20 : UserDefaults.standard.integer(forKey: "study.dailyMinutes"),
            diagnosticPercent: UserDefaults.standard.object(forKey: "study.diagnosticPercent") == nil ? 50 : UserDefaults.standard.integer(forKey: "study.diagnosticPercent")
        )
    }

    /// Optional exam date; nil means the learner does not know it yet.
    static func examDate() -> Date? {
        UserDefaults.standard.object(forKey: "study.examDate") as? Date
    }

    static func setExamDate(_ date: Date?) {
        if let date {
            UserDefaults.standard.set(Calendar.current.startOfDay(for: date), forKey: "study.examDate")
        } else {
            UserDefaults.standard.removeObject(forKey: "study.examDate")
        }
    }

    /// Whole days from today to the exam; nil when unknown or already past.
    static func daysToExam(now: Date = .now) -> Int? {
        guard let date = examDate() else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: date).day ?? 0
        return days >= 0 ? days : nil
    }

    static func onboardingPaywallSeen() -> Bool {
        UserDefaults.standard.bool(forKey: "study.onboardingPaywallSeen")
    }

    static func setOnboardingPaywallSeen(_ seen: Bool) {
        UserDefaults.standard.set(seen, forKey: "study.onboardingPaywallSeen")
    }

    static func notificationPrompted() -> Bool {
        UserDefaults.standard.bool(forKey: "study.notificationPrompted")
    }

    static func setNotificationPrompted(_ prompted: Bool) {
        UserDefaults.standard.set(prompted, forKey: "study.notificationPrompted")
    }

    static func clear() {
        [
            "study.country",
            "study.exam",
            "study.language",
            "study.goal",
            "study.dailyMinutes",
            "study.diagnosticPercent",
            "study.examDate",
            "study.onboardingPaywallSeen",
            "study.notificationPrompted"
        ].forEach(UserDefaults.standard.removeObject(forKey:))
    }
}
