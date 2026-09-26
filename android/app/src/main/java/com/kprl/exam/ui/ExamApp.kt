package com.kprl.exam.ui

import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import com.kprl.exam.ui.home.TodayScreen
import com.kprl.exam.ui.onboarding.OnboardingScreen
import com.kprl.exam.ui.theme.ExamTheme

@Composable
fun ExamApp() {
    ExamTheme {
        var onboardingComplete by rememberSaveable { mutableStateOf(false) }
        if (onboardingComplete) TodayScreen()
        else OnboardingScreen { onboardingComplete = true }
    }
}
