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
    @State private var diagnostic: DiagnosticResult?

    private let totalSteps = 9
    /// Steps: 0 country, 1 exam, 2 goal, 3 exam date, 4 daily time, 5 diagnostic,
    /// 6 analysis (auto-advances), 7 Study DNA, 8 first-week plan.
    private enum Step {
        static let goal = 2, examDate = 3, time = 4, diagnostic = 5, analysis = 6, dna = 7, plan = 8
    }

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
        case Step.goal, Step.time: selected[step] != nil
        case Step.diagnostic: diagnostic != nil
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
                case Step.examDate:
                    examDateStep
                case Step.time:
                    choiceStep(
                        title: copy.text("onboarding_time_title"),
                        subtitle: copy.text("onboarding_time_hint"),
                        choices: timeChoices
                    )
                case Step.diagnostic:
                    DiagnosticOnboardingView(exam: exams[examIndex ?? 0], copy: copy) { result in
                        diagnostic = result
                    }
                case Step.analysis:
                    AnalysisStepView(copy: copy) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { step = Step.dna }
                    }
                case Step.dna:
                    StudyDNAStepView(dna: StudyDNA(diagnostic ?? .empty), copy: copy)
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
                            dailyMinutes: dailyMinutes(for: selected[Step.time] ?? 1),
                            diagnosticPercent: diagnostic?.percent ?? 50
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
            // The analysis step advances on its own once the animation finishes.
            .opacity(step == Step.analysis ? 0 : 1)
            .disabled(step == Step.analysis)
        }
        .background(ExamPalette.background.ignoresSafeArea())
        .onAppear {
            AppServices.shared.analytics.event(AnalyticsEvent.onboardingStarted)
            seedForScreenshot()
        }
        .onChange(of: step) { _, newStep in
            if newStep == Step.diagnostic {
                AppServices.shared.analytics.event(
                    AnalyticsEvent.diagnosticStarted,
                    params: currentAnalyticsContext()
                )
            } else if newStep == Step.analysis {
                AppServices.shared.analytics.event(
                    AnalyticsEvent.diagnosticCompleted,
                    params: currentAnalyticsContext()
                )
            }
        }
    }

    /// Store screenshots jump straight to a later step with a plausible learner.
    private func seedForScreenshot() {
        guard ScreenshotMode.isActive, ScreenshotMode.screen.hasPrefix("onboarding_") else { return }
        let target = UserDefaults.standard.string(forKey: "screenshotExam")
        if let countryIndex = ExamCatalog.countries.firstIndex(where: { country in
            ExamCatalog.exams(for: country).contains { $0.id == target }
        }) {
            self.countryIndex = countryIndex
            examIndex = ExamCatalog.exams(for: ExamCatalog.countries[countryIndex]).firstIndex { $0.id == target }
        }
        selected[Step.goal] = 1
        selected[Step.time] = 1
        examDate = Calendar.current.date(byAdding: .day, value: 60, to: .now) ?? .now
        diagnostic = DiagnosticResult(answers: [
            .init(dimension: .application, correct: true, responseMs: 14_000),
            .init(dimension: .concepts, correct: true, responseMs: 11_000),
            .init(dimension: .concepts, correct: true, responseMs: 18_000),
            .init(dimension: .application, correct: false, responseMs: 26_000),
            .init(dimension: .strategy, correct: true, responseMs: 16_000)
        ])
        switch ScreenshotMode.screen {
        case "onboarding_date": step = Step.examDate
        case "onboarding_analysis": step = Step.analysis
        case "onboarding_dna": step = Step.dna
        default: step = Step.plan
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
                                Text(item.localizedName)
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

                Text(copy.text("onboarding_exam_hint", variables: ["country": "\(country.flag) \(country.localizedName)"]))
                    .font(.system(size: 15))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.top, 8)

                VStack(spacing: 9) {
                    ForEach(Array(exams.enumerated()), id: \.element.id) { index, exam in
                        ExamSelectionCard(
                            title: exam.shortName,
                            subtitle: exam.international ? copy.text("international_prefix", variables: ["title": exam.title]) : exam.title,
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
        let minutes = dailyMinutes(for: selected[Step.time] ?? 1)

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Image("calendar")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                Text(copy.text("first_week_title"))
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                Text(copy.text("first_week_subtitle", variables: ["exam": exam.shortName, "minutes": String(minutes)]))
                    .font(.system(size: 15))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)

                HStack(spacing: 8) {
                    ForEach(1...4, id: \.self) { week in
                        Text(week == 1 ? copy.text("week_n", variables: ["n": "1"]) : "\(week)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(week == 1 ? ExamPalette.primary : ExamPalette.textSecondary.opacity(0.6))
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(week == 1 ? ExamPalette.softBlue : .clear)
                            .clipShape(Capsule())
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 18)

                VStack(spacing: 10) {
                    planRow(weekday(2), "book.fill", copy.text("plan_core_title"), copy.text("tasks_minutes", variables: ["tasks": "3", "minutes": String(minutes)]), ExamPalette.primary)
                    planRow(weekday(3), "target", copy.text("plan_targeted_title"), copy.text("tasks_minutes", variables: ["tasks": "3", "minutes": String(minutes)]), ExamPalette.amber)
                    planRow(weekday(4), "arrow.triangle.2.circlepath", copy.text("plan_review_title"), copy.text("tasks_minutes", variables: ["tasks": "2", "minutes": String(minutes)]), ExamPalette.mint)
                    planRow(weekday(5), "timer", copy.text("plan_mock_title"), copy.text("tasks_minutes", variables: ["tasks": "1", "minutes": String(max(minutes, 20))]), ExamPalette.purple)
                    planRow(weekday(6), "chart.bar.fill", copy.text("plan_analyze_title"), copy.text("tasks_minutes", variables: ["tasks": "2", "minutes": String(minutes)]), ExamPalette.coral)
                }
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxHeight: .infinity)
    }

    private var examDateStep: some View {
        let exam = exams[examIndex ?? 0]
        let days = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: examDate)).day ?? 0)

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(copy.text("exam_date_question", variables: ["exam": exam.shortName]))
                    .font(.system(size: 30, weight: .bold))
                    .padding(.top, 28)

                examDateSection(exam)
                    .padding(.top, 20)

                ZStack {
                    Circle()
                        .fill(ExamPalette.softBlue)
                        .frame(width: 150, height: 150)
                    Circle()
                        .trim(from: 0, to: knowsExamDate ? min(1, Double(days) / 365) : 0)
                        .stroke(ExamPalette.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 162, height: 162)
                    VStack(spacing: 0) {
                        Text(knowsExamDate ? "\(days)" : "–")
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundStyle(ExamPalette.textPrimary)
                            .contentTransition(.numericText())
                        Text(copy.text("days_left"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ExamPalette.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: days)

                Image("calendar")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                Text(copy.text(days < 30 && knowsExamDate ? "exam_date_soon" : "exam_date_encourage"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxHeight: .infinity)
    }

    private func examDateSection(_ exam: ExamDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
        return formatter.shortWeekdaySymbols[(index - 1) % 7]
    }

    private func planRow(_ day: String, _ symbol: String, _ title: String, _ detail: String, _ accent: Color) -> some View {
        HStack(spacing: 12) {
            Text(day)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ExamPalette.textSecondary)
                .frame(width: 38, alignment: .leading)
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ExamPalette.textPrimary)
                        .lineLimit(1)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(ExamPalette.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .examCard(radius: 16)
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
            .init(title: copy.text("goal_top_title"), subtitle: copy.text("goal_top_hint"), symbol: "trophy.fill", accent: ExamPalette.amber),
            .init(title: copy.text("goal_target_title"), subtitle: copy.text("goal_target_hint"), symbol: "chart.line.uptrend.xyaxis", accent: ExamPalette.primary),
            .init(title: copy.text("goal_improve_title"), subtitle: copy.text("goal_improve_hint"), symbol: "scope", accent: ExamPalette.mint),
            .init(title: copy.text("goal_pass_title"), subtitle: copy.text("goal_pass_hint"), symbol: "checkmark.circle.fill", accent: ExamPalette.purple),
            .init(title: copy.text("goal_unsure_title"), subtitle: copy.text("goal_unsure_hint"), symbol: "safari.fill", accent: ExamPalette.indigo)
        ]
    }

    private var timeChoices: [OnboardingChoice] {
        [
            .init(title: copy.text("minutes_short", variables: ["count": "10"]), subtitle: copy.text("time_quick"), symbol: "bolt.fill", accent: ExamPalette.mint),
            .init(title: copy.text("minutes_short", variables: ["count": "20"]), subtitle: copy.text("time_recommended"), symbol: "timer", accent: ExamPalette.primary),
            .init(title: copy.text("minutes_short", variables: ["count": "30"]), subtitle: copy.text("time_serious"), symbol: "flame.fill", accent: ExamPalette.amber),
            .init(title: copy.text("minutes_short", variables: ["count": "45+"]), subtitle: copy.text("time_intensive"), symbol: "rocket.fill", accent: ExamPalette.purple)
        ]
    }
}


/// What a diagnostic question measures; feeds the Study DNA profile.
enum DiagnosticDimension: CaseIterable {
    case concepts, application, strategy
}

private struct DiagnosticOnboardingQuestion {
    let prompt: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
    let dimension: DiagnosticDimension
}

/// Per-question outcome of the onboarding diagnostic.
struct DiagnosticResult: Hashable {
    struct Answer: Hashable {
        let dimension: DiagnosticDimension
        let correct: Bool
        let responseMs: Int
    }

    let answers: [Answer]

    static let empty = DiagnosticResult(answers: [])

    var percent: Int {
        answers.isEmpty ? 50 : answers.filter(\.correct).count * 100 / answers.count
    }
}

/// The five-axis starting profile shown after the diagnostic. Each axis is scaled into
/// 40–95 so a 5-question test reads as a starting point, not a verdict.
struct StudyDNA {
    enum Axis: CaseIterable {
        case concepts, application, speed, accuracy, strategy

        var key: String {
            switch self {
            case .concepts: "dna_concepts"
            case .application: "dna_application"
            case .speed: "dna_speed"
            case .accuracy: "dna_accuracy"
            case .strategy: "dna_strategy"
            }
        }

        var archetypeKey: String {
            switch self {
            case .concepts: "dna_type_concepts"
            case .application: "dna_type_application"
            case .speed: "dna_type_speed"
            case .accuracy: "dna_type_accuracy"
            case .strategy: "dna_type_strategy"
            }
        }
    }

    let values: [Axis: Int]

    init(_ result: DiagnosticResult) {
        func scaled(_ fraction: Double) -> Int { Int((40 + 55 * fraction).rounded()) }
        func fraction(_ dimension: DiagnosticDimension) -> Double {
            let items = result.answers.filter { $0.dimension == dimension }
            return items.isEmpty ? 0.5 : Double(items.filter(\.correct).count) / Double(items.count)
        }
        let averageMs = result.answers.isEmpty ? 25_000 : result.answers.map(\.responseMs).reduce(0, +) / result.answers.count
        let speed = min(1, max(0, Double(40_000 - averageMs) / 32_000))
        values = [
            .concepts: scaled(fraction(.concepts)),
            .application: scaled(fraction(.application)),
            .speed: scaled(speed),
            .accuracy: scaled(Double(result.percent) / 100),
            .strategy: scaled(fraction(.strategy))
        ]
    }

    /// The strongest axis names the learner's profile ("Concept Builder", ...).
    var archetype: Axis {
        Axis.allCases.max { (values[$0] ?? 0) < (values[$1] ?? 0) } ?? .concepts
    }

    /// The weakest axis is where the first week starts.
    var focus: Axis {
        Axis.allCases.min { (values[$0] ?? 0) < (values[$1] ?? 0) } ?? .speed
    }
}

private struct DiagnosticOnboardingView: View {
    let exam: ExamDefinition
    let copy: LocalizedCopy
    let onComplete: (DiagnosticResult) -> Void

    @State private var index = 0
    @State private var selectedIndex: Int?
    @State private var answers: [DiagnosticResult.Answer] = []
    @State private var questionShownAt = Date()
    @State private var finished = false

    private var questions: [DiagnosticOnboardingQuestion] {
        func q(_ n: Int, _ options: [String], _ correct: Int, _ dimension: DiagnosticDimension) -> DiagnosticOnboardingQuestion {
            DiagnosticOnboardingQuestion(
                prompt: copy.text("diag_q\(n)"),
                options: options,
                correctIndex: correct,
                explanation: copy.text("diag_q\(n)_why"),
                dimension: dimension
            )
        }
        let common = [
            q(1, ["3", "5", "7", "9"], 1, .application),
            q(2, ["0.3", "0.5", "0.6", "1.5"].map(localizedDecimal), 2, .concepts),
            q(3, [copy.text("diag_q3_a"), copy.text("diag_q3_b"), copy.text("diag_q3_c"), copy.text("diag_q3_d")], 0, .concepts),
            q(4, ["10%", "20%", "25%", "80%"], 2, .application),
            q(5, [copy.text("diag_q5_a"), copy.text("diag_q5_b"), copy.text("diag_q5_c"), copy.text("diag_q5_d")], 1, .strategy)
        ]

        if exam.category == .language {
            // Language exams are taken in English, so their items stay in English.
            return [
                .init(
                    prompt: "Choose the grammatically correct sentence.",
                    options: ["She have finished.", "She has finished.", "She finishing.", "She finish yesterday."],
                    correctIndex: 1,
                    explanation: "Present perfect uses has/have + past participle.",
                    dimension: .concepts
                ),
                .init(
                    prompt: "The word 'concise' most nearly means…",
                    options: ["brief and clear", "uncertain", "very old", "unrelated"],
                    correctIndex: 0,
                    explanation: "Concise means expressing much in few words.",
                    dimension: .concepts
                ),
                common[2],
                common[4],
                .init(
                    prompt: "Which transition signals contrast?",
                    options: ["Therefore", "However", "For example", "Similarly"],
                    correctIndex: 1,
                    explanation: "However introduces contrast.",
                    dimension: .application
                )
            ]
        }
        return common
    }

    private func localizedDecimal(_ value: String) -> String {
        let separator = Locale(identifier: ExamCatalog.languageCode).decimalSeparator ?? "."
        return value.replacingOccurrences(of: ".", with: separator)
    }

    var body: some View {
        let question = questions[index]
        let correctCount = answers.filter(\.correct).count

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
                    Text(finished
                         ? copy.text("diagnostic_complete").uppercased()
                         : copy.text("question_n_of", variables: ["n": String(index + 1), "total": String(questions.count)]).uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ExamPalette.primary)

                    if finished {
                        let score = min(max(correctCount * 100 / questions.count, 0), 100)
                        Text("\(score)%")
                            .font(.system(size: 42, weight: .bold))
                        Text(copy.text(score >= 80 ? "diag_result_high" : score >= 55 ? "diag_result_mid" : "diag_result_low"))
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
                                answers.append(.init(
                                    dimension: question.dimension,
                                    correct: optionIndex == question.correctIndex,
                                    responseMs: Int(Date().timeIntervalSince(questionShownAt) * 1000)
                                ))
                            } label: {
                                HStack {
                                    Text(String(UnicodeScalar(65 + optionIndex)!))
                                        .fontWeight(.bold)
                                        .foregroundStyle(ExamPalette.textSecondary)
                                    Text(answer)
                                        .foregroundStyle(ExamPalette.textPrimary)
                                        .multilineTextAlignment(.leading)
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
                                .modifier(ShakeEffect(shakes: wrong ? 1 : 0))
                                .animation(.default, value: wrong)
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
                                    onComplete(DiagnosticResult(answers: answers))
                                } else {
                                    index += 1
                                    selectedIndex = nil
                                    questionShownAt = Date()
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
        .onAppear { questionShownAt = Date() }
    }
}

/// A short horizontal shake for wrong answers.
private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 6 * sin(shakes * .pi * 4), y: 0))
    }
}

/// "Analyzing your answers…": an orbiting orb and a checklist that ticks off, then advances.
private struct AnalysisStepView: View {
    let copy: LocalizedCopy
    let onFinished: () -> Void

    @State private var spin = false
    @State private var pulse = false
    @State private var done = 0

    private let items = ["analysis_strengths", "analysis_gaps", "analysis_syllabus", "analysis_dna"]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text(copy.text("analysis_title"))
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .fill(ExamPalette.softPurple)
                    .frame(width: 150, height: 150)
                    .scaleEffect(pulse ? 1.06 : 0.94)
                Circle()
                    .stroke(ExamPalette.indigo.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 200, height: 200)
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .fill(index == 0 ? ExamPalette.amber : ExamPalette.primary)
                        .frame(width: 12, height: 12)
                        .offset(x: 100)
                        .rotationEffect(.degrees((spin ? 360 : 0) + Double(index) * 160))
                }
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(colors: [ExamPalette.indigo, ExamPalette.primary], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .frame(height: 230)
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, key in
                    HStack(spacing: 10) {
                        Image(systemName: index < done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(index < done ? ExamPalette.mint : ExamPalette.border)
                            .contentTransition(.symbolEffect(.replace))
                        Text(copy.text(key))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(index < done ? ExamPalette.textPrimary : ExamPalette.textSecondary)
                    }
                }
            }
            .padding(.top, 28)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 1).repeatForever()) { pulse = true }
        }
        .task {
            for index in 1...items.count {
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { done = index }
            }
            try? await Task.sleep(for: .milliseconds(600))
            onFinished()
        }
    }
}

private struct StudyDNAStepView: View {
    let dna: StudyDNA
    let copy: LocalizedCopy

    @State private var reveal = 0.0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Text(copy.text("dna_title"))
                    .font(.system(size: 30, weight: .bold))
                    .padding(.top, 28)
                Text(copy.text("dna_subtitle"))
                    .font(.system(size: 15))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                RadarChart(
                    labels: StudyDNA.Axis.allCases.map { copy.text($0.key) },
                    values: StudyDNA.Axis.allCases.map { Double(dna.values[$0] ?? 0) / 100 },
                    reveal: reveal
                )
                .frame(height: 300)
                .padding(.top, 12)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ExamPalette.amber)
                        .frame(width: 44, height: 44)
                        .background(ExamPalette.amber.opacity(0.14))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(copy.text("dna_you_are", variables: ["type": copy.text(dna.archetype.archetypeKey)]))
                            .font(.system(size: 16, weight: .bold))
                        Text(copy.text("dna_next_focus", variables: ["axis": copy.text(dna.focus.key).lowercased()]))
                            .font(.system(size: 13))
                            .foregroundStyle(ExamPalette.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .examCard(radius: 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 1.1, dampingFraction: 0.75).delay(0.15)) { reveal = 1 }
        }
    }
}

/// A five-axis radar ("spider") chart with labelled percentages.
struct RadarChart: View {
    let labels: [String]
    let values: [Double]
    var reveal: Double

    private struct Geometry {
        let center: CGPoint
        let radius: CGFloat
        let count: Int

        init(size: CGSize, count: Int) {
            center = CGPoint(x: size.width / 2, y: size.height / 2 + 6)
            radius = min(size.width, size.height) / 2 - 46
            self.count = count
        }

        func point(_ index: Int, _ scale: Double) -> CGPoint {
            let angle: Double = -Double.pi / 2 + Double(index) * 2 * Double.pi / Double(count)
            let distance: Double = Double(radius) * scale
            return CGPoint(x: Double(center.x) + cos(angle) * distance, y: Double(center.y) + sin(angle) * distance)
        }

        func polygon(_ scales: [Double]) -> Path {
            var path = Path()
            for index in 0..<count {
                let p = point(index, scales[index])
                if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            return path
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let geometry = Geometry(size: proxy.size, count: values.count)
            ZStack {
                grid(geometry)
                shape(geometry)
                ForEach(0..<values.count, id: \.self) { index in
                    label(index, geometry)
                }
            }
        }
    }

    private func grid(_ geometry: Geometry) -> some View {
        Canvas { context, _ in
            for ring in [0.25, 0.5, 0.75, 1.0] {
                let scales = Array(repeating: ring, count: geometry.count)
                context.stroke(geometry.polygon(scales), with: .color(ExamPalette.border), lineWidth: 1)
            }
            var spokes = Path()
            for index in 0..<geometry.count {
                spokes.move(to: geometry.center)
                spokes.addLine(to: geometry.point(index, 1))
            }
            context.stroke(spokes, with: .color(ExamPalette.border), lineWidth: 1)
        }
    }

    private func shape(_ geometry: Geometry) -> some View {
        let polygon = geometry.polygon(values.map { $0 * reveal })
        let colors: [Color] = [ExamPalette.mint, ExamPalette.primary, ExamPalette.purple, ExamPalette.coral, ExamPalette.amber, ExamPalette.mint]
        return ZStack {
            polygon.fill(AngularGradient(colors: colors, center: .center).opacity(0.35))
            polygon.stroke(ExamPalette.indigo.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            ForEach(0..<values.count, id: \.self) { index in
                Circle()
                    .fill(ExamPalette.surface)
                    .overlay(Circle().stroke(ExamPalette.indigo, lineWidth: 2))
                    .frame(width: 9, height: 9)
                    .position(geometry.point(index, values[index] * reveal))
            }
        }
    }

    private func label(_ index: Int, _ geometry: Geometry) -> some View {
        let percent: Int = Int((values[index] * 100).rounded())
        return VStack(spacing: 1) {
            Text(labels[index])
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ExamPalette.textSecondary)
            Text("\(percent)%")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(ExamPalette.textPrimary)
        }
        .fixedSize()
        .position(geometry.point(index, 1.28))
    }
}
