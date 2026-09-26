import Foundation

enum StudySetupStore {
    private static let defaults = UserDefaults.standard

    static func save(_ setup: StudySetup) {
        defaults.set(setup.country.code, forKey: "study.country")
        defaults.set(setup.exam.id, forKey: "study.exam")
        defaults.set(setup.languageCode, forKey: "study.language")
        defaults.set(setup.goalKey, forKey: "study.goal")
        defaults.set(setup.dailyMinutes, forKey: "study.dailyMinutes")
        defaults.set(setup.diagnosticPercent, forKey: "study.diagnosticPercent")
    }

    static func load() -> StudySetup? {
        guard
            let countryCode = defaults.string(forKey: "study.country"),
            let examId = defaults.string(forKey: "study.exam"),
            let country = ExamCatalog.country(code: countryCode),
            let exam = ExamCatalog.exam(id: examId)
        else {
            return nil
        }

        return StudySetup(
            country: country,
            exam: exam,
            languageCode: defaults.string(forKey: "study.language") ?? ExamCatalog.languageCode,
            goalKey: defaults.string(forKey: "study.goal") ?? "improve",
            dailyMinutes: defaults.object(forKey: "study.dailyMinutes") == nil ? 20 : defaults.integer(forKey: "study.dailyMinutes"),
            diagnosticPercent: defaults.object(forKey: "study.diagnosticPercent") == nil ? 50 : defaults.integer(forKey: "study.diagnosticPercent")
        )
    }

    static func clear() {
        [
            "study.country",
            "study.exam",
            "study.language",
            "study.goal",
            "study.dailyMinutes",
            "study.diagnosticPercent"
        ].forEach(defaults.removeObject(forKey:))
    }
}
