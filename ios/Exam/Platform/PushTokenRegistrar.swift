import Foundation
import FirebaseCore
import FirebaseFunctions

@MainActor
enum PushTokenRegistrar {
    /// Registers the device and the study state the server uses to choose
    /// which reminder (if any) to send. Safe to call on every foreground.
    static func register(
        token: String,
        examId: String? = nil,
        examName: String? = nil,
        localReminderHour: Int? = nil,
        dueReviews: Int? = nil
    ) {
        guard FirebaseApp.app() != nil else { return }

        let progressStore = UserProgressStore()
        let progress = progressStore.snapshot()
        let reminderHour = localReminderHour ?? progress.reminderHour
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let utcMinute = ((reminderHour * 60 - offsetMinutes) % 1440 + 1440) % 1440
        let bucket = utcMinute / 15

        var payload: [String: Any] = [
            "token": token,
            "platform": "ios",
            // The app language the learner chose, so reminders match the UI.
            "language": StudySetupStore.load()?.languageCode ?? AppLanguage.resolve(),
            "timeZone": TimeZone.current.identifier,
            "reminderBucket": bucket,
            "streak": progress.streak
        ]
        if let examId { payload["examId"] = examId }
        if let examName { payload["examName"] = examName }
        if let dueReviews { payload["dueReviews"] = dueReviews }
        if let lastStudyDay = progressStore.lastStudyDay() {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            payload["lastStudyDay"] = formatter.string(from: lastStudyDay)
        }

        Functions.functions()
            .httpsCallable("registerPushToken")
            .call(payload) { _, _ in }
    }
}
