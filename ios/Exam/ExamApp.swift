import SwiftUI

@main
struct ExamApp: App {
    @UIApplicationDelegateAdaptor(ExamAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
