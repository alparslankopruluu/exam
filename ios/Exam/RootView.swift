import SwiftUI

struct RootView: View {
    @State private var onboardingComplete = false

    var body: some View {
        Group {
            if onboardingComplete {
                TodayView()
                    .transition(.opacity.combined(with: .scale(scale: 0.99)))
            } else {
                OnboardingView {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                        onboardingComplete = true
                    }
                }
            }
        }
        .background(ExamPalette.background)
    }
}
