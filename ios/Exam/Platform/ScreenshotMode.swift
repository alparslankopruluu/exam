import Foundation

/// Debug-only state seeding for store screenshots, driven by launch arguments:
///   xcrun simctl launch <device> com.techtactoe.examly \
///     -screenshotLanguage tr -screenshotExam tr_yks -screenshotScreen today
/// Screens: today, practice, tutor, library, session, paywall, credits.
enum ScreenshotMode {
    #if DEBUG
    static var language: String? { UserDefaults.standard.string(forKey: "screenshotLanguage") }
    static var isActive: Bool { language != nil }
    static var screen: String { UserDefaults.standard.string(forKey: "screenshotScreen") ?? "today" }

    @MainActor
    static func prepare() {
        guard let language,
              let exam = ExamCatalog.exam(id: UserDefaults.standard.string(forKey: "screenshotExam") ?? "intl_ielts"),
              let country = ExamCatalog.country(code: exam.countryCode ?? "OTHER") else { return }

        StudySetupStore.save(StudySetup(
            country: country,
            exam: exam,
            languageCode: language,
            goalKey: "target_score",
            dailyMinutes: 30,
            diagnosticPercent: 64
        ))
        StudySetupStore.setOnboardingPaywallSeen(true)
        StudySetupStore.setNotificationPrompted(true)
        StudySetupStore.setExamDate(Calendar.current.date(byAdding: .day, value: 47, to: .now))

        let defaults = UserDefaults.standard
        defaults.set(12, forKey: "progress.streak")
        defaults.set(1840, forKey: "progress.xp")
        defaults.set(38, forKey: "progress.sessions")
        defaults.set(412, forKey: "progress.questions")
        defaults.set(Calendar.current.startOfDay(for: .now), forKey: "progress.lastStudyDay")
    }
    #else
    static let isActive = false
    static let screen = "today"
    static func prepare() {}
    #endif
}
