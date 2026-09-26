import SwiftUI

struct RootView: View {
    @State private var setup: StudySetup?

    var body: some View {
        Group {
            if let setup {
                TodayView(setup: setup)
                    .transition(.opacity.combined(with: .scale(scale: 0.99)))
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
