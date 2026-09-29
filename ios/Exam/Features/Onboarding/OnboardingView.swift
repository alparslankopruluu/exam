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
    @State private var examDate = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    @State private var knowsExamDate = true

    private let totalSteps = 6

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: ExamCatalog.languageCode)
    }

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
                        title: copy.text("onboarding_goal_title"),
                        subtitle: copy.text("onboarding_goal_hint"),
                        choices: goalChoices
                    )
                case 3:
                    choiceStep(
                        title: copy.text("onboarding_time_title"),
                        subtitle: copy.text("onboarding_time_hint"),
                        choices: timeChoices
                    )
                case 4:
                    DiagnosticOnboardingView(exam: exams[examIndex ?? 0], copy: copy) { score in
                        selected[4] = score
                    }
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
                title: step == totalSteps - 1 ? copy.text("start_my_plan") : copy.text("continue"),
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
                    StudySetupStore.setExamDate(knowsExamDate ? examDate : nil)
                    AppServices.shared.analytics.event(
                        "exam_date_set",
                        params: ["known": knowsExamDate, "days_to_exam": StudySetupStore.daysToExam() ?? -1]
                    )
                    AppServices.shared.analytics.userProperty("exam_id", value: exams[examIndex].id)
                    AppServices.shared.analytics.userProperty("country_code", value: country.code)
                    onComplete(
                        StudySetup(
                            country: country,
                            exam: exams[examIndex],
                            languageCode: ExamCatalog.languageCode,
                            goalKey: goalKey(for: selected[2] ?? 2),
                            dailyMinutes: dailyMinutes(for: selected[3] ?? 1),
                            diagnosticPercent: selected[4] ?? 50
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
                Text(copy.text("onboarding_country_title"))
                    .font(.system(size: 30, weight: .bold))
                    .padding(.top, 28)

                Text(copy.text("onboarding_country_hint"))
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
                Text(copy.text("onboarding_exam_title"))
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

    private var planReadyStep: some View {
        let exam = exams[examIndex ?? 0]

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(copy.text("plan_ready_title", variables: ["exam": exam.shortName]))
                    .font(.system(size: 30, weight: .bold))
                    .padding(.top, 28)
                Text(copy.text("plan_ready_subtitle", variables: [
                    "level": String(selected[4] ?? 50),
                    "minutes": String(dailyMinutes(for: selected[3] ?? 1))
                ]))
                    .font(.system(size: 15))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.top, 8)

                VStack(spacing: 15) {
                    planRow(weekday(2), copy.text("plan_core_title"), copy.text("plan_core_subtitle"), copy.text("minutes_short", variables: ["count":"12"]), ExamPalette.primary)
                    planRow(weekday(3), copy.text("plan_targeted_title"), copy.text("plan_targeted_subtitle"), copy.text("minutes_short", variables: ["count":"17"]), ExamPalette.mint)
                    planRow(weekday(4), copy.text("plan_review_title"), copy.text("plan_review_subtitle"), copy.text("minutes_short", variables: ["count":"14"]), ExamPalette.amber)
                    planRow(weekday(5), copy.text("plan_mock_title"), copy.text("plan_mock_subtitle"), copy.text("minutes_short", variables: ["count":"20"]), ExamPalette.purple)
                }
                .padding(18)
                .examCard(radius: 24)
                .padding(.top, 24)

                examDateSection(exam)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxHeight: .infinity)
    }

    private func examDateSection(_ exam: ExamDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.text("exam_date_question", variables: ["exam": exam.shortName]))
                .font(.system(size: 15, weight: .semibold))

            if knowsExamDate {
                DatePicker(
                    copy.text("exam_date_label"),
                    selection: $examDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .font(.system(size: 14))
                .tint(ExamPalette.primary)
            }

            Button {
                knowsExamDate.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: knowsExamDate ? "circle" : "checkmark.circle.fill")
                        .foregroundStyle(knowsExamDate ? ExamPalette.border : ExamPalette.primary)
                    Text(copy.text("exam_date_unknown"))
                        .font(.system(size: 13))
                        .foregroundStyle(ExamPalette.textSecondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .examCard(radius: 20)
    }

    /// Short localized weekday name, 1 = Sunday ... 7 = Saturday.
    private func weekday(_ index: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: ExamCatalog.languageCode)
        return formatter.shortWeekdaySymbols[(index - 1) % 7].uppercased()
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

    private func goalKey(for index: Int) -> String {
        switch index {
        case 0: "top_score"
        case 1: "target_score"
        case 3: "pass"
        case 4: "explore"
        default: "improve"
        }
    }

    private func dailyMinutes(for index: Int) -> Int {
        switch index {
        case 0: 10
        case 2: 30
        case 3: 45
        default: 20
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


private struct DiagnosticOnboardingQuestion {
    let prompt: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

private struct DiagnosticOnboardingView: View {
    let exam: ExamDefinition
    let copy: LocalizedCopy
    let onComplete: (Int) -> Void

    @State private var index = 0
    @State private var selectedIndex: Int?
    @State private var correctCount = 0
    @State private var finished = false

    private var questions: [DiagnosticOnboardingQuestion] {
        let common = [
            DiagnosticOnboardingQuestion(
                prompt: "If 3x + 6 = 21, what is x?",
                options: ["3", "5", "7", "9"],
                correctIndex: 1,
                explanation: "Subtract 6, then divide 15 by 3."
            ),
            DiagnosticOnboardingQuestion(
                prompt: "Which value is equivalent to 3/5?",
                options: ["0.3", "0.5", "0.6", "1.5"],
                correctIndex: 2,
                explanation: "3 divided by 5 equals 0.6."
            ),
            DiagnosticOnboardingQuestion(
                prompt: "A claim is best supported by evidence that is…",
                options: ["Relevant and verifiable", "Long", "Emotional", "Repeated"],
                correctIndex: 0,
                explanation: "Strong evidence directly supports the claim and can be checked."
            ),
            DiagnosticOnboardingQuestion(
                prompt: "A quantity rises from 80 to 100. What is the percentage increase?",
                options: ["10%", "20%", "25%", "80%"],
                correctIndex: 2,
                explanation: "The increase is 20; 20/80 = 25%."
            ),
            DiagnosticOnboardingQuestion(
                prompt: "When two answers look plausible, what should you do first?",
                options: ["Guess", "Re-read the exact requirement", "Pick the longest", "Always skip"],
                correctIndex: 1,
                explanation: "Returning to the precise requirement helps eliminate distractors."
            )
        ]

        if exam.category == .language {
            return [
                .init(
                    prompt: "Choose the grammatically correct sentence.",
                    options: ["She have finished.", "She has finished.", "She finishing.", "She finish yesterday."],
                    correctIndex: 1,
                    explanation: "Present perfect uses has/have + past participle."
                ),
                .init(
                    prompt: "The word 'concise' most nearly means…",
                    options: ["brief and clear", "uncertain", "very old", "unrelated"],
                    correctIndex: 0,
                    explanation: "Concise means expressing much in few words."
                ),
                common[2],
                common[4],
                .init(
                    prompt: "Which transition signals contrast?",
                    options: ["Therefore", "However", "For example", "Similarly"],
                    correctIndex: 1,
                    explanation: "However introduces contrast."
                )
            ]
        }
        return common
    }

    var body: some View {
        let question = questions[index]

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(copy.text("diagnostic_title"))
                    .font(.system(size: 30, weight: .bold))
                    .padding(.top, 28)
                Text(copy.text("diagnostic_hint", variables: ["exam": exam.shortName]))
                    .font(.system(size: 15))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.top, 8)

                ProgressView(
                    value: Double(index + ((selectedIndex != nil || finished) ? 1 : 0)),
                    total: Double(questions.count)
                )
                .tint(ExamPalette.primary)
                .padding(.top, 18)

                VStack(alignment: .leading, spacing: 14) {
                    Text(finished ? copy.text("diagnostic_complete").uppercased() : "QUESTION \(index + 1) / \(questions.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ExamPalette.primary)

                    if finished {
                        let score = min(max(correctCount * 100 / questions.count, 0), 100)
                        Text("\(score)%")
                            .font(.system(size: 42, weight: .bold))
                        Text(
                            score >= 80
                            ? "Strong starting point. We'll begin with harder mixed practice."
                            : score >= 55
                            ? "Good base. We'll balance review with exam-style practice."
                            : "We'll rebuild the highest-impact foundations first."
                        )
                        .font(.system(size: 14))
                        .foregroundStyle(ExamPalette.textSecondary)
                    } else {
                        Text(question.prompt)
                            .font(.system(size: 18, weight: .semibold))

                        ForEach(Array(question.options.enumerated()), id: \.offset) { optionIndex, answer in
                            let chosen = selectedIndex == optionIndex
                            let correct = selectedIndex != nil && optionIndex == question.correctIndex
                            let wrong = chosen && optionIndex != question.correctIndex

                            Button {
                                guard selectedIndex == nil else { return }
                                selectedIndex = optionIndex
                                if optionIndex == question.correctIndex {
                                    correctCount += 1
                                }
                            } label: {
                                HStack {
                                    Text(String(UnicodeScalar(65 + optionIndex)!))
                                        .fontWeight(.bold)
                                        .foregroundStyle(ExamPalette.textSecondary)
                                    Text(answer)
                                        .foregroundStyle(ExamPalette.textPrimary)
                                    Spacer()
                                    if correct {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(ExamPalette.mint)
                                    } else if wrong {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(ExamPalette.coral)
                                    }
                                }
                                .padding(14)
                                .background(
                                    correct ? ExamPalette.softMint
                                    : wrong ? ExamPalette.coral.opacity(0.08)
                                    : ExamPalette.background
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .stroke(
                                            correct ? ExamPalette.mint
                                            : wrong ? ExamPalette.coral
                                            : ExamPalette.border
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        if selectedIndex != nil {
                            Text(question.explanation)
                                .font(.system(size: 12))
                                .foregroundStyle(ExamPalette.textSecondary)

                            Button {
                                if index == questions.count - 1 {
                                    finished = true
                                    onComplete(min(max(correctCount * 100 / questions.count, 0), 100))
                                } else {
                                    index += 1
                                    selectedIndex = nil
                                }
                            } label: {
                                Text(index == questions.count - 1 ? copy.text("see_my_level") : copy.text("next_question"))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(ExamPalette.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
                .examCard(radius: 22)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
    }
}
