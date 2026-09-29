import Foundation

@MainActor
final class AppServices {
    static let shared = AppServices()

    private(set) var analytics: AppAnalytics = NoOpAnalytics()
    private(set) var flags = RemoteFeatureFlags()

    private init() {}

    func configure() {
        ScreenshotMode.prepare()
        let ready = FirebaseBootstrap.configureIfAvailable()
        analytics = FirebaseAppAnalytics.makeIfAvailable(firebaseReady: ready) ?? NoOpAnalytics()
        flags = RemoteFeatureFlags(firebaseReady: ready)
        flags.refresh()
        FirebaseBootstrap.ensureAnonymousSession(firebaseReady: ready)
        AuthService.shared.start()
    }
}
