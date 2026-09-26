import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseCrashlytics

enum FirebaseBootstrap {
    static func configureIfAvailable(bundle: Bundle = .main) -> Bool {
        if FirebaseApp.app() != nil {
            return true
        }

        guard let path = bundle.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path) else {
            return false
        }

        FirebaseApp.configure(options: options)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        return true
    }

    static func ensureAnonymousSession(firebaseReady: Bool) {
        guard firebaseReady else { return }
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { _, _ in }
        }
    }
}
