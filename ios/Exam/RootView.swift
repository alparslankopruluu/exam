import SwiftUI
@preconcurrency import FirebaseMessaging

struct RootView: View {
    @State private var setup: StudySetup? = StudySetupStore.load()
    @State private var onboardingPaywallSeen = StudySetupStore.onboardingPaywallSeen()
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
        .background(ExamPalette.background)
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
