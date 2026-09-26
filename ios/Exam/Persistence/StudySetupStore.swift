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

    static func onboardingPaywallSeen() -> Bool {
        UserDefaults.standard.bool(forKey: "study.onboardingPaywallSeen")
    }

    static func setOnboardingPaywallSeen(_ seen: Bool) {
        UserDefaults.standard.set(seen, forKey: "study.onboardingPaywallSeen")
    }

    static func clear() {
        [
            "study.country",
            "study.exam",
            "study.language",
            "study.goal",
            "study.dailyMinutes",
            "study.diagnosticPercent",
            "study.onboardingPaywallSeen"
        ].forEach(UserDefaults.standard.removeObject(forKey:))
    }
}
