import SwiftUI
import SwiftData
import UserNotifications
import ActivityKit
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

    private enum Mode: CaseIterable { case pomodoro, deepWork }
    private enum Phase: CaseIterable { case focus, shortBreak, longBreak }

    @State private var mode: Mode = .pomodoro
    @State private var phase: Phase = .focus
    @State private var endDate: Date?
    @State private var pausedRemaining: Int?
    @State private var now = Date()

    private static let notificationId = "focus_session_end"
    @State private var activity: Activity<FocusActivityAttributes>?
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    private func minutes(_ phase: Phase, in mode: Mode) -> Int {
        switch (mode, phase) {
        case (.pomodoro, .focus): 25
        case (.pomodoro, .shortBreak): 5
        case (.pomodoro, .longBreak): 15
        case (.deepWork, .focus): 50
        case (.deepWork, .shortBreak): 10
        case (.deepWork, .longBreak): 20
        }
    }

    private var total: Int { minutes(phase, in: mode) * 60 }
    private var running: Bool { endDate != nil }

    private var remaining: Int {
        if let endDate { return max(0, Int(endDate.timeIntervalSince(now).rounded(.up))) }
        return pausedRemaining ?? total
    }

    /// 0 at the start of a focus phase, 1 when it ends; the plant grows with it.
    private var growth: Double {
        phase == .focus ? 1 - Double(remaining) / Double(total) : 1
    }

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader(copy.text("focus_mode"), nil, onClose: onClose)

            HStack(spacing: 4) {
                ForEach(Mode.allCases, id: \.self) { item in
                    Button {
                        switchTo(mode: item, phase: .focus)
                    } label: {
                        Text(copy.text(item == .pomodoro ? "pomodoro" : "deep_work"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(mode == item ? ExamPalette.textPrimary : ExamPalette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(mode == item ? ExamPalette.surface : .clear)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(mode == item ? 0.06 : 0), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(ExamPalette.border.opacity(0.6))
            .clipShape(Capsule())
            .padding(.top, 8)

            ZStack(alignment: .top) {
                FocusScene(growth: growth)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(.top, 110)

                ZStack {
                    Circle().fill(ExamPalette.surface)
                    Circle()
                        .stroke(ExamPalette.softBlue, lineWidth: 10)
                        .padding(9)
                    Circle()
                        .trim(from: 0, to: 1 - Double(remaining) / Double(total))
                        .stroke(ExamPalette.primary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(9)
                        .animation(.linear(duration: 1), value: remaining)
                    VStack(spacing: 4) {
                        Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(ExamPalette.textPrimary)
                        Text(copy.text(phase == .focus ? "focus_time" : "break_time"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ExamPalette.textSecondary)
                    }
                }
                .frame(width: 210, height: 210)
                .shadow(color: ExamPalette.primary.opacity(0.12), radius: 18, y: 8)
                .padding(.top, 18)
            }
            .frame(maxHeight: .infinity)

            Button {
                running ? pause() : start()
            } label: {
                Text(running ? copy.text("pause") : copy.text(phase == .focus ? "start_focus" : "start_break"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ExamPalette.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 14)

            HStack(spacing: 10) {
                ForEach(Phase.allCases, id: \.self) { item in
                    Button {
                        switchTo(mode: mode, phase: item)
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(minutes(item, in: mode))")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(phase == item ? ExamPalette.primary : ExamPalette.textPrimary)
                            Text(copy.text(item == .focus ? "focus" : item == .shortBreak ? "short_break" : "long_break"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ExamPalette.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(phase == item ? ExamPalette.softBlue : ExamPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(phase == item ? ExamPalette.primary : ExamPalette.border, lineWidth: phase == item ? 1.5 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(ExamPalette.background.ignoresSafeArea())
        .onReceive(ticker) { date in
            now = date
            if let endDate, endDate <= date { complete() }
        }
        .onAppear {
            // Store screenshots show a session midway, with the sapling half grown.
            if ScreenshotMode.isActive { pausedRemaining = total * 2 / 5 }
        }
    }

    private func switchTo(mode: Mode, phase: Phase) {
        cancelNotification()
        endLiveActivity()
        self.mode = mode
        self.phase = phase
        endDate = nil
        pausedRemaining = nil
    }

    private func start() {
        if phase == .focus {
            AppServices.shared.analytics.event(
                AnalyticsEvent.focusStarted,
                params: [AnalyticsParam.examId: setup.exam.id, AnalyticsParam.durationSeconds: remaining]
            )
        }
        now = Date()
        endDate = now.addingTimeInterval(TimeInterval(remaining))
        pausedRemaining = nil
        scheduleNotification(after: remaining)
        startLiveActivity()
    }

    /// Shows the countdown on the lock screen and in the Dynamic Island.
    private func startLiveActivity() {
        guard let endDate, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endLiveActivity()
        activity = try? Activity.request(
            attributes: FocusActivityAttributes(
                title: copy.text(phase == .focus ? "focus_time" : "break_time"),
                exam: setup.exam.shortName
            ),
            content: ActivityContent(state: .init(endsAt: endDate), staleDate: endDate)
        )
    }

    private func endLiveActivity() {
        guard let current = activity else { return }
        activity = nil
        Task { await current.end(nil, dismissalPolicy: .immediate) }
    }

    private func pause() {
        pausedRemaining = remaining
        endDate = nil
        cancelNotification()
        endLiveActivity()
    }

    private func complete() {
        if phase == .focus {
            AppServices.shared.analytics.event(
                AnalyticsEvent.focusCompleted,
                params: [AnalyticsParam.examId: setup.exam.id, AnalyticsParam.durationSeconds: total]
            )
        }
        endDate = nil
        pausedRemaining = 0
        endLiveActivity()
    }

    /// Scheduled up front so the reminder also fires while the app is in the background.
    private func scheduleNotification(after seconds: Int) {
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = copy.text(phase == .focus ? "focus_complete" : "break_complete")
        content.body = copy.text(phase == .focus ? "focus_break" : "break_over", variables: ["exam": setup.exam.shortName])
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: Self.notificationId, content: content, trigger: trigger)
        )
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationId])
    }
}

/// The focus illustration (design/illustrations/focus_scene.svg) with a sapling
/// drawn on top of the soil mound that grows as the focus phase progresses.
private struct FocusScene: View {
    let growth: Double

    var body: some View {
        GeometryReader { proxy in
            // The 400x440 scene is aspect-filled and centre-cropped; the sapling
            // stands on the soil mound at scene point (200, 380).
            let scale = max(proxy.size.width / 400, proxy.size.height / 440)
            let originX = (proxy.size.width - 400 * scale) / 2
            let originY = (proxy.size.height - 440 * scale) / 2
            ZStack(alignment: .topLeading) {
                Image("focus_scene")
                    .resizable()
                    .frame(width: 400 * scale, height: 440 * scale)
                    .offset(x: originX, y: originY)
                Sapling(growth: growth)
                    .frame(width: 120 * scale, height: 110 * scale)
                    .position(x: originX + 200 * scale, y: originY + (380 - 55) * scale)
                    .animation(.easeInOut(duration: 0.8), value: growth)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
    }
}

/// A sapling in a 120x110 box whose base sits at the bottom centre.
struct Sapling: View, Animatable {
    var growth: Double

    var animatableData: Double {
        get { growth }
        set { growth = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let s = size.width / 120
            let g = max(0.08, min(1, growth))
            let base = CGPoint(x: 60 * s, y: 110 * s)
            let height = 100 * s * g
            let stemColor = Color(red: 0.37, green: 0.66, blue: 0.50)
            let leafA = Color(red: 0.49, green: 0.77, blue: 0.60)
            let leafB = Color(red: 0.42, green: 0.71, blue: 0.54)

            var stem = Path()
            stem.move(to: base)
            stem.addQuadCurve(
                to: CGPoint(x: base.x, y: base.y - height),
                control: CGPoint(x: base.x + 8 * s, y: base.y - height / 2)
            )
            context.stroke(stem, with: .color(stemColor), style: StrokeStyle(lineWidth: 5 * s, lineCap: .round))

            func leaf(at t: Double, appearAt threshold: Double, length: Double, left: Bool, color: Color) {
                let p = min(1, max(0, (g - threshold) / 0.2))
                guard p > 0 else { return }
                let y = base.y - height * t
                let dir: Double = left ? -1 : 1
                var leafPath = Path()
                leafPath.move(to: CGPoint(x: base.x, y: y))
                let tip = CGPoint(x: base.x + dir * length * s * p, y: y - 14 * s * p)
                leafPath.addQuadCurve(to: tip, control: CGPoint(x: base.x + dir * length * 0.4 * s * p, y: y - 22 * s * p))
                leafPath.addQuadCurve(to: CGPoint(x: base.x, y: y), control: CGPoint(x: base.x + dir * length * 0.7 * s * p, y: y + 4 * s * p))
                context.fill(leafPath, with: .color(color))
            }

            leaf(at: 0.35, appearAt: 0.15, length: 34, left: true, color: leafB)
            leaf(at: 0.45, appearAt: 0.3, length: 30, left: false, color: leafA)
            leaf(at: 0.7, appearAt: 0.55, length: 28, left: true, color: leafA)
            leaf(at: 0.8, appearAt: 0.7, length: 26, left: false, color: leafB)
            leaf(at: 1.0, appearAt: 0.85, length: 20, left: false, color: leafA)
            leaf(at: 1.0, appearAt: 0.85, length: 20, left: true, color: leafB)
        }
    }
}

struct StudyProgressView: View {
    let setup: StudySetup
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var progress = StudyProgressSummary(masteryPercent: 0, sessions: 0, questions: 0, correct: 0, studyMinutes: 0)
    @State private var errorDNA: [ErrorDNAItem] = []
    @State private var user = UserProgressStore().snapshot()
    @State private var weekly = Array(repeating: 0, count: 7)
    @State private var lastWeekMinutes = 0
    @State private var masteredSkills = 0
    @State private var sections: [(title: String, percent: Int?)] = []
    @State private var shareImage: Image?

    private static let sectionColors = [ExamPalette.mint, ExamPalette.amber, ExamPalette.purple, ExamPalette.primary, ExamPalette.coral]

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    private var mastery: Int {
        progress.masteryPercent == 0 ? setup.diagnosticPercent : progress.masteryPercent
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                ToolHeader(
                    copy.text("your_progress"),
                    copy.text("learning_profile", variables: ["exam": setup.exam.shortName]),
                    onClose: onClose
                )

                weeklyReport

                HStack(spacing: 12) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().stroke(ExamPalette.softMint, lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: Double(mastery) / 100)
                                .stroke(ExamPalette.mint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(mastery)%")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(ExamPalette.mint)
                        }
                        .frame(width: 78, height: 78)
                        Text(copy.text("mastery"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ExamPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .examCard(radius: 20)

                    VStack(spacing: 8) {
                        Text("\(max(progress.questions, user.totalQuestions))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(ExamPalette.purple)
                            .frame(height: 78)
                        Text(copy.text("questions_solved"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ExamPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .examCard(radius: 20)
                }

                weeklyChart

                if !sections.isEmpty {
                    Text(copy.text("subject_progress"))
                        .font(.system(size: 18, weight: .bold))
                        .padding(.top, 4)
                    VStack(spacing: 14) {
                        ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                            sectionRow(section.title, section.percent, color: Self.sectionColors[index % Self.sectionColors.count])
                        }
                    }
                    .padding(16)
                    .examCard(radius: 20)
                }

                HStack(spacing: 8) {
                    metric("\(user.streak)", copy.text("streak") + " · " + copy.text(UserProgressStore().shieldAvailable() ? "shield_ready" : "shield_used"))
                    metric("\(progress.questions == 0 ? 0 : progress.correct * 100 / progress.questions)%", copy.text("accuracy"))
                    metric("\(max(progress.sessions, user.totalSessions))", copy.text("sessions"))
                }

                achievementsSection

                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview(copy.text("share_progress"), image: shareImage)) {
                        Label(copy.text("share_progress"), systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(ExamPalette.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(ExamPalette.softBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                Text(copy.text("error_dna"))
                    .font(.system(size: 18, weight: .bold))
                    .padding(.top, 4)

                if errorDNA.isEmpty {
                    Text(copy.text("no_error_pattern"))
                        .font(.system(size: 14))
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
        .onAppear(perform: load)
    }

    // MARK: Weekly report

    private var weeklyReport: some View {
        let thisWeek = weekly.reduce(0, +)
        let change = lastWeekMinutes == 0 ? nil : (thisWeek - lastWeekMinutes) * 100 / lastWeekMinutes
        let focus = sections.filter { $0.percent != nil }.min { ($0.percent ?? 0) < ($1.percent ?? 0) }?.title
            ?? sections.first?.title
        return VStack(alignment: .leading, spacing: 10) {
            Text(copy.text("your_week"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
            Text(copy.text("duration_hm", variables: ["h": String(thisWeek / 60), "m": String(thisWeek % 60)]))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            if let change {
                Label(copy.text("vs_last_week", variables: ["change": (change >= 0 ? "+" : "") + "\(change)%"]),
                      systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            if let focus {
                Text(copy.text("focus_next", variables: ["topic": focus]))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            LinearGradient(colors: [ExamPalette.primary, ExamPalette.indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Achievements

    private struct Badge {
        let key: String
        let symbol: String
        let color: Color
        let value: Int
        let target: Int
        var unlocked: Bool { value >= target }
    }

    private var badges: [Badge] {
        let questions = max(progress.questions, user.totalQuestions)
        return [
            Badge(key: "badge_streak_7", symbol: "flame.fill", color: ExamPalette.amber, value: user.streak, target: 7),
            Badge(key: "badge_streak_30", symbol: "flame.circle.fill", color: ExamPalette.coral, value: user.streak, target: 30),
            Badge(key: "badge_questions_100", symbol: "checkmark.seal.fill", color: ExamPalette.primary, value: questions, target: 100),
            Badge(key: "badge_questions_500", symbol: "star.circle.fill", color: ExamPalette.purple, value: questions, target: 500),
            Badge(key: "badge_study_10h", symbol: "clock.fill", color: ExamPalette.mint, value: progress.studyMinutes, target: 600),
            Badge(key: "badge_mastered_5", symbol: "graduationcap.fill", color: ExamPalette.indigo, value: masteredSkills, target: 5)
        ]
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(copy.text("achievements"))
                .font(.system(size: 18, weight: .bold))
                .padding(.top, 4)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(badges, id: \.key) { badge in
                    VStack(spacing: 8) {
                        Image(systemName: badge.symbol)
                            .font(.system(size: 24))
                            .foregroundStyle(badge.unlocked ? badge.color : ExamPalette.border)
                            .frame(width: 52, height: 52)
                            .background(badge.unlocked ? badge.color.opacity(0.14) : ExamPalette.background)
                            .clipShape(Circle())
                        Text(copy.text(badge.key))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(badge.unlocked ? ExamPalette.textPrimary : ExamPalette.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        Text(badge.unlocked ? "✓" : "\(min(badge.value, badge.target))/\(badge.target)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(badge.unlocked ? badge.color : ExamPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .examCard(radius: 18)
                }
            }
        }
    }

    // MARK: Share card

    @MainActor
    private func renderShareCard() {
        let card = ProgressShareCard(
            exam: setup.exam.shortName,
            streak: user.streak,
            minutes: progress.studyMinutes,
            questions: max(progress.questions, user.totalQuestions),
            mastery: mastery,
            copy: copy
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let image = renderer.uiImage { shareImage = Image(uiImage: image) }
    }

    private var weeklyChart: some View {
        let peak = max(weekly.max() ?? 0, 1)
        let total = weekly.reduce(0, +)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(copy.text("this_week"))
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text(copy.text("duration_hm", variables: ["h": String(total / 60), "m": String(total % 60)]))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ExamPalette.primary)
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 6) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: index == 6
                                        ? [ExamPalette.indigo, ExamPalette.primary]
                                        : [ExamPalette.primary.opacity(0.45), ExamPalette.primary.opacity(0.25)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: 18, height: max(8, 114 * CGFloat(weekly[index]) / CGFloat(peak)))
                        Text(weekdayLabel(daysAgo: 6 - index))
                            .font(.system(size: 11, weight: index == 6 ? .bold : .medium))
                            .foregroundStyle(index == 6 ? ExamPalette.textPrimary : ExamPalette.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 146, alignment: .bottom)
        }
        .padding(16)
        .examCard(radius: 20)
    }

    private func sectionRow(_ title: String, _ percent: Int?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Circle()
                    .fill(color.opacity(0.16))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(color, lineWidth: 2).padding(8))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ExamPalette.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(percent.map { "\($0)%" } ?? "—")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ExamPalette.textSecondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(ExamPalette.border)
                    Capsule().fill(color).frame(width: proxy.size.width * CGFloat(percent ?? 0) / 100)
                }
            }
            .frame(height: 7)
            .padding(.leading, 38)
        }
    }

    private func weekdayLabel(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: setup.languageCode)
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    private func load() {
        let store = LearningStore(context: modelContext)
        progress = (try? store.progressSummary(examId: setup.exam.id)) ?? progress
        errorDNA = (try? store.errorDNA(examId: setup.exam.id)) ?? []
        user = UserProgressStore().snapshot()
        let fortnight = (try? store.weeklyMinutes(examId: setup.exam.id, days: 14)) ?? Array(repeating: 0, count: 14)
        weekly = Array(fortnight.suffix(7))
        lastWeekMinutes = fortnight.prefix(7).reduce(0, +)
        masteredSkills = (try? store.masteredSkillCount(examId: setup.exam.id)) ?? 0
        let titles = ContentPackRepository.load(packId: setup.exam.syllabusPackId)?.units.prefix(5).map(\.title) ?? []
        let percents = (try? store.sectionMastery(examId: setup.exam.id, sectionTitles: Array(titles))) ?? []
        sections = zip(titles, percents).map { (title: $0, percent: $1) }

        if ScreenshotMode.isActive {
            // Store screenshots show an established learner.
            weekly = [35, 50, 20, 65, 45, 80, 40]
            progress = StudyProgressSummary(masteryPercent: progress.masteryPercent, sessions: 38, questions: 412, correct: 346, studyMinutes: 335)
            lastWeekMinutes = 260
            masteredSkills = 3
            sections = sections.enumerated().map { index, section in
                (title: section.title, percent: [76, 62, 48, 70, 55][index % 5])
            }
        }
        renderShareCard()
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

/// Story-sized progress card people can share (streak, study time, questions, mastery).
private struct ProgressShareCard: View {
    let exam: String
    let streak: Int
    let minutes: Int
    let questions: Int
    let mastery: Int
    let copy: LocalizedCopy

    var body: some View {
        VStack(spacing: 18) {
            Text("🔥 \(streak)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(copy.text("day_streak").uppercased())
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
            VStack(spacing: 12) {
                row(copy.text("duration_hm", variables: ["h": String(minutes / 60), "m": String(minutes % 60)]), copy.text("study_time"))
                row("\(questions)", copy.text("questions_solved"))
                row("\(mastery)%", copy.text("mastery"))
            }
            .padding(18)
            .background(.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            HStack(spacing: 8) {
                Image("app_mark").resizable().frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 7))
                Text("Examly · \(exam)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(28)
        .frame(width: 360, height: 560)
        .background(
            LinearGradient(colors: [Color(red: 0.23, green: 0.29, blue: 0.48), Color(red: 0.11, green: 0.14, blue: 0.25)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func row(_ value: String, _ label: String) -> some View {
        HStack {
            Text(label).font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
        }
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

                ShareLink(
                    item: URL(string: "https://apps.apple.com/app/id6817641143")!,
                    message: Text(copy.text("invite_message", variables: ["exam": setup.exam.shortName]))
                ) {
                    settingsRowContent("person.2.fill", copy.text("invite_friend"), copy.text("invite_hint"))
                }
                .buttonStyle(.plain)

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
            settingsRowContent(symbol, title, subtitle)
        }
        .buttonStyle(.plain)
    }

    private func settingsRowContent(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
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
