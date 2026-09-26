package com.kprl.exam.ui

import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import com.kprl.exam.data.StudySetup
import com.kprl.exam.ui.home.TodayScreen
import com.kprl.exam.ui.onboarding.OnboardingScreen
import com.kprl.exam.ui.paywall.PremiumPaywallScreen
import com.kprl.exam.ui.theme.ExamTheme

@Composable
fun ExamApp() {
    ExamTheme {
        var setup by remember { mutableStateOf<StudySetup?>(null) }
        var onboardingPaywallSeen by rememberSaveable { mutableStateOf(false) }

        when {
            setup == null -> {
                OnboardingScreen { result ->
                    setup = result
                }
            }

            !onboardingPaywallSeen -> {
                PremiumPaywallScreen(
                    setup = setup!!,
                    placement = "onboarding",
                    onClose = { onboardingPaywallSeen = true }
                )
            }

            else -> TodayScreen(setup = setup!!)
        }
    }
}
