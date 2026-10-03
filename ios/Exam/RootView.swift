import SwiftUI
@preconcurrency import FirebaseMessaging

struct RootView: View {
    // Store screenshots of onboarding steps start without a saved setup.
    @State private var setup: StudySetup? = ScreenshotMode.screen.hasPrefix("onboarding_") ? nil : StudySetupStore.load()
    @State private var onboardingPaywallSeen = StudySetupStore.onboardingPaywallSeen()
    /// The brand splash greets first-time users before onboarding.
    @State private var showSplash = StudySetupStore.load() == nil || ScreenshotMode.screen == "splash"
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let setup {
                if onboardingPaywallSeen || !AppServices.shared.flags.snapshot.onboardingPaywallEnabled {
                    TodayView(
                        setup: setup,
                        onSetupChanged: { updated in
                            StudySetupStore.save(updated)
                            self.setup = updated
                        },
                        onRestartOnboarding: {
                            StudySetupStore.clear()
                            self.setup = nil
                            onboardingPaywallSeen = false
                            StudySetupStore.setOnboardingPaywallSeen(false)
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.99)))
                } else {
                    PremiumPaywallView(
                        setup: setup,
                        placement: "onboarding",
                        onClose: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                onboardingPaywallSeen = true
                                StudySetupStore.setOnboardingPaywallSeen(true)
                                requestStudyNotifications(for: setup)
                            }
                        }
                    )
                }
            } else {
                OnboardingView { result in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                        StudySetupStore.save(result)
                        setup = result
                    }
                    if !AppServices.shared.flags.snapshot.onboardingPaywallEnabled {
                        requestStudyNotifications(for: result)
                    }
                }
            }
        }
        .overlay {
            if showSplash {
                SplashView(languageCode: setup?.languageCode ?? ExamCatalog.languageCode)
                    .transition(.opacity)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.35)) { showSplash = false } }
                    .task {
                        guard ScreenshotMode.screen != "splash" else { return }
                        try? await Task.sleep(for: .milliseconds(1800))
                        withAnimation(.easeOut(duration: 0.5)) { showSplash = false }
                    }
            }
        }
        .background(ExamPalette.background)
        .environment(\.layoutDirection, AppLanguage.layoutDirection(for: setup?.languageCode ?? ExamCatalog.languageCode))
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let setup, StudySetupStore.notificationPrompted() else { return }
            syncStudyState(for: setup)
        }
    }

    /// Refreshes the study state the reminder scheduler relies on.
    @MainActor
    private func syncStudyState(for setup: StudySetup) {
        let due = (try? LearningStore(context: modelContext).dueSkills(examId: setup.exam.id).count) ?? 0
        Messaging.messaging().token { token, _ in
            guard let token else { return }
            Task { @MainActor in
                PushTokenRegistrar.register(
                    token: token,
                    examId: setup.exam.id,
                    examName: setup.exam.shortName,
                    dueReviews: due
                )
            }
        }
    }

    @MainActor
    private func requestStudyNotifications(for setup: StudySetup) {
        if StudySetupStore.notificationPrompted() {
            Messaging.messaging().token { token, _ in
                guard let token else { return }
                Task { @MainActor in
                    PushTokenRegistrar.register(
                        token: token,
                        examId: setup.exam.id,
                        examName: setup.exam.shortName,
                        localReminderHour: UserProgressStore().snapshot().reminderHour
                    )
                }
            }
            return
        }

        StudySetupStore.setNotificationPrompted(true)
        PushNotifications.shared.requestAuthorizationAndRegister()

        Messaging.messaging().token { token, _ in
            guard let token else { return }
            Task { @MainActor in
                PushTokenRegistrar.register(
                    token: token,
                    examId: setup.exam.id,
                    examName: setup.exam.shortName,
                    localReminderHour: UserProgressStore().snapshot().reminderHour
                )
            }
        }
    }
}

/// Brand splash: mark, wordmark, tagline and the student illustration.
private struct SplashView: View {
    let languageCode: String

    @State private var appeared = false

    private var copy: LocalizedCopy { LocalizedCopy.load(languageCode: languageCode) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.93, green: 0.94, blue: 1.0), ExamPalette.background],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 40)
                Image("app_mark")
                    .resizable()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .shadow(color: ExamPalette.indigo.opacity(0.25), radius: 14, y: 6)
                Text("Examly")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.11, green: 0.14, blue: 0.25))
                    .padding(.top, 14)
                Text(copy.text("splash_tagline"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                Spacer(minLength: 16)
                Image("hero_student")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 380)
                    .offset(y: appeared ? 0 : 24)
                    .opacity(appeared ? 1 : 0)
                Text(copy.text("splash_footer"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.vertical, 18)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) { appeared = true }
        }
    }
}

