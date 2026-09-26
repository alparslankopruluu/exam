import SwiftUI
import SwiftData

@main
struct ExamApp: App {
    @UIApplicationDelegateAdaptor(ExamAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            MasteryRecord.self,
            MistakeRecord.self,
            StudySessionRecord.self,
            MaterialRecord.self,
            DailyPlanRecord.self
        ])
    }
}
