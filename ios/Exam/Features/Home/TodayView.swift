import SwiftUI
import SwiftData

private enum ExamTab: String, CaseIterable, Hashable {
    case today = "Today"
    case practice = "Practice"
    case tutor = "AI Tutor"
    case library = "Library"

    var symbol: String {
        switch self {
        case .today: "house.fill"
        case .practice: "pencil.and.list.clipboard"
        case .tutor: "sparkles"
        case .library: "folder.fill"
        }
    }
}

private enum ToolRoute {
    case mock
    case mistakes
    case flashcards
    case createPractice
    case focus
    case progress
    case credits
    case profile
    case media
}

struct TodayView: View {
    let setup: StudySetup
    var onSetupChanged: (StudySetup) -> Void = { _ in }
    var onRestartOnboarding: () -> Void = {}

    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: ExamTab = .today
    @State private var premiumPlacement: String?
    @State private var voiceTutorOpen = false
    @State private var toolRoute: ToolRoute?
    @State private var sessionOpen = false
    @State private var sessionQuestions: [StudyQuestion]?
    @State private var sessionType = "quick_practice"
    @State private var sessionTimeLimit: Int?
    @State private var dashboardRefresh = 0
    @State private var entitlement = EntitlementSnapshot.empty
    @State private var giftWheelOpen = false
    @State private var spunToday = OfferService.spunToday
    @State private var homeOffer: ActiveOffer?
    @State private var creditBoost: CreditBoost?

    @State private var plan: [PlanTask] = []
    @State private var progress = StudyProgressSummary(
        masteryPercent: 0,
        sessions: 0,
        questions: 0,
        correct: 0,
        studyMinutes: 0
    )
    @State private var userProgress = UserProgressStore().snapshot()

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    var body: some View {
        Group {
            if let premiumPlacement {
                PremiumPaywallView(
                    setup: setup,
                    placement: premiumPlacement,
                    onClose: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            self.premiumPlacement = nil
                            dashboardRefresh += 1
                        }
                    }
                )
            } else if sessionOpen {
                QuestionSessionView(
                    setup: setup,
                    onClose: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            sessionOpen = false
                            sessionQuestions = nil
                            sessionTimeLimit = nil
                            dashboardRefresh += 1
                        }
                    },
                    questionsOverride: sessionQuestions,
                    sessionType: sessionType,
                    onSessionCompleted: {
                        if sessionType == "quick_practice" || sessionType == "daily_plan" {
                            let dayKey = Self.dayKey
                            let store = LearningStore(context: modelContext)
                            if let first = (try? store.plan(dayKey: dayKey))?.first(where: { !$0.completed }) {
                                try? store.markPlanCompleted(id: first.id)
                            }
                        }
                        dashboardRefresh += 1
                    },
                    onPaywall: { placement in
                        sessionOpen = false
                        sessionTimeLimit = nil
                        premiumPlacement = placement
                    },
                    timeLimitSeconds: sessionTimeLimit
                )
            } else if voiceTutorOpen {
                VoiceTutorView(
                    setup: setup,
                    onClose: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            voiceTutorOpen = false
                            dashboardRefresh += 1
                        }
                    }
                )
            } else if giftWheelOpen {
                GiftWheelScreen(
                    copy: copy,
                    onClose: closeGiftWheel,
                    onClaimOffer: {
                        closeGiftWheel()
                        premiumPlacement = "wheel"
                    },
                    onCreditsWon: closeGiftWheel
                )
                .transition(.move(edge: .bottom))
            } else if let toolRoute {
                toolView(toolRoute)
            } else {
                appShell
            }
        }
        .background(ExamPalette.background.ignoresSafeArea())
        .onAppear {
            guard ScreenshotMode.isActive else { return }
            switch ScreenshotMode.screen {
            case "practice": selectedTab = .practice
            case "tutor": selectedTab = .tutor
            case "library": selectedTab = .library
            case "session": openSession(type: "quick_practice")
            case "paywall": premiumPlacement = "push_offer"
            case "credits": toolRoute = .credits
            case "focus": toolRoute = .focus
            case "progress": toolRoute = .progress
            case "wheel": giftWheelOpen = true
            default: break
            }
        }
        .onReceive(DeepLinkRouter.shared.$pending.compactMap { $0 }) { _ in
            openDeepLink(DeepLinkRouter.shared.consume())
        }
        .task(id: dashboardRefresh) {
            if premiumPlacement == nil {
                entitlement = await EntitlementService().fetch()
            }
            loadDashboard()
            spunToday = OfferService.spunToday
            // Also lets the server issue this week's offer (max two a week).
            let offer = await OfferService.shared.fetch(daysToExam: StudySetupStore.daysToExam())
            homeOffer = entitlement.premium ? nil : offer
            creditBoost = OfferService.shared.creditBoost
        }
    }

    @ViewBuilder
    private func toolView(_ route: ToolRoute) -> some View {
        switch route {
        case .mock:
            MockExamView(
                setup: setup,
                onClose: { toolRoute = nil },
                onStart: { questions in
                    toolRoute = nil
                    openSession(
                        type: "mock_exam",
                        questions: questions,
                        timeLimitSeconds: questions.count * 90
                    )
                },
                onPaywall: { placement in
                    toolRoute = nil
                    premiumPlacement = placement
                }
            )

        case .mistakes:
            MistakesView(
                setup: setup,
                onClose: { toolRoute = nil },
                onPractice: {
                    toolRoute = nil
                    openSession(type: "mistake_review")
                }
            )

        case .flashcards:
            FlashcardsView(
                setup: setup,
                onClose: {
                    toolRoute = nil
                    dashboardRefresh += 1
                }
            )

        case .createPractice:
            CreatePracticeView(
                setup: setup,
                onClose: { toolRoute = nil },
                onStart: { questions in
                    toolRoute = nil
                    openSession(type: "generated_practice", questions: questions)
                },
                onPaywall: { placement in
                    toolRoute = nil
                    premiumPlacement = placement
                }
            )

        case .focus:
            FocusView(
                setup: setup,
                onClose: { toolRoute = nil }
            )

        case .progress:
            StudyProgressView(
                setup: setup,
                onClose: { toolRoute = nil }
            )

        case .credits:
            CreditStoreView(
                setup: setup,
                onClose: {
                    toolRoute = nil
                    dashboardRefresh += 1
                }
            )

        case .media:
            MediaLabView(
                setup: setup,
                onClose: { toolRoute = nil },
                onNeedCredits: { toolRoute = .credits }
            )

        case .profile:
            ProfileSettingsView(
                setup: setup,
                onClose: { toolRoute = nil },
                onSetupChanged: { updated in
                    onSetupChanged(updated)
                    toolRoute = nil
                },
                onProgress: { toolRoute = .progress },
                onCredits: { toolRoute = .credits },
                onRestartOnboarding: onRestartOnboarding
            )
        }
    }

    private func closeGiftWheel() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            giftWheelOpen = false
            dashboardRefresh += 1
        }
    }

    private func openDeepLink(_ route: String?) {
        switch route {
        case "paywall":
            guard !entitlement.premium else { return }
            toolRoute = nil
            premiumPlacement = "push_offer"
        case "review":
            premiumPlacement = nil
            toolRoute = .mistakes
        case "today":
            premiumPlacement = nil
            toolRoute = nil
            selectedTab = .today
        case "wheel":
            premiumPlacement = nil
            toolRoute = nil
            selectedTab = .today
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { giftWheelOpen = true }
        case "credits":
            premiumPlacement = nil
            toolRoute = .credits
        default:
            break
        }
    }

    private var appShell: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .today:
                    todayContent

                case .practice:
                    PracticeView(
                        setup: setup,
                        onQuickPractice: {
                            openSession(type: "quick_practice")
                        },
                        onMockExam: {
                            toolRoute = .mock
                        },
                        onMistakes: {
                            toolRoute = .mistakes
                        },
                        onFlashcards: {
                            toolRoute = .flashcards
                        },
                        onCreatePractice: {
                            toolRoute = .createPractice
                        },
                        onFocus: {
                            toolRoute = .focus
                        },
                        onLibrary: {
                            selectedTab = .library
                        }
                    )

                case .tutor:
                    AITutorView(
                        setup: setup,
                        onVoiceTutor: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                if entitlement.premium && AppServices.shared.flags.snapshot.voiceTutorEnabled {
                                    voiceTutorOpen = true
                                } else {
                                    premiumPlacement = "voice_tutor"
                                }
                            }
                        },
                        onStudyNotes: {
                            selectedTab = .library
                        },
                        onMediaLab: {
                            toolRoute = .media
                        },
                        onPaywall: { placement in
                            premiumPlacement = placement
                        }
                    )

                case .library:
                    LibraryView(
                        setup: setup,
                        onStartPractice: { questions in
                            openSession(type: "material_practice", questions: questions)
                        },
                        onPaywall: { placement in
                            premiumPlacement = placement
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
    }

    private var todayContent: some View {
        let activeTask = plan.first(where: { !$0.completed })
        let mastery = progress.masteryPercent == 0
            ? setup.diagnosticPercent
            : progress.masteryPercent
        let completedCount = plan.filter(\.completed).count
        let hour = Calendar.current.component(.hour, from: Date())
        let greetingKey = hour >= 5 && hour <= 11
            ? "good_morning"
            : hour >= 12 && hour <= 17
            ? "good_afternoon"
            : "good_evening"
        let remainingMinutes = max(5, plan.filter { !$0.completed }.map(\.estimatedMinutes).reduce(0, +))

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(copy.text(greetingKey))
                            .font(.system(size: 13))
                            .foregroundStyle(ExamPalette.textSecondary)
                        Text(copy.text("ready_small_win"))
                            .font(.system(size: 22, weight: .bold))
                    }

                    Spacer()

                    Button {
                        toolRoute = .profile
                    } label: {
                        Image(systemName: "person.fill")
                            .foregroundStyle(ExamPalette.primary)
                            .frame(width: 42, height: 42)
                            .background(ExamPalette.softBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 9) {
                    ExamStatPill(
                        value: "\(userProgress.streak)",
                        label: copy.text("day_streak"),
                        symbol: "flame.fill",
                        accent: ExamPalette.amber
                    )
                    if let days = StudySetupStore.daysToExam() {
                        ExamStatPill(
                            value: "\(days)",
                            label: copy.text("days_to_exam", variables: ["exam": setup.exam.shortName]),
                            symbol: "calendar",
                            accent: ExamPalette.mint
                        )
                    } else {
                        ExamStatPill(
                            value: setup.exam.shortName,
                            label: copy.text("active_exam"),
                            symbol: "graduationcap.fill",
                            accent: ExamPalette.mint
                        )
                    }
                    ExamStatPill(
                        value: "\(mastery)",
                        label: copy.text("mastery"),
                        symbol: "chart.xyaxis.line",
                        accent: ExamPalette.purple
                    )
                }
                // Pills stretch to the tallest one so the row stays even.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)

                if let homeOffer, !homeOffer.isExpired {
                    TimedOfferHomeCard(
                        title: copy.text("offer_title_\(homeOffer.kind)"),
                        subtitle: copy.text("home_offer_subtitle", variables: ["percent": String(homeOffer.discountPercent)]),
                        symbol: homeOffer.kind == "wheel" ? "gift.fill" : "bolt.fill",
                        colors: [Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.36, green: 0.36, blue: 0.96)],
                        expiresAt: homeOffer.expiresAt
                    ) {
                        premiumPlacement = homeOffer.kind
                    }
                    .padding(.top, 14)
                }
                if let creditBoost, creditBoost.expiresAt > Date() {
                    TimedOfferHomeCard(
                        title: copy.text("credit_boost_title", variables: ["percent": String(creditBoost.bonusPercent)]),
                        subtitle: copy.text("credit_boost_subtitle"),
                        symbol: "sparkles",
                        colors: [Color(red: 0.13, green: 0.72, blue: 0.62), Color(red: 0.23, green: 0.42, blue: 0.96)],
                        expiresAt: creditBoost.expiresAt
                    ) {
                        toolRoute = .credits
                    }
                    .padding(.top, 14)
                }
                GiftWheelHomeCard(copy: copy, spunToday: spunToday) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { giftWheelOpen = true }
                }
                .padding(.top, 14)

                let expiry = AppServices.shared.flags.snapshot.limitedOfferExpiryEpochSeconds
                if homeOffer == nil, expiry > Int64(Date().timeIntervalSince1970) {
                    LimitedOfferView(
                        expiryEpochSeconds: expiry,
                        title: copy.text("personal_offer"),
                        subtitle: copy.text("offer_server_timed")
                    ) {
                        premiumPlacement = "winback"
                    }
                    .padding(.top, 14)
                }

                HStack {
                    Text(copy.text("todays_plan", variables: ["exam": setup.exam.shortName]).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ExamPalette.textSecondary)

                    Spacer()

                    Button {
                        toolRoute = .progress
                    } label: {
                        Text(
                            copy.text(
                                "plan_done_count",
                                variables: [
                                    "done": "\(completedCount)",
                                    "total": "\(max(plan.count, 1))"
                                ]
                            )
                        )
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 22)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Image(systemName: "books.vertical.fill")
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Spacer()

                        Text("\(userProgress.xp) XP")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.16))
                            .clipShape(Capsule())
                    }

                    Text(activeTask?.title ?? copy.text("daily_plan_complete"))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 22)

                    Text(
                        activeTask == nil
                        ? copy.text("tomorrow_adaptive_plan")
                        : copy.text("personalized_plan_hint")
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.top, 3)

                    Label(
                        activeTask == nil
                        ? copy.text("completed")
                        : copy.text(
                            "minutes_remaining",
                            variables: [
                                "task": "\(activeTask?.estimatedMinutes ?? 0)",
                                "remaining": "\(remainingMinutes)"
                            ]
                        ),
                        systemImage: "clock.fill"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 16)

                    Button {
                        if activeTask == nil {
                            toolRoute = .focus
                        } else {
                            openSession(type: "daily_plan")
                        }
                    } label: {
                        Text(activeTask == nil ? copy.text("start_focus_session") : copy.text("continue"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(ExamPalette.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 18)
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [ExamPalette.primary, ExamPalette.indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.top, 8)

                Text(copy.text("next_up"))
                    .font(.system(size: 18, weight: .bold))
                    .padding(.top, 22)

                VStack(spacing: 8) {
                    ForEach(Array(plan.filter { !$0.completed }.dropFirst().prefix(2))) { task in
                        nextRow(
                            symbol: task.type == "mistake_review"
                                ? "arrow.clockwise"
                                : task.type == "mixed_set"
                                ? "checklist"
                                : "book.fill",
                            title: task.title,
                            subtitle: copy.text("minutes_short", variables: ["count": "\(task.estimatedMinutes)"]),
                            accent: task.type == "mistake_review"
                                ? ExamPalette.coral
                                : task.type == "mixed_set"
                                ? ExamPalette.purple
                                : ExamPalette.primary
                        ) {
                            openSession(type: "daily_plan")
                        }
                    }

                    if ((try? LearningStore(context: modelContext).mistakes(examId: setup.exam.id, limit: 1)) ?? []).isEmpty == false {
                        nextRow(
                            symbol: "arrow.clockwise",
                            title: copy.text("review_mistakes"),
                            subtitle: copy.text("error_dna_attention"),
                            accent: ExamPalette.coral
                        ) {
                            toolRoute = .mistakes
                        }
                    }

                    nextRow(
                        symbol: "sparkles",
                        title: copy.text("ask_tutor"),
                        subtitle: copy.text("explain_scan_practice"),
                        accent: ExamPalette.purple
                    ) {
                        selectedTab = .tutor
                    }
                }
                .padding(.top, 9)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    private var bottomBar: some View {
        HStack {
            ForEach(ExamTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(selectedTab == tab ? ExamPalette.primary : ExamPalette.textSecondary)
                        Text(tabLabel(tab))
                            .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundStyle(selectedTab == tab ? ExamPalette.primary : ExamPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .background(ExamPalette.surface)
        .overlay(alignment: .top) {
            Divider().foregroundStyle(ExamPalette.border)
        }
    }

    private func tabLabel(_ tab: ExamTab) -> String {
        switch tab {
        case .today: copy.text("today")
        case .practice: copy.text("practice")
        case .tutor: copy.text("ai_tutor")
        case .library: copy.text("library")
        }
    }

    private func nextRow(
        symbol: String,
        title: String,
        subtitle: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(accent)
                    .frame(width: 40, height: 40)
                    .background(accent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ExamPalette.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(ExamPalette.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(ExamPalette.textSecondary)
            }
            .padding(13)
            .examCard(radius: 17)
        }
        .buttonStyle(.plain)
    }

    private func openSession(
        type: String,
        questions: [StudyQuestion]? = nil,
        timeLimitSeconds: Int? = nil
    ) {
        sessionType = type
        sessionQuestions = questions
        sessionTimeLimit = timeLimitSeconds
        sessionOpen = true
    }

    @MainActor
    private func loadDashboard() {
        let store = LearningStore(context: modelContext)
        progress = (try? store.progressSummary(examId: setup.exam.id)) ?? progress
        userProgress = UserProgressStore().snapshot()

        let key = Self.dayKey
        var currentPlan = (try? store.plan(dayKey: key)) ?? []

        if currentPlan.isEmpty {
            var generated = DailyPlanEngine().build(
                weakSkills: (try? store.weakSkills(examId: setup.exam.id)) ?? [],
                dueSkills: (try? store.dueSkills(examId: setup.exam.id)) ?? [],
                errorDNA: (try? store.errorDNA(examId: setup.exam.id)) ?? [],
                dailyMinutes: setup.dailyMinutes
            )

            if progress.sessions == 0,
               let pack = ContentPackRepository.load(packId: setup.exam.syllabusPackId),
               !pack.units.isEmpty {
                var remaining = setup.dailyMinutes
                generated = Array(pack.units.prefix(3).enumerated()).map { index, unit in
                    let minutes = min(unit.durationMinutes.map { min(max($0, 6), 15) } ?? 8, max(remaining, 6))
                    remaining -= minutes
                    return PlanTask(
                        id: "seed_\(key)_\(index)",
                        type: index == 0 ? "foundation" : "practice",
                        skillId: setup.exam.id + ":" + unit.id,
                        title: unit.title,
                        estimatedMinutes: minutes,
                        priority: 1.0 - Double(index) * 0.1
                    )
                }
            }

            try? store.savePlan(dayKey: key, tasks: generated)
            currentPlan = (try? store.plan(dayKey: key)) ?? generated
        }

        plan = currentPlan
        WidgetSnapshotWriter.write(
            setup: setup,
            plan: currentPlan,
            dueReviews: (try? store.dueSkills(examId: setup.exam.id).count) ?? 0,
            streak: userProgress.streak
        )
    }

    private static var dayKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private struct LimitedOfferView: View {
    let expiryEpochSeconds: Int64
    let title: String
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, expiryEpochSeconds - Int64(context.date.timeIntervalSince1970))
            if remaining > 0 {
                let hours = remaining / 3600
                let minutes = (remaining % 3600) / 60
                let seconds = remaining % 60

                Button(action: onTap) {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(ExamPalette.purple)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(ExamPalette.textPrimary)
                            Text(subtitle)
                                .font(.system(size: 10))
                                .foregroundStyle(ExamPalette.textSecondary)
                        }

                        Spacer()

                        Text(String(format: "%02lld:%02lld:%02lld", hours, minutes, seconds))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(ExamPalette.purple)
                    }
                    .padding(13)
                    .background(ExamPalette.softPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(ExamPalette.purple.opacity(0.25))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Gift wheel

/// Wheel segments, clockwise from 12 o'clock; must match backend/functions/src/wheel.ts.
private let wheelSegments = ["credits10", "annual40", "credits5", "credits25", "annual40", "credits5", "credits10", "annual40"]

private let wheelColors: [Color] = [
    Color(red: 0.23, green: 0.42, blue: 0.96), Color(red: 0.55, green: 0.36, blue: 0.96),
    Color(red: 0.17, green: 0.80, blue: 0.55), Color(red: 0.96, green: 0.65, blue: 0.14),
    Color(red: 0.36, green: 0.36, blue: 0.96), Color(red: 0.13, green: 0.72, blue: 0.81),
    Color(red: 0.31, green: 0.55, blue: 1.00), Color(red: 0.93, green: 0.44, blue: 0.63)
]

/// Drives the wheel frame by frame so the pointer can kick (with a haptic tick)
/// each time a segment boundary passes it.
@MainActor
private final class WheelEngine: NSObject, ObservableObject {
    @Published var angle: Double = -22.5
    @Published var pointerKick: Double = 0

    private enum Phase { case idle, windUp(start: CFTimeInterval, from: Double), landing(start: CFTimeInterval, from: Double, to: Double) }
    private var phase: Phase = .idle
    private var link: CADisplayLink?
    private var lastSegment = 0
    private var onLanded: (() -> Void)?
    private let haptic = UISelectionFeedbackGenerator()
    private let landingDuration: CFTimeInterval = 5.2

    func windUp() {
        phase = .windUp(start: CACurrentMediaTime(), from: angle)
        startLink()
    }

    /// Decelerates onto `segment` (centre plus a little jitter) and calls `completion` when settled.
    func land(on segment: Int, completion: @escaping () -> Void) {
        let slice = 360.0 / Double(wheelSegments.count)
        let target = 360 - (Double(segment) * slice + slice / 2) + Double.random(in: -slice * 0.3...slice * 0.3)
        let current = angle.truncatingRemainder(dividingBy: 360)
        var delta = target - current
        while delta < 0 { delta += 360 }
        phase = .landing(start: CACurrentMediaTime(), from: angle, to: angle + delta + 5 * 360)
        onLanded = completion
        startLink()
    }

    private func startLink() {
        guard link == nil else { return }
        haptic.prepare()
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        switch phase {
        case .idle:
            break
        case let .windUp(start, from):
            let t = now - start
            // Accelerate to 720°/s over 0.8s, then keep spinning until the prize arrives.
            angle = t < 0.8 ? from + 450 * t * t : from + 288 + 720 * (t - 0.8)
        case let .landing(start, from, to):
            let p = min(1, (now - start) / landingDuration)
            angle = from + (to - from) * (1 - pow(1 - p, 4))
            if p >= 1 {
                phase = .idle
                link.invalidate()
                self.link = nil
                onLanded?()
                onLanded = nil
            }
        }
        let slice = 360.0 / Double(wheelSegments.count)
        let normalized = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let segment = Int(((360 - normalized).truncatingRemainder(dividingBy: 360)) / slice)
        if segment != lastSegment {
            lastSegment = segment
            haptic.selectionChanged()
            pointerKick = -16
            withAnimation(.interpolatingSpring(stiffness: 400, damping: 9)) { pointerKick = 0 }
        }
    }
}

/// The wheel face: gradient slices with prize labels, a glowing rim and blinking bulbs.
private struct WheelFace: View {
    let copy: LocalizedCopy

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(AngularGradient(colors: [Color(red: 0.73, green: 0.78, blue: 1), Color(red: 0.45, green: 0.52, blue: 0.95), Color(red: 0.73, green: 0.78, blue: 1)], center: .center))
                Circle().fill(Color(red: 0.11, green: 0.14, blue: 0.25)).padding(size * 0.045)
                ForEach(0..<wheelSegments.count, id: \.self) { index in
                    slice(index, size: size)
                }
                WheelBulbs(size: size)
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.2, height: size * 0.2)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                    .overlay(Image(systemName: "gift.fill").font(.system(size: size * 0.08)).foregroundStyle(ExamPalette.indigo))
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func slice(_ index: Int, size: CGFloat) -> some View {
        let count = Double(wheelSegments.count)
        let start = Angle.degrees(Double(index) * 360 / count - 90)
        let end = Angle.degrees(Double(index + 1) * 360 / count - 90)
        let radius = size / 2 - size * 0.06
        let color = wheelColors[index % wheelColors.count]
        let prize = wheelSegments[index]
        let isOffer = prize == "annual40"
        let amount = prize.replacingOccurrences(of: "credits", with: "")
        return ZStack {
            Path { path in
                let center = CGPoint(x: size / 2, y: size / 2)
                path.move(to: center)
                path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom))
            .overlay(
                Path { path in
                    let center = CGPoint(x: size / 2, y: size / 2)
                    path.move(to: center)
                    path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                    path.closeSubpath()
                }
                .stroke(Color(red: 0.11, green: 0.14, blue: 0.25), lineWidth: 2)
            )
            VStack(spacing: 0) {
                Text(isOffer ? "-40%" : "+\(amount)")
                    .font(.system(size: size * 0.07, weight: .heavy, design: .rounded))
                Text(isOffer ? "Premium" : copy.text("credits_short"))
                    .font(.system(size: size * 0.033, weight: .bold))
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .offset(y: -radius * 0.62)
            .rotationEffect(.degrees(Double(index) * 360 / count + 180 / count))
        }
        .frame(width: size, height: size)
    }
}

/// Marquee bulbs around the rim, alternating on and off.
private struct WheelBulbs: View {
    let size: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.45)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.45)
            ZStack {
                ForEach(0..<24, id: \.self) { index in
                    let lit = (index + tick) % 2 == 0
                    Circle()
                        .fill(lit ? Color(red: 1, green: 0.93, blue: 0.62) : Color.white.opacity(0.35))
                        .frame(width: size * 0.026, height: size * 0.026)
                        .shadow(color: lit ? Color(red: 1, green: 0.85, blue: 0.4).opacity(0.9) : .clear, radius: 4)
                        .offset(y: -(size / 2 - size * 0.024))
                        .rotationEffect(.degrees(Double(index) * 15))
                }
            }
        }
    }
}

/// A one-shot confetti burst.
private struct ConfettiBurst: View {
    private struct Piece { let angle: Double; let speed: Double; let spin: Double; let color: Color; let size: CGFloat }
    @State private var start = Date()
    private let pieces: [Piece] = (0..<70).map { _ in
        Piece(angle: .random(in: 0...(2 * .pi)), speed: .random(in: 180...420), spin: .random(in: -6...6),
              color: wheelColors.randomElement() ?? .white, size: .random(in: 6...11))
    }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSince(start)
                guard t < 2.6 else { return }
                let center = CGPoint(x: size.width / 2, y: size.height * 0.4)
                for piece in pieces {
                    let x = center.x + cos(piece.angle) * piece.speed * t
                    let y = center.y + sin(piece.angle) * piece.speed * t + 260 * t * t
                    var shape = canvas
                    shape.opacity = max(0, 1 - t / 2.6)
                    shape.translateBy(x: x, y: y)
                    shape.rotate(by: .radians(piece.spin * t))
                    shape.fill(Path(CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)), with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { start = Date() }
    }
}

/// Full-screen daily gift wheel. The server draws the prize; the wheel only animates to it.
private struct GiftWheelScreen: View {
    let copy: LocalizedCopy
    let onClose: () -> Void
    let onClaimOffer: () -> Void
    let onCreditsWon: () -> Void

    @StateObject private var engine = WheelEngine()
    @State private var spinning = false
    @State private var result: WheelResult?
    @State private var error: String?
    @State private var spunToday = OfferService.spunToday

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.20, blue: 0.38), Color(red: 0.07, green: 0.09, blue: 0.18)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [ExamPalette.indigo.opacity(0.45), .clear], center: .center, startRadius: 10, endRadius: 320)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .disabled(spinning)
                }
                Text(copy.text("gift_wheel_title"))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(copy.text("gift_wheel_subtitle"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                    .padding(.horizontal, 12)

                Spacer(minLength: 16)
                ZStack(alignment: .top) {
                    WheelFace(copy: copy)
                        .rotationEffect(.degrees(engine.angle))
                        .shadow(color: ExamPalette.indigo.opacity(0.6), radius: 30)
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(LinearGradient(colors: [.white, Color(red: 0.85, green: 0.88, blue: 1)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                        .rotationEffect(.degrees(engine.pointerKick), anchor: .top)
                        .offset(y: -14)
                }
                .padding(.horizontal, 22)
                Spacer(minLength: 16)

                if let error {
                    Text(error).font(.system(size: 13)).foregroundStyle(ExamPalette.coral).padding(.bottom, 8)
                }
                Button(action: spin) { spinLabel }
                .disabled(spinning || spunToday)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 22)

            if let result {
                ConfettiBurst()
                    .ignoresSafeArea()
                resultCard(result)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
    }

    private var spinLabel: some View {
        let dimmed = spinning || spunToday
        let key = spunToday && result == nil ? "wheel_come_back" : "spin"
        let gradient = LinearGradient(
            colors: [Color(red: 1, green: 0.72, blue: 0.25), Color(red: 0.96, green: 0.45, blue: 0.35)],
            startPoint: .leading, endPoint: .trailing
        )
        let title: Text = Text(copy.text(key))
            .font(Font.system(size: 18, weight: .heavy, design: .rounded))
        let glow: Color = Color(red: 0.96, green: 0.45, blue: 0.35).opacity(spunToday ? 0 : 0.5)
        return title
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background { gradient.opacity(dimmed ? 0.45 : 1.0) }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: glow, radius: 14, x: 0, y: 6)
    }

    private func spin() {
        guard !spinning, !spunToday else { return }
        spinning = true
        error = nil
        engine.windUp()
        Task { @MainActor in
            do {
                let won = try await OfferService.shared.spinWheel()
                engine.land(on: won.segment) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { result = won }
                    spinning = false
                    spunToday = true
                    AppServices.shared.analytics.event("wheel_spun", params: ["prize": won.prize])
                }
            } catch {
                engine.land(on: 0) { spinning = false }
                if OfferService.isAlreadySpun(error) {
                    spunToday = true
                    UserDefaults.standard.set(OfferService.localDay, forKey: "wheel.lastSpinDay")
                } else {
                    self.error = copy.text("wheel_error")
                }
            }
        }
    }

    private func resultCard(_ result: WheelResult) -> some View {
        let isOffer = result.credits == 0
        return VStack(spacing: 14) {
            Text(isOffer ? "🎉" : "⚡️").font(.system(size: 52))
            Text(isOffer ? copy.text("wheel_won_offer", variables: ["percent": "40"]) : copy.text("wheel_won_credits", variables: ["count": String(result.credits)]))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(ExamPalette.textPrimary)
            Text(copy.text(isOffer ? "wheel_offer_hint" : "wheel_credits_hint"))
                .font(.system(size: 14))
                .foregroundStyle(ExamPalette.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                isOffer ? onClaimOffer() : onCreditsWon()
            } label: {
                Text(copy.text(isOffer ? "claim_offer" : "awesome"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(ExamPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(ExamPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
        .padding(.horizontal, 28)
    }
}

/// Home card inviting the daily spin, with a slowly turning mini wheel.
private struct GiftWheelHomeCard: View {
    let copy: LocalizedCopy
    let spunToday: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: spunToday)) { context in
                    WheelFace(copy: copy)
                        .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate * 24))
                }
                .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(copy.text("gift_wheel_title"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    if spunToday {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let midnight = Calendar.current.startOfDay(for: context.date).addingTimeInterval(86_400)
                            let left = Int(midnight.timeIntervalSince(context.date))
                            Text(copy.text("next_spin_in", variables: ["time": String(format: "%02d:%02d:%02d", left / 3600, (left % 3600) / 60, left % 60)]))
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    } else {
                        Text(copy.text("gift_wheel_card_hint"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if !spunToday {
                    Text(copy.text("spin"))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Color(red: 0.16, green: 0.20, blue: 0.38))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(red: 1, green: 0.82, blue: 0.4))
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .background(
                LinearGradient(colors: [Color(red: 0.23, green: 0.29, blue: 0.48), Color(red: 0.36, green: 0.36, blue: 0.96)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Time-limited offer card with a live countdown (server-fixed expiry).
private struct TimedOfferHomeCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let colors: [Color]
    let expiresAt: Date
    let onTap: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .scaleEffect(pulse ? 1.08 : 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, Int(expiresAt.timeIntervalSince(context.date)))
                    Text(String(format: "%02d:%02d:%02d", left / 3600, (left % 3600) / 60, left % 60))
                        .font(.system(size: 13, weight: .heavy).monospacedDigit())
                        .foregroundStyle(colors.last ?? .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever()) { pulse = true }
        }
    }
}
