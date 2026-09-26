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

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .today:
                    todayContent
                case .practice:
                    PracticeView(setup: setup)
                case .tutor:
                    AITutorView(setup: setup)
                case .library:
                    LibraryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
        .background(ExamPalette.background.ignoresSafeArea())
    }

    private var todayContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Good evening")
                            .font(.system(size: 13))
                            .foregroundStyle(ExamPalette.textSecondary)
                        Text("Ready for a small win? 👋")
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
                    ExamStatPill(value: "7", label: "day streak", symbol: "flame.fill", accent: ExamPalette.amber)
                    ExamStatPill(value: setup.exam.shortName, label: "active exam", symbol: "graduationcap.fill", accent: ExamPalette.mint)
                    ExamStatPill(value: "61", label: "mastery", symbol: "chart.xyaxis.line", accent: ExamPalette.purple)
                }
                .padding(.top, 20)

                Text("TODAY'S \(setup.exam.shortName.uppercased()) PLAN")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.top, 24)

                hero.padding(.top, 9)

                Text("Next up")
                    .font(.system(size: 18, weight: .bold))
                    .padding(.top, 24)

                VStack(spacing: 8) {
                    nextRow(symbol: "checklist", title: "Exam-style questions", subtitle: "5 questions", accent: ExamPalette.purple)
                    nextRow(symbol: "arrow.clockwise", title: "Review mistakes", subtitle: "3 mistakes", accent: ExamPalette.coral)
                    nextRow(symbol: "sparkles", title: "Ask your tutor", subtitle: "Explain, scan or practice anything", accent: ExamPalette.purple)
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

            Text("Core practice")
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

            Button {} label: {
                Text("Continue")
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
                        Text(tab.rawValue)
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
