import SwiftUI
import SwiftData
import UserNotifications
@preconcurrency import FirebaseMessaging

private struct ToolHeader: View {
    let title: String
    let subtitle: String?
    let onClose: () -> Void

    init(_ title: String, _ subtitle: String? = nil, onClose: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.onClose = onClose
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(ExamPalette.textPrimary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 24, weight: .bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(ExamPalette.textSecondary)
                }
            }
            Spacer()
        }
    }
}

private func generatedQuestions(from payload: [[String: Any]]) -> [StudyQuestion] {
    payload.compactMap { item in
        guard
            let prompt = item["prompt"] as? String,
            let options = item["options"] as? [String],
            let correct = item["correctIndex"] as? Int,
            options.indices.contains(correct)
        else {
            return nil
        }

        return StudyQuestion(
            id: item["id"] as? String ?? "generated_\(prompt.hashValue)",
            topic: item["topic"] as? String ?? "Practice",
            prompt: prompt,
            options: options,
            correctIndex: correct,
            explanation: item["explanation"] as? String ?? "Review the key relationship and eliminate distractors."
        )
    }
}

struct MockExamView: View {
    let setup: StudySetup
    let onClose: () -> Void
    let onStart: ([StudyQuestion]) -> Void
    var onPaywall: (String) -> Void = { _ in }

    @State private var questionCount = 10
    @State private var loading = false
    @State private var error: String?

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader(
                copy.text("mock_exam"),
                copy.text("mock_timed_set", variables: ["exam": setup.exam.shortName]),
                onClose: onClose
            )

            VStack(alignment: .leading, spacing: 12) {
                Text(copy.text("exam_simulation"))
                    .font(.system(size: 18, weight: .bold))
                Text(copy.text("mock_desc"))
                    .font(.system(size: 13))
                    .foregroundStyle(ExamPalette.textSecondary)

                HStack(spacing: 8) {
                    ForEach([10, 20, 30], id: \.self) { count in
                        Button {
                            questionCount = count
                        } label: {
                            Text(copy.text("questions_count", variables: ["count": "\(count)"]))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(questionCount == count ? .white : ExamPalette.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(questionCount == count ? ExamPalette.primary : ExamPalette.softBlue)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
            .examCard(radius: 22)
            .padding(.top, 18)

            if let error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(ExamPalette.coral)
                    .padding(.top, 10)
            }

            Spacer()

            Button {
                loading = true
                error = nil
                Task { @MainActor in
                    do {
                        let rows = try await AIGatewayClient().generatePractice(
                            setup: setup,
                            topic: "Mixed full-exam simulation across the highest-impact \(setup.exam.shortName) domains",
                            count: questionCount
                        )
                        let generated = generatedQuestions(from: rows)
                        if generated.isEmpty {
                            let fallback = SampleQuestionFactory.questions(for: setup)
                            onStart((0..<questionCount).map {
                                let source = fallback[$0 % fallback.count]
                                return StudyQuestion(
                                    id: "mock_\($0)",
                                    topic: source.topic,
                                    prompt: source.prompt,
                                    options: source.options,
                                    correctIndex: source.correctIndex,
                                    explanation: source.explanation
                                )
                            })
                        } else {
                            onStart(generated)
                        }
                    } catch {
                        let message = error.localizedDescription
                        if message.localizedCaseInsensitiveContains("Daily AI limit") {
                            onPaywall("ai_limit")
                            loading = false
                            return
                        }
                        self.error = message
                        let fallback = SampleQuestionFactory.questions(for: setup)
                        onStart((0..<questionCount).map {
                            let source = fallback[$0 % fallback.count]
                            return StudyQuestion(
                                id: "mock_\($0)",
                                topic: source.topic,
                                prompt: source.prompt,
                                options: source.options,
                                correctIndex: source.correctIndex,
                                explanation: source.explanation
                            )
                        })
                    }
                    loading = false
                }
            } label: {
                HStack {
                    if loading { ProgressView().tint(.white) }
                    else { Image(systemName: "timer") }
                    Text(loading ? copy.text("building_mock") : copy.text("start_mock"))
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(ExamPalette.primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(loading)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(ExamPalette.background.ignoresSafeArea())
    }
}

struct MistakesView: View {
    let setup: StudySetup
    let onClose: () -> Void
    let onPractice: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var mistakes: [MistakeDetail] = []

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader(copy.text("mistakes"), copy.text("mistakes_subtitle"), onClose: onClose)

            if mistakes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(ExamPalette.mint)
                    Text(copy.text("no_unresolved_mistakes"))
                        .font(.system(size: 18, weight: .bold))
                    Text(copy.text("new_mistakes_hint"))
                        .font(.system(size: 12))
                        .foregroundStyle(ExamPalette.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(22)
                .examCard(radius: 22)
                .padding(.top, 14)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 9) {
                        ForEach(mistakes) { item in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.skillId.split(separator: ":").last.map(String.init) ?? item.skillId)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(
                                    item.errorType.replacingOccurrences(of: "_", with: " ")
                                    + " · "
                                    + copy.text(
                                        "selected_answer",
                                        variables: ["answer": item.selectedAnswer ?? "—"]
                                    )
                                )
                                    .font(.system(size: 11))
                                    .foregroundStyle(ExamPalette.textSecondary)
                                if let correct = item.correctAnswer {
                                    Text(copy.text("correct_answer", variables: ["answer": correct]))
                                        .font(.system(size: 12))
                                        .foregroundStyle(ExamPalette.mint)
                                }
                                Button(copy.text("mark_resolved")) {
                                    try? LearningStore(context: modelContext).resolveMistake(id: item.id)
                                    reload()
                                }
                                .font(.system(size: 12, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .examCard(radius: 18)
                        }
                    }
                    .padding(.top, 14)
                }
            }

            Spacer()

            Button(action: onPractice) {
                Label(copy.text("practice_weak_areas"), systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(ExamPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(ExamPalette.background.ignoresSafeArea())
        .onAppear(perform: reload)
    }

    private func reload() {
        mistakes = (try? LearningStore(context: modelContext).mistakes(examId: setup.exam.id)) ?? []
    }
}

struct FlashcardsView: View {
    let setup: StudySetup
    let onClose: () -> Void

    @State private var cards: [StudyQuestion] = []
    @State private var index = 0
    @State private var revealed = false

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader(copy.text("flashcards"), copy.text("spaced_repetition"), onClose: onClose)

            if cards.isEmpty {
                Spacer()
                Text(copy.text("nothing_due"))
                    .foregroundStyle(ExamPalette.textSecondary)
                Spacer()
            } else {
                let card = cards[min(index, cards.count - 1)]

                Spacer()
                Button {
                    revealed.toggle()
                } label: {
                    VStack(spacing: 18) {
                        Text(card.topic.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ExamPalette.primary)
                        Text(revealed ? card.explanation : card.prompt)
                            .font(.system(size: revealed ? 17 : 21, weight: revealed ? .medium : .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(ExamPalette.textPrimary)
                        Text(revealed ? copy.text("rate_recall") : copy.text("tap_reveal"))
                            .font(.system(size: 12))
                            .foregroundStyle(ExamPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .padding(22)
                    .examCard(radius: 28)
                }
                .buttonStyle(.plain)

                if revealed {
                    HStack(spacing: 8) {
                        ratingButton(copy.text("again"), .again, card: card)
                        ratingButton(copy.text("hard"), .hard, card: card)
                        ratingButton(copy.text("good"), .good, card: card)
                        ratingButton(copy.text("easy"), .easy, card: card)
                    }
                    .padding(.top, 18)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .background(ExamPalette.background.ignoresSafeArea())
        .onAppear {
            let all = SampleQuestionFactory.questions(for: setup)
            let due = all.filter { FlashcardScheduler().isDue(cardId: $0.id) }
            cards = due.isEmpty ? all : due
        }
    }

    private func ratingButton(_ title: String, _ rating: FlashcardRating, card: StudyQuestion) -> some View {
        Button {
            FlashcardScheduler().review(cardId: card.id, rating: rating)
            AppServices.shared.analytics.event(
                AnalyticsEvent.flashcardReviewed,
                params: [
                    AnalyticsParam.examId: setup.exam.id,
                    AnalyticsParam.topicId: card.topic.lowercased().replacingOccurrences(of: " ", with: "_"),
                    AnalyticsParam.source: title.lowercased()
                ]
            )
            if index < cards.count - 1 {
                index += 1
                revealed = false
            } else {
                cards = []
            }
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .overlay {
                    Capsule().stroke(ExamPalette.border)
                }
        }
        .buttonStyle(.plain)
    }
}

struct CreatePracticeView: View {
    let setup: StudySetup
    let onClose: () -> Void
    let onStart: ([StudyQuestion]) -> Void
    var onPaywall: (String) -> Void = { _ in }

    @State private var topic = ""
    @State private var count = 5
    @State private var loading = false
    @State private var error: String?

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader(copy.text("create_practice"), copy.text("create_practice_hint"), onClose: onClose)

            TextField(copy.text("topic_instruction"), text: $topic, axis: .vertical)
                .lineLimit(3...6)
                .padding(14)
                .examCard(radius: 18)
                .padding(.top, 18)

            HStack(spacing: 8) {
                ForEach([5, 10, 20], id: \.self) { value in
                    Button {
                        count = value
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(count == value ? .white : ExamPalette.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(count == value ? ExamPalette.primary : ExamPalette.softBlue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)

            if let error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(ExamPalette.coral)
                    .padding(.top, 10)
            }

            Spacer()

            Button {
                loading = true
                error = nil
                Task { @MainActor in
                    do {
                        let rows = try await AIGatewayClient().generatePractice(
                            setup: setup,
                            topic: topic.isEmpty ? "Mixed \(setup.exam.shortName)" : topic,
                            count: count
                        )
                        let parsed = generatedQuestions(from: rows)
                        if parsed.isEmpty {
                            self.error = copy.text("generated_set_invalid")
                        } else {
                            onStart(parsed)
                        }
                    } catch {
                        let message = error.localizedDescription
                        if message.localizedCaseInsensitiveContains("Daily AI limit") {
                            onPaywall("ai_limit")
                        } else {
                            self.error = message
                        }
                    }
                    loading = false
                }
            } label: {
                HStack {
                    if loading { ProgressView().tint(.white) }
                    else { Image(systemName: "sparkles") }
                    Text(loading ? copy.text("generating") : copy.text("generate_practice"))
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(ExamPalette.primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(loading)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(ExamPalette.background.ignoresSafeArea())
    }
}

struct FocusView: View {
    let setup: StudySetup
    let onClose: () -> Void

    @State private var focusMinutes = 25
    @State private var remaining = 25 * 60
    @State private var running = false
    @State private var timer: Timer?

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader(
                copy.text("focus"),
                copy.text("focus_pomodoro", variables: ["exam": setup.exam.shortName]),
                onClose: onClose
            )

            HStack(spacing: 8) {
                ForEach([25, 40, 50], id: \.self) { minutes in
                    Button {
                        reset(minutes)
                    } label: {
                        Text("\(minutes) min")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(focusMinutes == minutes ? .white : ExamPalette.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(focusMinutes == minutes ? ExamPalette.primary : ExamPalette.softBlue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 28)

            Spacer()

            VStack(spacing: 6) {
                Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                Text(running ? copy.text("stay_with_it") : copy.text("ready"))
                    .foregroundStyle(ExamPalette.textSecondary)
            }
            .frame(width: 230, height: 230)
            .background(ExamPalette.surface)
            .clipShape(Circle())

            Spacer()

            Button {
                running ? pause() : start()
            } label: {
                Label(
                    running ? copy.text("pause") : copy.text("start_focus"),
                    systemImage: running ? "pause.fill" : "play.fill"
                )
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ExamPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(copy.text("reset")) { reset(focusMinutes) }
                .font(.system(size: 13, weight: .semibold))
                .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(ExamPalette.background.ignoresSafeArea())
        .onDisappear { timer?.invalidate() }
    }

    private func start() {
        AppServices.shared.analytics.event(
            AnalyticsEvent.focusStarted,
            params: [
                AnalyticsParam.examId: setup.exam.id,
                AnalyticsParam.durationSeconds: remaining
            ]
        )
        running = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if remaining > 0 {
                    remaining -= 1
                } else {
                    AppServices.shared.analytics.event(
                        AnalyticsEvent.focusCompleted,
                        params: [
                            AnalyticsParam.examId: setup.exam.id,
                            AnalyticsParam.durationSeconds: focusMinutes * 60
                        ]
                    )
                    pause()
                    let content = UNMutableNotificationContent()
                    content.title = copy.text("focus_complete")
                    content.body = copy.text("focus_break", variables: ["exam": setup.exam.shortName])
                    content.sound = .default
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request)
                }
            }
        }
    }

    private func pause() {
        running = false
        timer?.invalidate()
        timer = nil
    }

    private func reset(_ minutes: Int) {
        pause()
        focusMinutes = minutes
        remaining = minutes * 60
    }
}

struct StudyProgressView: View {
    let setup: StudySetup
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var progress = StudyProgressSummary(masteryPercent: 0, sessions: 0, questions: 0, correct: 0, studyMinutes: 0)
    @State private var errorDNA: [ErrorDNAItem] = []
    @State private var user = UserProgressStore().snapshot()

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                ToolHeader(
                    copy.text("progress"),
                    copy.text("learning_profile", variables: ["exam": setup.exam.shortName]),
                    onClose: onClose
                )

                HStack(spacing: 8) {
                    metric("\(progress.masteryPercent == 0 ? setup.diagnosticPercent : progress.masteryPercent)%", copy.text("mastery"))
                    metric("\(user.streak)", copy.text("streak"))
                    metric("\(user.xp)", copy.text("xp"))
                }

                HStack(spacing: 8) {
                    metric("\(progress.sessions)", copy.text("sessions"))
                    metric("\(progress.questions == 0 ? 0 : progress.correct * 100 / progress.questions)%", copy.text("accuracy"))
                    metric("\(progress.studyMinutes)m", copy.text("study_time"))
                }

                Text(copy.text("error_dna"))
                    .font(.system(size: 18, weight: .bold))
                    .padding(.top, 8)

                if errorDNA.isEmpty {
                    Text(copy.text("no_error_pattern"))
                        .foregroundStyle(ExamPalette.textSecondary)
                } else {
                    ForEach(Array(errorDNA.prefix(8).enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 10) {
                            Image(systemName: "chart.xyaxis.line")
                                .foregroundStyle(ExamPalette.coral)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.skillId.split(separator: ":").last.map(String.init) ?? item.skillId)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(item.errorType.replacingOccurrences(of: "_", with: " "))
                                    .font(.system(size: 11))
                                    .foregroundStyle(ExamPalette.textSecondary)
                            }
                            Spacer()
                            Text("\(item.count)×")
                                .fontWeight(.bold)
                                .foregroundStyle(ExamPalette.coral)
                        }
                        .padding(13)
                        .examCard(radius: 16)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(ExamPalette.background.ignoresSafeArea())
        .onAppear {
            let store = LearningStore(context: modelContext)
            progress = (try? store.progressSummary(examId: setup.exam.id)) ?? progress
            errorDNA = (try? store.errorDNA(examId: setup.exam.id)) ?? []
            user = UserProgressStore().snapshot()
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 19, weight: .bold))
            Text(label).font(.system(size: 10)).foregroundStyle(ExamPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .examCard(radius: 16)
    }
}

struct CreditStoreView: View {
    let setup: StudySetup
    let onClose: () -> Void

    // Display only; the backend catalog decides what a verified purchase grants.
    private static let creditAmounts = [
        StoreKitBillingService.ProductId.creditsSmall: 50,
        StoreKitBillingService.ProductId.creditsMedium: 150,
        StoreKitBillingService.ProductId.creditsLarge: 500
    ]

    @State private var packs: [CreditPackPresentation] = []
    @State private var selectedId = StoreKitBillingService.ProductId.creditsMedium
    @State private var balance: Int?
    @State private var loading = false
    @State private var message: String?

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader(copy.text("ai_credits"), copy.text("credits_subtitle"), onClose: onClose)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(copy.text("credits_balance", variables: ["count": balance.map(String.init) ?? "—"]))
                            .font(.system(size: 26, weight: .bold))
                        Text(copy.text("credits_desc"))
                            .font(.system(size: 13))
                            .foregroundStyle(ExamPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .examCard(radius: 24)

                    if packs.isEmpty {
                        Text(copy.text("loading_price"))
                            .font(.system(size: 13))
                            .foregroundStyle(ExamPalette.textSecondary)
                            .padding(.top, 8)
                    }

                    ForEach(packs) { pack in
                        packCard(pack)
                    }

                    if let message {
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundStyle(ExamPalette.textSecondary)
                    }
                }
                .padding(.top, 20)
            }

            ExamPrimaryButton(
                title: loading ? copy.text("processing") : copy.text("buy_credits"),
                enabled: !loading && packs.contains { $0.productId == selectedId }
            ) {
                buy(selectedId)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(ExamPalette.background.ignoresSafeArea())
        .task {
            AppServices.shared.analytics.event(
                AnalyticsEvent.creditStoreViewed,
                params: [AnalyticsParam.examId: setup.exam.id]
            )
            packs = await StoreKitBillingService.shared.loadCreditPacks()
            balance = await EntitlementService().fetch().credits
        }
    }

    private func packCard(_ pack: CreditPackPresentation) -> some View {
        let selected = pack.productId == selectedId
        let popular = pack.productId == StoreKitBillingService.ProductId.creditsMedium
        return Button {
            selectedId = pack.productId
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "diamond.fill")
                    .foregroundStyle(ExamPalette.purple)
                    .frame(width: 40, height: 40)
                    .background(ExamPalette.softPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(copy.text("credits_pack", variables: ["count": String(Self.creditAmounts[pack.productId] ?? 0)]))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(ExamPalette.textPrimary)
                        if popular {
                            Text(copy.text("most_popular"))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(ExamPalette.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(ExamPalette.softBlue)
                                .clipShape(Capsule())
                        }
                    }
                }
                Spacer()
                Text(pack.localizedPrice)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ExamPalette.textPrimary)
            }
            .padding(14)
            .background(ExamPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? ExamPalette.primary : ExamPalette.border, lineWidth: selected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func buy(_ productId: String) {
        loading = true
        message = nil
        AppServices.shared.analytics.event(
            AnalyticsEvent.creditPurchaseStarted,
            params: [AnalyticsParam.examId: setup.exam.id, AnalyticsParam.productId: productId]
        )
        Task { @MainActor in
            let success = await StoreKitBillingService.shared.purchase(productId: productId)
            message = success ? copy.text("credits_added") : copy.text("purchase_not_completed")
            AppServices.shared.analytics.event(
                success ? AnalyticsEvent.creditPurchaseCompleted : AnalyticsEvent.purchaseFailed,
                params: success
                    ? [AnalyticsParam.examId: setup.exam.id, AnalyticsParam.productId: productId]
                    : [AnalyticsParam.placement: "credit_store", AnalyticsParam.productId: productId]
            )
            if success {
                balance = await EntitlementService().fetch().credits
            }
            loading = false
        }
    }
}

struct ProfileSettingsView: View {
    let setup: StudySetup
    let onClose: () -> Void
    let onSetupChanged: (StudySetup) -> Void
    let onProgress: () -> Void
    let onCredits: () -> Void
    let onRestartOnboarding: () -> Void

    @State private var reminderHour = UserProgressStore().snapshot().reminderHour
    @State private var confirmDelete = false
    @State private var deletingAccount = false
    @State private var deleteError: String?
    @State private var showAccount = false
    @State private var examDate = StudySetupStore.examDate()
    @ObservedObject private var auth = AuthService.shared

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    private let languages = AppLanguage.supported.map { ($0.code, $0.name) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ToolHeader(copy.text("profile_settings"), setup.exam.shortName, onClose: onClose)

                settingsRow(
                    auth.account.isAnonymous ? "person.crop.circle.badge.plus" : "person.crop.circle.badge.checkmark",
                    copy.text(auth.account.isAnonymous ? "account_save_progress" : "account_title_linked"),
                    auth.account.isAnonymous ? copy.text("account_save_progress_hint") : (auth.account.email ?? "")
                ) {
                    showAccount = true
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.text("exam_date_label"))
                        .font(.system(size: 14, weight: .semibold))
                    if let date = examDate {
                        HStack {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { date },
                                    set: { value in
                                        examDate = value
                                        StudySetupStore.setExamDate(value)
                                    }
                                ),
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .tint(ExamPalette.primary)
                            Spacer()
                            Button(copy.text("exam_date_clear")) {
                                examDate = nil
                                StudySetupStore.setExamDate(nil)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ExamPalette.textSecondary)
                        }
                    } else {
                        Button(copy.text("exam_date_add")) {
                            let date = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
                            examDate = date
                            StudySetupStore.setExamDate(date)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ExamPalette.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .examCard(radius: 18)

                settingsRow("chart.xyaxis.line", copy.text("progress"), copy.text("progress_hint"), action: onProgress)
                settingsRow("diamond.fill", copy.text("ai_credits"), copy.text("credits_hint"), action: onCredits)

                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.text("app_language")).font(.system(size: 14, weight: .semibold))
                    Picker("Language", selection: Binding(
                        get: { setup.languageCode },
                        set: { code in
                            let updated = StudySetup(
                                country: setup.country,
                                exam: setup.exam,
                                languageCode: code,
                                goalKey: setup.goalKey,
                                dailyMinutes: setup.dailyMinutes,
                                diagnosticPercent: setup.diagnosticPercent
                            )
                            StudySetupStore.save(updated)
                            onSetupChanged(updated)
                        }
                    )) {
                        ForEach(languages, id: \.0) { code, label in
                            Text(label).tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .examCard(radius: 18)

                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.text("daily_reminder")).font(.system(size: 14, weight: .semibold))
                    Text(copy.text("local_time", variables: ["hour": "\(reminderHour)"]))
                        .font(.system(size: 12))
                        .foregroundStyle(ExamPalette.textSecondary)

                    Slider(
                        value: Binding(
                            get: { Double(reminderHour) },
                            set: { reminderHour = Int($0).clamped(to: 6...23) }
                        ),
                        in: 6...23,
                        step: 1
                    )
                    .onChange(of: reminderHour) { _, value in
                        UserProgressStore().setReminderHour(value)
                        AppServices.shared.analytics.event(
                            AnalyticsEvent.reminderChanged,
                            params: [
                                AnalyticsParam.examId: setup.exam.id,
                                AnalyticsParam.reminderHour: value
                            ]
                        )
                        Messaging.messaging().token { token, _ in
                            guard let token else { return }
                            Task { @MainActor in
                                PushTokenRegistrar.register(
                                    token: token,
                                    examId: setup.exam.id,
                                    examName: setup.exam.shortName,
                                    localReminderHour: value
                                )
                            }
                        }
                    }
                }
                .padding(14)
                .examCard(radius: 18)

                settingsRow("arrow.clockwise", copy.text("restore_purchases"), copy.text("restore_hint")) {
                    Task { @MainActor in
                        await StoreKitBillingService.shared.restore()
                    }
                }

                settingsRow("arrow.counterclockwise", copy.text("choose_another_exam"), copy.text("choose_exam_hint"), action: onRestartOnboarding)

                settingsRow("trash.fill", copy.text("delete_account"), copy.text("delete_account_hint")) {
                    confirmDelete = true
                }

                if let deleteError {
                    Text(deleteError)
                        .font(.system(size: 12))
                        .foregroundStyle(ExamPalette.coral)
                }

                Text(copy.text("privacy_note"))
                    .font(.system(size: 11))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.vertical, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(ExamPalette.background.ignoresSafeArea())
        .sheet(isPresented: $showAccount) {
            AccountView(copy: copy) { showAccount = false }
        }
        .alert(copy.text("delete_confirm_title"), isPresented: $confirmDelete) {
            Button(copy.text("cancel"), role: .cancel) {}
            Button(copy.text("delete_permanently"), role: .destructive) {
                deletingAccount = true
                deleteError = nil
                Task { @MainActor in
                    do {
                        try await AccountService().deleteAccount()
                        AppServices.shared.analytics.event(
                            AnalyticsEvent.accountDeleted,
                            params: [AnalyticsParam.examId: setup.exam.id]
                        )
                        StudySetupStore.clear()
                        UserProgressStore().reset()
                        onRestartOnboarding()
                    } catch {
                        deleteError = error.localizedDescription
                    }
                    deletingAccount = false
                }
            }
            .disabled(deletingAccount)
        } message: {
            Text(copy.text("delete_confirm_body"))
        }
    }

    private func settingsRow(
        _ symbol: String,
        _ title: String,
        _ subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ExamIconBadge(symbol: symbol, accent: ExamPalette.primary, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ExamPalette.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(ExamPalette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(ExamPalette.textSecondary)
            }
            .padding(14)
            .examCard(radius: 18)
        }
        .buttonStyle(.plain)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}


struct MediaLabView: View {
    let setup: StudySetup
    let onClose: () -> Void
    let onNeedCredits: () -> Void

    @State private var prompt = ""
    @State private var status: String?
    @State private var assetURL: URL?
    @State private var error: String?
    @State private var submitting = false
    @State private var generatedKind = "image_explainer"

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader(
                copy.text("visual_explanation"),
                copy.text("visual_media_subtitle", variables: ["exam": setup.exam.shortName]),
                onClose: onClose
            )

            TextField(
                copy.text("visual_prompt_label"),
                text: $prompt,
                axis: .vertical
            )
            .lineLimit(4...7)
            .padding(14)
            .examCard(radius: 18)
            .padding(.top, 18)

            HStack(spacing: 9) {
                mediaButton(
                    title: copy.text("image_credit"),
                    symbol: "photo.fill",
                    kind: "image_explainer",
                    enabled: AppServices.shared.flags.snapshot.imageExplanationsEnabled
                )
                mediaButton(
                    title: copy.text("video_credit"),
                    symbol: "film.fill",
                    kind: "video_explainer",
                    enabled: AppServices.shared.flags.snapshot.videoExplanationsEnabled
                )
            }
            .padding(.top, 12)

            if let status {
                HStack(spacing: 10) {
                    if assetURL == nil {
                        ProgressView()
                    }
                    Text(status.replacingOccurrences(of: "_", with: " "))
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                }
                .padding(13)
                .examCard(radius: 16)
                .padding(.top, 14)
            }

            if let error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(ExamPalette.coral)
                    .padding(.top, 10)
            }

            if let assetURL {
                VStack(alignment: .leading, spacing: 10) {
                    if generatedKind == "image_explainer" {
                        AsyncImage(url: assetURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            case .failure:
                                EmptyView()
                            default:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 120)
                            }
                        }
                    }

                    Label(copy.text("media_ready"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(ExamPalette.mint)

                    Link(destination: assetURL) {
                        Text(copy.text("open_generated_asset"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(ExamPalette.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                }
                .padding(16)
                .examCard(radius: 20)
                .padding(.top, 18)
            }

            Spacer()

            Text(copy.text("media_cost_note"))
                .font(.system(size: 11))
                .foregroundStyle(ExamPalette.textSecondary)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .background(ExamPalette.background.ignoresSafeArea())
    }

    private func mediaButton(
        title: String,
        symbol: String,
        kind: String,
        enabled: Bool
    ) -> some View {
        Button {
            submit(kind: kind)
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(kind == "video_explainer" ? ExamPalette.purple : ExamPalette.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submitting || !enabled)
        .opacity(enabled ? 1 : 0.45)
    }

    private func submit(kind: String) {
        let value = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !submitting else { return }

        submitting = true
        generatedKind = kind
        assetURL = nil
        error = nil
        status = "submitting"
        AppServices.shared.analytics.event(
            AnalyticsEvent.mediaRequested,
            params: [
                AnalyticsParam.examId: setup.exam.id,
                AnalyticsParam.mediaKind: kind,
                AnalyticsParam.creditCost: kind == "video_explainer" ? 5 : 1
            ]
        )

        Task { @MainActor in
            do {
                let job = try await AIGatewayClient().generateMedia(kind: kind, prompt: value)
                status = "queued · \(job.creditCost) credits"

                for _ in 0..<120 {
                    try? await Task.sleep(for: .seconds(2))
                    let update = try await AIGatewayClient().mediaStatus(requestId: job.requestId)
                    status = update.status
                    if let url = update.assetURL {
                        assetURL = url
                        AppServices.shared.analytics.event(
                            AnalyticsEvent.mediaCompleted,
                            params: [
                                AnalyticsParam.examId: setup.exam.id,
                                AnalyticsParam.mediaKind: kind
                            ]
                        )
                        break
                    }
                    if update.status == "completed" {
                        AppServices.shared.analytics.event(
                            AnalyticsEvent.mediaCompleted,
                            params: [
                                AnalyticsParam.examId: setup.exam.id,
                                AnalyticsParam.mediaKind: kind
                            ]
                        )
                        break
                    }
                }
            } catch {
                self.error = error.localizedDescription
                if error.localizedDescription.localizedCaseInsensitiveContains("credit") {
                    onNeedCredits()
                }
            }
            submitting = false
        }
    }
}
