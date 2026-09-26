import Foundation
import FirebaseCore
import FirebaseFunctions

@MainActor
enum PushTokenRegistrar {
    static func register(
        token: String,
        examId: String? = nil,
        examName: String? = nil,
        localReminderHour: Int = 19
    ) {
        guard FirebaseApp.app() != nil else { return }

        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let utcMinute = ((localReminderHour * 60 - offsetMinutes) % 1440 + 1440) % 1440
        let bucket = utcMinute / 15

        var payload: [String: Any] = [
            "token": token,
            "platform": "ios",
            "language": Locale.current.identifier,
            "timeZone": TimeZone.current.identifier,
            "reminderBucket": bucket
        ]
        if let examId { payload["examId"] = examId }
        if let examName { payload["examName"] = examName }

        Functions.functions()
            .httpsCallable("registerPushToken")
            .call(payload) { _, _ in }
    }
}
