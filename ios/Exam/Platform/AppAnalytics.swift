import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

protocol AppAnalytics {
    func event(_ name: String, params: [String: Any])
    func userProperty(_ name: String, value: String?)
    func nonFatal(_ error: Error, context: [String: String])
}

extension AppAnalytics {
    func event(_ name: String) {
        event(name, params: [:])
    }
}

final class NoOpAnalytics: AppAnalytics {
    func event(_ name: String, params: [String: Any]) {}
    func userProperty(_ name: String, value: String?) {}
    func nonFatal(_ error: Error, context: [String: String]) {}
}

final class FirebaseAppAnalytics: AppAnalytics {
    func event(_ name: String, params: [String: Any]) {
        Analytics.logEvent(name, parameters: params)
    }

    func userProperty(_ name: String, value: String?) {
        Analytics.setUserProperty(value, forName: name)
    }

    func nonFatal(_ error: Error, context: [String: String]) {
        for (key, value) in context {
            Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        }
        Crashlytics.crashlytics().record(error: error)
    }

    static func makeIfAvailable(firebaseReady: Bool) -> FirebaseAppAnalytics? {
        firebaseReady ? FirebaseAppAnalytics() : nil
    }
}
