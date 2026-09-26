import SwiftUI

private struct OnboardingChoice {
    let title: String
    let subtitle: String
    let symbol: String
    let accent: Color
}

struct OnboardingView: View {
    let onComplete: (StudySetup) -> Void

    @State private var step = 0
    @State private var countryIndex = ExamCatalog.suggestedCountryIndex
    @State private var examIndex: Int?
    @State private var selected: [Int: Int] = [:]

    private let totalSteps = 6

    private var country: CountryDefinition {
        ExamCatalog.countries[countryIndex]
    }

    private var exams: [ExamDefinition] {
        ExamCatalog.exams(for: country)
    }

    private var canContinue: Bool {
        switch step {
        case 0: true
        case 1: examIndex != nil
        case 2, 3, 4: selected[step] != nil
        default: true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Group {
                switch step {
                case 0:
                    countryStep
                case 1:
                    examStep
                case 2:
                    choiceStep(
                        title: "What's your goal?",
                        subtitle: "We'll tune pace, difficulty and your weekly plan.",
                        choices: goalChoices
                    )
                case 3:
                    choiceStep(
                        title: "How much time can you study daily?",
                        subtitle: "Choose something realistic. Consistency wins.",
                        choices: timeChoices
                    )
                case 4:
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
                enabled: canContinue
            ) {
                if step == totalSteps - 1, let examIndex {
                    AppServices.shared.analytics.event(
                        AnalyticsEvent.planGenerated,
                        params: [
                            AnalyticsParam.countryCode: country.code,
                            AnalyticsParam.examId: exams[examIndex].id,
                            AnalyticsParam.contentPackId: exams[examIndex].syllabusPackId,
                            AnalyticsParam.languageCode: ExamCatalog.languageCode
                        ]
                    )
                    AppServices.shared.analytics.userProperty("exam_id", value: exams[examIndex].id)
                    AppServices.shared.analytics.userProperty("country_code", value: country.code)
                    onComplete(
                        StudySetup(
                            country: country,
                            exam: exams[examIndex],
                            languageCode: ExamCatalog.languageCode
                        )
                    )
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
        .onAppear {
            AppServices.shared.analytics.event(AnalyticsEvent.onboardingStarted)
        }
        .onChange(of: step) { _, newStep in
            if newStep == 4 {
                AppServices.shared.analytics.event(
                    AnalyticsEvent.diagnosticStarted,
                    params: currentAnalyticsContext()
                )
            } else if newStep == 5 {
                AppServices.shared.analytics.event(
                    AnalyticsEvent.diagnosticCompleted,
                    params: currentAnalyticsContext()
                )
            }
        }
    }

    private func currentAnalyticsContext() -> [String: Any] {
        var params: [String: Any] = [
            AnalyticsParam.countryCode: country.code
        ]
        if let examIndex, exams.indices.contains(examIndex) {
            params[AnalyticsParam.examId] = exams[examIndex].id
            params[AnalyticsParam.contentPackId] = exams[examIndex].syllabusPackId
        }
        return params
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

    private var countryStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Where are you studying?")
                    .font(.system(size: 30, weight: .bold))
                    .padding(.top, 28)

                Text("We use your region to suggest the right exams. You can still choose international exams anywhere.")
                    .font(.system(size: 15))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .lineSpacing(3)
                    .padding(.top, 8)

                VStack(spacing: 9) {
                    ForEach(Array(ExamCatalog.countries.enumerated()), id: \.element.id) { index, item in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                countryIndex = index
                                examIndex = nil
                                AppServices.shared.analytics.event(
                                    AnalyticsEvent.countrySelected,
                                    params: [AnalyticsParam.countryCode: item.code]
                                )
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Text(item.flag).font(.system(size: 26)).frame(width: 42)
                                Text(item.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(ExamPalette.textPrimary)
                                Spacer()
                                if countryIndex == index {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(ExamPalette.primary)
                                }
                            }
                            .padding(14)
                            .background(ExamPalette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(countryIndex == index ? ExamPalette.primary : ExamPalette.border, lineWidth: countryIndex == index ? 1.5 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 22)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxHeight: .infinity)
    }

    private var examStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Which exam are you preparing for?")
                    .font(.system(size: 30, weight: .bold))
                    .padding(.top, 28)

                Text("\(country.flag) \(country.name) exams first, followed by international options.")
                    .font(.system(size: 15))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.top, 8)

                VStack(spacing: 9) {
                    ForEach(Array(exams.enumerated()), id: \.element.id) { index, exam in
                        ExamSelectionCard(
                            title: exam.shortName,
                            subtitle: exam.international ? "International · \(exam.title)" : exam.title,
                            symbol: symbol(for: exam.category),
                            accent: accent(for: exam.category),
                            selected: examIndex == index
                        ) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                examIndex = index
                                AppServices.shared.analytics.event(
                                    AnalyticsEvent.examSelected,
                                    params: [
                                        AnalyticsParam.countryCode: country.code,
                                        AnalyticsParam.examId: exam.id,
                                        AnalyticsParam.contentPackId: exam.syllabusPackId
                                    ]
                                )
                            }
                        }
                    }
                }
                .padding(.top, 22)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxHeight: .infinity)
    }

    private func choiceStep(title: String, subtitle: String, choices: [OnboardingChoice]) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                    .padding(.top, 28)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(ExamPalette.textSecondary)
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
                Text("This sample will be replaced by an exam-specific diagnostic blueprint.")
                    .font(.system(size: 15))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 14) {
                    Text("DIAGNOSTIC · SAMPLE")
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
        let exam = exams[examIndex ?? 0]

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your \(exam.shortName) week is ready.")
                    .font(.system(size: 30, weight: .bold))
                    .padding(.top, 28)
                Text("The plan uses the \(exam.syllabusPackId) content pack and adapts as you improve.")
                    .font(.system(size: 15))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.top, 8)

                VStack(spacing: 15) {
                    planRow("MON", "Core concept", "Learn + Practice", "12 min", ExamPalette.primary)
                    planRow("TUE", "Targeted practice", "Exam-style questions", "17 min", ExamPalette.mint)
                    planRow("WED", "Review", "Mistake session", "14 min", ExamPalette.amber)
                    planRow("THU", "Mini mock", "Exam blueprint", "20 min", ExamPalette.purple)
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

    private func symbol(for category: ExamCategory) -> String {
        switch category {
        case .university: "graduationcap.fill"
        case .school: "books.vertical.fill"
        case .language: "globe"
        case .professional: "briefcase.fill"
        case .international: "sparkles"
        }
    }

    private func accent(for category: ExamCategory) -> Color {
        switch category {
        case .university: ExamPalette.primary
        case .school: ExamPalette.amber
        case .language: ExamPalette.mint
        case .professional: ExamPalette.purple
        case .international: ExamPalette.indigo
        }
    }

    private var goalChoices: [OnboardingChoice] {
        [
            .init(title: "Highest possible score", subtitle: "Push for the top range", symbol: "trophy.fill", accent: ExamPalette.amber),
            .init(title: "Strong target score", subtitle: "Build competitive options", symbol: "chart.line.uptrend.xyaxis", accent: ExamPalette.primary),
            .init(title: "Improve significantly", subtitle: "Raise your current level", symbol: "scope", accent: ExamPalette.mint),
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
