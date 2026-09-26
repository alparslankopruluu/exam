package com.kprl.exam.ui

import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.platform.LocalContext
import com.kprl.exam.data.StudySetup
import com.kprl.exam.platform.AppServices
import com.kprl.exam.platform.persistence.StudySetupStore
import com.kprl.exam.ui.home.TodayScreen
import com.kprl.exam.ui.onboarding.OnboardingScreen
import com.kprl.exam.ui.paywall.PremiumPaywallScreen
import com.kprl.exam.ui.theme.ExamTheme

@Composable
fun ExamApp() {
    ExamTheme {
        val context = LocalContext.current
        val setupStore = remember { StudySetupStore(context.applicationContext) }
        var setup by remember { mutableStateOf(setupStore.load()) }
        var onboardingPaywallSeen by rememberSaveable { mutableStateOf(false) }

        when {
            setup == null -> {
                OnboardingScreen { result ->
                    setupStore.save(result)
                    setup = result
                }
            }

            !onboardingPaywallSeen && AppServices.flags.snapshot.onboardingPaywallEnabled -> {
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
