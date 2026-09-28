import SwiftUI
import SwiftData

@main
struct ExamApp: App {
    @UIApplicationDelegateAdaptor(ExamAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in _ = AuthService.shared.handleOpenURL(url) }
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
