import SwiftUI

private struct OnboardingChoice {
    let title: String
    let subtitle: String
    let symbol: String
    let accent: Color
}

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var step = 0
    @State private var selected: [Int: Int] = [:]

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            header

            Group {
                switch step {
                case 0:
                    choiceStep(
                        title: "What are you preparing for?",
                        subtitle: "Choose your exam to get a study plan built around your real goal.",
                        choices: examChoices
                    )
                case 1:
                    choiceStep(
                        title: "What's your goal?",
                        subtitle: "We'll tune pace, difficulty and your weekly plan.",
                        choices: goalChoices
                    )
                case 2:
                    choiceStep(
                        title: "How much time can you study daily?",
                        subtitle: "Choose something realistic. Consistency wins.",
                        choices: timeChoices
                    )
                case 3:
                    diagnosticStep
                default:
                    planReadyStep
                }
            }
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            ExamPrimaryButton(
                title: step == totalSteps - 1 ? "Start my plan" : "Continue",
                enabled: step == totalSteps - 1 || selected[step] != nil
            ) {
                if step == totalSteps - 1 {
                    onComplete()
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                        step += 1
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(ExamPalette.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                guard step > 0 else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                    step -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ExamPalette.textPrimary)
                    .frame(width: 38, height: 38)
                    .opacity(step > 0 ? 1 : 0)
            }
            .buttonStyle(.plain)
            .disabled(step == 0)

            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? ExamPalette.primary : ExamPalette.border)
                        .frame(height: 4)
                }
            }

            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func choiceStep(title: String, subtitle: String, choices: [OnboardingChoice]) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(ExamPalette.textPrimary)
                    .padding(.top, 28)

                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .lineSpacing(3)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                        ExamSelectionCard(
                            title: choice.title,
                            subtitle: choice.subtitle,
                            symbol: choice.symbol,
                            accent: choice.accent,
                            selected: selected[step] == index
                        ) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                selected[step] = index
                            }
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxHeight: .infinity)
    }

    private var diagnosticStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Let's find your starting point.")
                    .font(.system(size: 30, weight: .bold))
                    .padding(.top, 28)
                Text("A quick sample helps us start at the right difficulty.")
                    .font(.system(size: 15))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 14) {
                    Text("DIAGNOSTIC · 1 / 5")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ExamPalette.primary)
                    Text("f(x) = 2x + 4")
                        .font(.system(size: 22, weight: .semibold))
                    Text("If f(x) = 10, what is x?")
                        .font(.system(size: 16))

                    ForEach(Array(["2", "3", "4", "5"].enumerated()), id: \.offset) { index, answer in
                        let correct = selected[step] != nil && index == 1
                        let chosen = selected[step] == index

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                selected[step] = index
                            }
                        } label: {
                            HStack {
                                Text(String(UnicodeScalar(65 + index)!))
                                    .fontWeight(.bold)
                                    .foregroundStyle(ExamPalette.textSecondary)
                                Text(answer)
                                    .fontWeight(.medium)
                                    .foregroundStyle(ExamPalette.textPrimary)
                                Spacer()
                                if correct {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(ExamPalette.mint)
                                }
                            }
                            .padding(14)
                            .background(correct ? ExamPalette.softMint : (chosen ? ExamPalette.softBlue : ExamPalette.background))
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(correct ? ExamPalette.mint : (chosen ? ExamPalette.primary : ExamPalette.border))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if let answer = selected[step] {
                        Text(answer == 1 ? "Nice. You isolated x correctly." : "Almost. Subtract 4 first, then divide by 2.")
                            .font(.system(size: 13))
                            .foregroundStyle(ExamPalette.textSecondary)
                    }
                }
                .padding(20)
                .examCard(radius: 22)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxHeight: .infinity)
    }

    private var planReadyStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your first week is ready.")
                    .font(.system(size: 30, weight: .bold))
                    .padding(.top, 28)
                Text("A focused plan that adapts as you answer, review and improve.")
                    .font(.system(size: 15))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.top, 8)

                VStack(spacing: 15) {
                    planRow("MON", "Functions", "Learn + Practice", "12 min", ExamPalette.primary)
                    planRow("TUE", "Geometry", "Key concepts", "17 min", ExamPalette.mint)
                    planRow("WED", "Review", "Mistake session", "14 min", ExamPalette.amber)
                    planRow("THU", "Mini mock", "Mixed questions", "20 min", ExamPalette.purple)
                }
                .padding(18)
                .examCard(radius: 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxHeight: .infinity)
    }

    private func planRow(_ day: String, _ title: String, _ subtitle: String, _ time: String, _ accent: Color) -> some View {
        HStack(spacing: 12) {
            Text(day)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(ExamPalette.textSecondary)
            }
            Spacer()
            Text(time).font(.system(size: 12)).foregroundStyle(ExamPalette.textSecondary)
        }
    }

    private var examChoices: [OnboardingChoice] {
        [
            .init(title: "University entrance", subtitle: "YKS · DGS · ALES · SAT", symbol: "graduationcap.fill", accent: ExamPalette.primary),
            .init(title: "Language exam", subtitle: "IELTS · TOEFL · Cambridge", symbol: "globe", accent: ExamPalette.mint),
            .init(title: "School exams", subtitle: "Middle school · High school", symbol: "books.vertical.fill", accent: ExamPalette.amber),
            .init(title: "Professional exams", subtitle: "KPSS · certification", symbol: "briefcase.fill", accent: ExamPalette.purple),
            .init(title: "Something else", subtitle: "Build a custom plan", symbol: "sparkles", accent: ExamPalette.indigo)
        ]
    }

    private var goalChoices: [OnboardingChoice] {
        [
            .init(title: "Top 1K", subtitle: "Aim for the highest score", symbol: "trophy.fill", accent: ExamPalette.amber),
            .init(title: "Top 10K", subtitle: "Strong university options", symbol: "chart.line.uptrend.xyaxis", accent: ExamPalette.primary),
            .init(title: "Top 50K", subtitle: "Build a reliable score", symbol: "scope", accent: ExamPalette.mint),
            .init(title: "Pass comfortably", subtitle: "Study with less stress", symbol: "checkmark.circle.fill", accent: ExamPalette.purple),
            .init(title: "I don't know yet", subtitle: "We'll help you decide", symbol: "safari.fill", accent: ExamPalette.indigo)
        ]
    }

    private var timeChoices: [OnboardingChoice] {
        [
            .init(title: "10 min", subtitle: "Quick habit", symbol: "bolt.fill", accent: ExamPalette.mint),
            .init(title: "20 min", subtitle: "Recommended", symbol: "timer", accent: ExamPalette.primary),
            .init(title: "30 min", subtitle: "Serious progress", symbol: "flame.fill", accent: ExamPalette.amber),
            .init(title: "45+ min", subtitle: "Intensive", symbol: "rocket.fill", accent: ExamPalette.purple)
        ]
    }
}
