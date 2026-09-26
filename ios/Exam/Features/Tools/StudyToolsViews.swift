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

    @State private var questionCount = 10
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader("Mock Exam", "\(setup.exam.shortName) · timed mixed set", onClose: onClose)

            VStack(alignment: .leading, spacing: 12) {
                Text("Exam simulation")
                    .font(.system(size: 18, weight: .bold))
                Text("Questions are generated against your selected exam context and recorded as a mock session.")
                    .font(.system(size: 13))
                    .foregroundStyle(ExamPalette.textSecondary)

                HStack(spacing: 8) {
                    ForEach([10, 20, 30], id: \.self) { count in
                        Button {
                            questionCount = count
                        } label: {
                            Text("\(count) questions")
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
                        self.error = error.localizedDescription
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
                    Text(loading ? "Building mock…" : "Start mock")
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

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader("Mistakes", "Your unresolved Error DNA", onClose: onClose)

            if mistakes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(ExamPalette.mint)
                    Text("No unresolved mistakes")
                        .font(.system(size: 18, weight: .bold))
                    Text("New mistakes will appear here automatically.")
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
                                Text("\(item.errorType.replacingOccurrences(of: "_", with: " ")) · selected: \(item.selectedAnswer ?? "—")")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ExamPalette.textSecondary)
                                if let correct = item.correctAnswer {
                                    Text("Correct: \(correct)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(ExamPalette.mint)
                                }
                                Button("Mark resolved") {
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
                Label("Practice weak areas", systemImage: "arrow.clockwise")
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

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader("Flashcards", "Spaced repetition", onClose: onClose)

            if cards.isEmpty {
                Spacer()
                Text("Nothing due right now.")
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
                        Text(revealed ? "Rate your recall" : "Tap to reveal")
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
                        ratingButton("Again", .again, card: card)
                        ratingButton("Hard", .hard, card: card)
                        ratingButton("Good", .good, card: card)
                        ratingButton("Easy", .easy, card: card)
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

    @State private var topic = ""
    @State private var count = 5
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader("Create Practice", "Generate a focused set", onClose: onClose)

            TextField("Topic or instruction", text: $topic, axis: .vertical)
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
                            self.error = "The generated set was invalid. Try a more specific topic."
                        } else {
                            onStart(parsed)
                        }
                    } catch {
                        self.error = error.localizedDescription
                    }
                    loading = false
                }
            } label: {
                HStack {
                    if loading { ProgressView().tint(.white) }
                    else { Image(systemName: "sparkles") }
                    Text(loading ? "Generating…" : "Generate practice")
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

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader("Focus", "\(setup.exam.shortName) Pomodoro", onClose: onClose)

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
                Text(running ? "Stay with it" : "Ready")
                    .foregroundStyle(ExamPalette.textSecondary)
            }
            .frame(width: 230, height: 230)
            .background(ExamPalette.surface)
            .clipShape(Circle())

            Spacer()

            Button {
                running ? pause() : start()
            } label: {
                Label(running ? "Pause" : "Start focus", systemImage: running ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ExamPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            Button("Reset") { reset(focusMinutes) }
                .font(.system(size: 13, weight: .semibold))
                .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(ExamPalette.background.ignoresSafeArea())
        .onDisappear { timer?.invalidate() }
    }

    private func start() {
        running = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if remaining > 0 {
                    remaining -= 1
                } else {
                    pause()
                    let content = UNMutableNotificationContent()
                    content.title = "Focus session complete"
                    content.body = "\(setup.exam.shortName) · Nice work. Take a short break."
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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                ToolHeader("Progress", "\(setup.exam.shortName) learning profile", onClose: onClose)

                HStack(spacing: 8) {
                    metric("\(progress.masteryPercent == 0 ? setup.diagnosticPercent : progress.masteryPercent)%", "Mastery")
                    metric("\(user.streak)", "Streak")
                    metric("\(user.xp)", "XP")
                }

                HStack(spacing: 8) {
                    metric("\(progress.sessions)", "Sessions")
                    metric("\(progress.questions == 0 ? 0 : progress.correct * 100 / progress.questions)%", "Accuracy")
                    metric("\(progress.studyMinutes)m", "Study")
                }

                Text("Error DNA")
                    .font(.system(size: 18, weight: .bold))
                    .padding(.top, 8)

                if errorDNA.isEmpty {
                    Text("No active error pattern yet.")
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

    @State private var price: String?
    @State private var loading = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader("AI Credits", "For high-cost image & video generation", onClose: onClose)

            VStack(alignment: .leading, spacing: 8) {
                Text("25 credits")
                    .font(.system(size: 28, weight: .bold))
                Text("Use credits only for expensive generated visuals/video. Core study stays subscription/free-limit based.")
                    .font(.system(size: 13))
                    .foregroundStyle(ExamPalette.textSecondary)
                Text(price ?? "Loading local price…")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(ExamPalette.primary)
                    .padding(.top, 10)
            }
            .padding(20)
            .examCard(radius: 24)
            .padding(.top, 20)

            if let message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.top, 10)
            }

            Spacer()

            Button {
                loading = true
                Task { @MainActor in
                    let success = await StoreKitBillingService.shared.purchase(
                        productId: StoreKitBillingService.ProductId.creditsSmall
                    )
                    message = success ? "Credits added." : "Purchase not completed."
                    loading = false
                }
            } label: {
                Text(loading ? "Processing…" : "Buy 25 credits")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ExamPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(price == nil || loading)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(ExamPalette.background.ignoresSafeArea())
        .task {
            price = await StoreKitBillingService.shared.loadCreditPrice()
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

    private let languages = [
        ("en", "English"), ("tr", "Türkçe"), ("de", "Deutsch"),
        ("es", "Español"), ("fr", "Français"), ("pt", "Português"),
        ("ko", "한국어"), ("ja", "日本語"), ("hi", "हिन्दी")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ToolHeader("Profile & Settings", setup.exam.shortName, onClose: onClose)

                settingsRow("chart.xyaxis.line", "Progress", "Mastery, streak, XP and Error DNA", action: onProgress)
                settingsRow("diamond.fill", "AI Credits", "High-cost image/video credits", action: onCredits)

                VStack(alignment: .leading, spacing: 8) {
                    Text("App language").font(.system(size: 14, weight: .semibold))
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
                    Text("Daily reminder").font(.system(size: 14, weight: .semibold))
                    Text("\(reminderHour):00 local time")
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

                settingsRow("arrow.clockwise", "Restore purchases", "Ask the App Store to restore active purchases") {
                    Task { @MainActor in
                        await StoreKitBillingService.shared.restore()
                    }
                }

                settingsRow("arrow.counterclockwise", "Choose another exam", "Restart onboarding and build a new plan", action: onRestartOnboarding)

                settingsRow("trash.fill", "Delete account", "Permanently delete cloud study data and account") {
                    confirmDelete = true
                }

                if let deleteError {
                    Text(deleteError)
                        .font(.system(size: 12))
                        .foregroundStyle(ExamPalette.coral)
                }

                Text("Privacy: study files stay scoped to your authenticated account. AI provider keys are server-side and are never shipped in the app.")
                    .font(.system(size: 11))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.vertical, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(ExamPalette.background.ignoresSafeArea())
        .alert("Delete account?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete permanently", role: .destructive) {
                deletingAccount = true
                deleteError = nil
                Task { @MainActor in
                    do {
                        try await AccountService().deleteAccount()
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
            Text("This permanently deletes your cloud study files, AI jobs, push token and account. This cannot be undone.")
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
                Image(systemName: symbol)
                    .foregroundStyle(ExamPalette.primary)
                    .frame(width: 34)
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

    var body: some View {
        VStack(spacing: 0) {
            ToolHeader("Visual Explanation", "\(setup.exam.shortName) · credit-based AI media", onClose: onClose)

            TextField(
                "What should the visual explain?",
                text: $prompt,
                axis: .vertical
            )
            .lineLimit(4...7)
            .padding(14)
            .examCard(radius: 18)
            .padding(.top, 18)

            HStack(spacing: 9) {
                mediaButton(
                    title: "Image · 1",
                    symbol: "photo.fill",
                    kind: "image_explainer",
                    enabled: AppServices.shared.flags.snapshot.imageExplanationsEnabled
                )
                mediaButton(
                    title: "Video · 5",
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

                    Label("Media ready", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(ExamPalette.mint)

                    Link(destination: assetURL) {
                        Text("Open generated asset")
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

            Text("Image/video generation is optional and spends credits because its provider cost is materially higher than normal tutoring.")
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
                        break
                    }
                    if update.status == "completed" {
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
