import SwiftUI

struct RootView: View {
    @State private var setup: StudySetup?
    @State private var onboardingPaywallSeen = false

    var body: some View {
        Group {
            if let setup {
                if onboardingPaywallSeen {
                    TodayView(setup: setup)
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
                        setup = result
                    }
                }
            }
        }
        .background(ExamPalette.background)
    }
}
