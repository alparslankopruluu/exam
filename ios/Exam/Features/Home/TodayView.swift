import SwiftUI

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

struct TodayView: View {
    let setup: StudySetup
    @State private var selectedTab: ExamTab = .today
    @State private var premiumPlacement: String?
    @State private var quickPracticeOpen = false

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
                        }
                    }
                )
            } else if quickPracticeOpen {
                QuestionSessionView(
                    setup: setup,
                    onClose: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            quickPracticeOpen = false
                        }
                    }
                )
            } else {
                appShell
            }
        }
        .background(ExamPalette.background.ignoresSafeArea())
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
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                quickPracticeOpen = true
                            }
                        }
                    )
                case .tutor:
                    AITutorView(
                        setup: setup,
                        onVoiceTutor: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                premiumPlacement = "voice_tutor"
                            }
                        }
                    )
                case .library:
                    LibraryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
    }

    private var todayContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(copy.text("good_evening"))
                            .font(.system(size: 13))
                            .foregroundStyle(ExamPalette.textSecondary)
                        Text(copy.text("ready_small_win"))
                            .font(.system(size: 22, weight: .bold))
                    }
                    Spacer()
                    Image(systemName: "person.fill")
                        .foregroundStyle(ExamPalette.primary)
                        .frame(width: 42, height: 42)
                        .background(ExamPalette.softBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                HStack(spacing: 9) {
                    ExamStatPill(value: "7", label: copy.text("day_streak"), symbol: "flame.fill", accent: ExamPalette.amber)
                    ExamStatPill(value: setup.exam.shortName, label: copy.text("active_exam"), symbol: "graduationcap.fill", accent: ExamPalette.mint)
                    ExamStatPill(value: "61", label: copy.text("mastery"), symbol: "chart.xyaxis.line", accent: ExamPalette.purple)
                }
                .padding(.top, 20)

                Text(copy.text("todays_plan", variables: ["exam": setup.exam.shortName]).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.top, 24)

                hero.padding(.top, 9)

                Text(copy.text("next_up"))
                    .font(.system(size: 18, weight: .bold))
                    .padding(.top, 24)

                VStack(spacing: 8) {
                    nextRow(symbol: "checklist", title: copy.text("exam_style_questions"), subtitle: copy.text("questions_count", variables: ["count": "5"]), accent: ExamPalette.purple)
                    nextRow(symbol: "arrow.clockwise", title: copy.text("review_mistakes"), subtitle: copy.text("mistakes_count", variables: ["count": "3"]), accent: ExamPalette.coral)
                    nextRow(symbol: "sparkles", title: copy.text("ask_tutor"), subtitle: copy.text("explain_scan_practice"), accent: ExamPalette.purple)
                }
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
                Text("+80 XP")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.16))
                    .clipShape(Capsule())
            }

            Text(copy.text("core_practice"))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 24)
            Text(setup.exam.title)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.top, 2)

            Label("14 min", systemImage: "clock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 18)

            Button {
                quickPracticeOpen = true
            } label: {
                Text(copy.text("continue"))
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
    }

    private func nextRow(symbol: String, title: String, subtitle: String, accent: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(accent)
                .frame(width: 40, height: 40)
                .background(accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(ExamPalette.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(ExamPalette.textSecondary)
        }
        .padding(13)
        .examCard(radius: 17)
    }

    private func tabLabel(_ tab: ExamTab) -> String {
        switch tab {
        case .today: copy.text("today")
        case .practice: copy.text("practice")
        case .tutor: copy.text("ai_tutor")
        case .library: copy.text("library")
        }
    }

    private var bottomBar: some View {
        HStack {
            ForEach(ExamTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 20, weight: .semibold))
                        Text(tabLabel(tab))
                            .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? ExamPalette.primary : ExamPalette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
        .background(ExamPalette.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(ExamPalette.border).frame(height: 0.5)
        }
    }
}
