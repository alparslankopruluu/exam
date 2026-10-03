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

                let expiry = AppServices.shared.flags.snapshot.limitedOfferExpiryEpochSeconds
                if expiry > Int64(Date().timeIntervalSince1970) {
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
