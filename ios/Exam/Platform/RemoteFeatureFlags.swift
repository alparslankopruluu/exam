import Foundation
import FirebaseRemoteConfig

struct FeatureSnapshot: Equatable {
    var onboardingPaywallEnabled = true
    var voiceTutorEnabled = true
    var scanQuestionEnabled = true
    var imageExplanationsEnabled = true
    var videoExplanationsEnabled = false
    var freeAiMessagesPerDay = 5
    var freeMaterialsLimit = 3
    var defaultDailyGoalMinutes = 20
    var limitedOfferExpiryEpochSeconds: Int64 = 0
}

final class RemoteFeatureFlags {
    private let remote: RemoteConfig?
    private(set) var snapshot = FeatureSnapshot()

    init(firebaseReady: Bool = false) {
        guard firebaseReady else {
            remote = nil
            return
        }

        let client = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600
        client.configSettings = settings
        client.setDefaults([
            "onboarding_paywall_enabled": true as NSObject,
            "voice_tutor_enabled": true as NSObject,
            "scan_question_enabled": true as NSObject,
            "image_explanations_enabled": true as NSObject,
            "video_explanations_enabled": false as NSObject,
            "free_ai_messages_per_day": 5 as NSObject,
            "free_materials_limit": 3 as NSObject,
            "default_daily_goal_minutes": 20 as NSObject,
            "limited_offer_expiry_epoch_seconds": 0 as NSObject
        ])
        remote = client
    }

    func refresh(completion: (() -> Void)? = nil) {
        guard let remote else {
            completion?()
            return
        }

        remote.fetchAndActivate { [weak self] _, _ in
            guard let self else {
                completion?()
                return
            }
            self.snapshot = FeatureSnapshot(
                onboardingPaywallEnabled: remote["onboarding_paywall_enabled"].boolValue,
                voiceTutorEnabled: remote["voice_tutor_enabled"].boolValue,
                scanQuestionEnabled: remote["scan_question_enabled"].boolValue,
                imageExplanationsEnabled: remote["image_explanations_enabled"].boolValue,
                videoExplanationsEnabled: remote["video_explanations_enabled"].boolValue,
                freeAiMessagesPerDay: remote["free_ai_messages_per_day"].numberValue.intValue,
                freeMaterialsLimit: remote["free_materials_limit"].numberValue.intValue,
                defaultDailyGoalMinutes: remote["default_daily_goal_minutes"].numberValue.intValue,
                limitedOfferExpiryEpochSeconds: remote["limited_offer_expiry_epoch_seconds"].numberValue.int64Value
            )
            completion?()
        }
    }
}
