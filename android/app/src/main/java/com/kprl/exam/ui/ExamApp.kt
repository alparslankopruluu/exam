package com.kprl.exam.ui

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import com.kprl.exam.data.ExamCatalog
import com.kprl.exam.localization.AppLanguage
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessaging
import com.kprl.exam.platform.firebase.FirebaseBootstrap
import com.kprl.exam.data.StudySetup
import com.kprl.exam.platform.AppServices
import com.kprl.exam.platform.persistence.StudySetupStore
import com.kprl.exam.platform.persistence.UserProgressStore
import com.kprl.exam.platform.notifications.PushTokenRegistrar
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
        var onboardingPaywallSeen by remember {
            mutableStateOf(setupStore.isOnboardingPaywallSeen())
        }

        fun registerStudyPush(current: StudySetup) {
            if (!FirebaseBootstrap.isConfigured()) return
            FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
                PushTokenRegistrar.register(
                    context = context,
                    token = token,
                    examId = current.exam.id,
                    examName = current.exam.shortName,
                    localReminderHour = UserProgressStore(context.applicationContext)
                        .snapshot()
                        .reminderHour
                )
            }
        }

        val notificationPermissionLauncher = rememberLauncherForActivityResult(
            ActivityResultContracts.RequestPermission()
        ) { granted ->
            setup?.let { current ->
                if (granted) registerStudyPush(current)
            }
        }

        fun requestStudyNotifications(current: StudySetup) {
            if (setupStore.isNotificationPrompted()) {
                registerStudyPush(current)
                return
            }

            setupStore.setNotificationPrompted(true)
            if (
                Build.VERSION.SDK_INT >= 33 &&
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            } else {
                registerStudyPush(current)
            }
        }

        LaunchedEffect(setup?.exam?.id, onboardingPaywallSeen) {
            val current = setup ?: return@LaunchedEffect
            val valueMomentReached =
                onboardingPaywallSeen || !AppServices.flags.snapshot.onboardingPaywallEnabled
            if (valueMomentReached) requestStudyNotifications(current)
        }

        val languageCode = setup?.languageCode ?: ExamCatalog.languageCode()
        val direction = if (AppLanguage.isRightToLeft(languageCode)) LayoutDirection.Rtl else LayoutDirection.Ltr
        CompositionLocalProvider(LocalLayoutDirection provides direction) {
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
                        onClose = {
                            onboardingPaywallSeen = true
                            setupStore.setOnboardingPaywallSeen(true)
                        }
                    )
                }

                else -> TodayScreen(
                    setup = setup!!,
                    onSetupChanged = { updated ->
                        setupStore.save(updated)
                        setup = updated
                    },
                    onRestartOnboarding = {
                        setupStore.clear()
                        setup = null
                        onboardingPaywallSeen = false
                        setupStore.setOnboardingPaywallSeen(false)
                    }
                )
            }
        }
    }
}
