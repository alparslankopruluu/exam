package com.kprl.exam.platform.remote

import com.google.firebase.remoteconfig.FirebaseRemoteConfig
import com.google.firebase.remoteconfig.FirebaseRemoteConfigSettings

data class FeatureSnapshot(
    val onboardingPaywallEnabled: Boolean = true,
    val voiceTutorEnabled: Boolean = true,
    val scanQuestionEnabled: Boolean = true,
    val imageExplanationsEnabled: Boolean = true,
    val videoExplanationsEnabled: Boolean = false,
    val freeAiMessagesPerDay: Long = 5,
    val freeMaterialsLimit: Long = 3,
    val defaultDailyGoalMinutes: Long = 20,
    val limitedOfferExpiryEpochSeconds: Long = 0
)

class RemoteFeatureFlags private constructor(
    private val remote: FirebaseRemoteConfig?
) {
    @Volatile
    var snapshot: FeatureSnapshot = FeatureSnapshot()
        private set

    fun refresh(onComplete: (() -> Unit)? = null) {
        val client = remote
        if (client == null) {
            onComplete?.invoke()
            return
        }

        client.fetchAndActivate().addOnCompleteListener {
            snapshot = FeatureSnapshot(
                onboardingPaywallEnabled = client.getBoolean("onboarding_paywall_enabled"),
                voiceTutorEnabled = client.getBoolean("voice_tutor_enabled"),
                scanQuestionEnabled = client.getBoolean("scan_question_enabled"),
                imageExplanationsEnabled = client.getBoolean("image_explanations_enabled"),
                videoExplanationsEnabled = client.getBoolean("video_explanations_enabled"),
                freeAiMessagesPerDay = client.getLong("free_ai_messages_per_day"),
                freeMaterialsLimit = client.getLong("free_materials_limit"),
                defaultDailyGoalMinutes = client.getLong("default_daily_goal_minutes"),
                limitedOfferExpiryEpochSeconds = client.getLong("limited_offer_expiry_epoch_seconds")
            )
            onComplete?.invoke()
        }
    }

    companion object {
        fun create(firebaseReady: Boolean): RemoteFeatureFlags {
            if (!firebaseReady) return RemoteFeatureFlags(null)

            val client = runCatching { FirebaseRemoteConfig.getInstance() }.getOrNull()
                ?: return RemoteFeatureFlags(null)

            client.setConfigSettingsAsync(
                FirebaseRemoteConfigSettings.Builder()
                    .setMinimumFetchIntervalInSeconds(3600)
                    .build()
            )
            client.setDefaultsAsync(
                mapOf(
                    "onboarding_paywall_enabled" to true,
                    "voice_tutor_enabled" to true,
                    "scan_question_enabled" to true,
                    "image_explanations_enabled" to true,
                    "video_explanations_enabled" to false,
                    "free_ai_messages_per_day" to 5L,
                    "free_materials_limit" to 3L,
                    "default_daily_goal_minutes" to 20L,
                    "limited_offer_expiry_epoch_seconds" to 0L
                )
            )
            return RemoteFeatureFlags(client)
        }
    }
}
