import SwiftUI

struct RootView: View {
    @State private var setup: StudySetup? = StudySetupStore.load()
    @State private var onboardingPaywallSeen = false

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
                }
            }
        }
        .background(ExamPalette.background)
    }
}
