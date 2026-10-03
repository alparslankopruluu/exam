import SwiftUI

struct PracticeView: View {
    let setup: StudySetup
    var onQuickPractice: () -> Void = {}
    var onMockExam: () -> Void = {}
    var onMistakes: () -> Void = {}
    var onFlashcards: () -> Void = {}
    var onCreatePractice: () -> Void = {}
    var onFocus: () -> Void = {}
    var onLibrary: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var unitMastery: [Int?] = []
    @State private var lessonUnit: ContentUnit?

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    private var pack: ExamContentPack? {
        ContentPackRepository.load(packId: setup.exam.syllabusPackId)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(copy.text("practice"))
                    .font(.system(size: 28, weight: .bold))
                Text(copy.text("practice_pack_hint", variables: ["exam": setup.exam.shortName]))
                    .font(.system(size: 13))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(.white.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Spacer()
                        Text(copy.text("minutes_short", variables: ["count": "5"]).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Text(copy.text("quick_practice"))
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 22)
                    Text(copy.text("quick_practice_hint"))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.top, 3)

                    Button(action: onQuickPractice) {
                        Text(copy.text("start_questions", variables: ["count": "5"]))
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
                .padding(.top, 22)

                if let pack, !pack.units.isEmpty {
                    Text(copy.text("learning_path"))
                        .font(.system(size: 18, weight: .bold))
                        .padding(.top, 22)
                    MasteryLegend(copy: copy)
                        .padding(.top, 8)
                    MasteryPath(
                        units: pack.units,
                        mastery: unitMastery,
                        copy: copy,
                        onSelect: { lessonUnit = $0 }
                    )
                    .padding(.top, 6)
                }

                VStack(spacing: 9) {
                    practiceRow("timer", copy.text("mock_exam"), copy.text("mock_exam_hint"), ExamPalette.purple, onMockExam)
                    practiceRow("arrow.clockwise", copy.text("mistakes"), copy.text("mistakes_hint"), ExamPalette.coral, onMistakes)
                    practiceRow("rectangle.stack.fill", copy.text("flashcards"), copy.text("flashcards_hint"), ExamPalette.mint, onFlashcards)
                    practiceRow("sparkles", copy.text("create_practice"), copy.text("create_practice_hint"), ExamPalette.amber, onCreatePractice)
                    practiceRow("scope", copy.text("focus"), copy.text("focus_hint"), ExamPalette.primary, onFocus)
                }
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .fullScreenCover(item: $lessonUnit) { unit in
            LessonView(
                setup: setup,
                unit: unit,
                copy: copy,
                onClose: { lessonUnit = nil },
                onPractice: { lessonUnit = nil; onQuickPractice() },
                onLibrary: { lessonUnit = nil; onLibrary() }
            )
        }
        .onAppear {
            let titles = pack?.units.map(\.title) ?? []
            unitMastery = (try? LearningStore(context: modelContext).sectionMastery(examId: setup.exam.id, sectionTitles: titles)) ?? []
            if ScreenshotMode.isActive {
                unitMastery = titles.indices.map { [86, 64, 38, nil, nil, nil][$0 % 6] }
            }
        }
    }

    private func detail(for unit: ContentUnit) -> String {
        var parts: [String] = []
        if let questionCount = unit.questionCount {
            parts.append(copy.text("questions_count", variables: ["count": String(questionCount)]))
        }
        if let durationMinutes = unit.durationMinutes {
            parts.append(copy.text("minutes_short", variables: ["count": String(durationMinutes)]))
        }
        return parts.isEmpty ? copy.text("exam_specific_practice") : parts.joined(separator: " · ")
    }

    private func practiceRow(
        _ symbol: String,
        _ title: String,
        _ subtitle: String,
        _ accent: Color,
        _ action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(accent.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            .padding(14)
            .examCard(radius: 18)
        }
        .buttonStyle(.plain)
    }
}

/// Where a pack section stands on the learning path.
enum MasteryStatus: CaseIterable {
    case mastered, learning, review, notStarted

    init(percent: Int?) {
        guard let percent else { self = .notStarted; return }
        self = percent >= 80 ? .mastered : percent < 50 ? .review : .learning
    }

    var color: Color {
        switch self {
        case .mastered: ExamPalette.mint
        case .learning: ExamPalette.amber
        case .review: ExamPalette.coral
        case .notStarted: ExamPalette.border
        }
    }

    var key: String {
        switch self {
        case .mastered: "status_mastered"
        case .learning: "status_learning"
        case .review: "status_review"
        case .notStarted: "status_not_started"
        }
    }
}

private struct MasteryLegend: View {
    let copy: LocalizedCopy

    var body: some View {
        HStack(spacing: 12) {
            ForEach(MasteryStatus.allCases, id: \.self) { status in
                HStack(spacing: 5) {
                    Circle().fill(status.color).frame(width: 9, height: 9)
                    Text(copy.text(status.key))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ExamPalette.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// Pack sections as a zig-zag path of nodes joined by a dashed trail.
private struct MasteryPath: View {
    let units: [ContentUnit]
    let mastery: [Int?]
    let copy: LocalizedCopy
    let onSelect: (ContentUnit) -> Void

    private let rowHeight: CGFloat = 104

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let points = units.indices.map { point($0, width: width) }
            ZStack(alignment: .topLeading) {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for (previous, next) in zip(points, points.dropFirst()) {
                        let midY = (previous.y + next.y) / 2
                        path.addCurve(to: next, control1: CGPoint(x: previous.x, y: midY), control2: CGPoint(x: next.x, y: midY))
                    }
                }
                .stroke(ExamPalette.border, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 10]))

                ForEach(Array(units.enumerated()), id: \.element.id) { index, unit in
                    let percent = mastery.indices.contains(index) ? mastery[index] : nil
                    let status = MasteryStatus(percent: percent)
                    let left = index % 2 == 0
                    Button { onSelect(unit) } label: {
                        HStack(spacing: 12) {
                            if !left { label(unit, percent: percent, status: status, alignment: .trailing) }
                            ZStack {
                                Circle()
                                    .fill(status == .notStarted ? ExamPalette.surface : status.color.opacity(0.16))
                                    .overlay(Circle().stroke(status.color, lineWidth: 3))
                                Image(systemName: status == .mastered ? "checkmark" : status == .notStarted ? "lock.open.fill" : "book.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(status == .notStarted ? ExamPalette.textSecondary : status.color)
                            }
                            .frame(width: 62, height: 62)
                            if left { label(unit, percent: percent, status: status, alignment: .leading) }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: width * 0.86, alignment: left ? .leading : .trailing)
                    .position(x: left ? width * 0.43 : width * 0.57, y: points[index].y)
                }
            }
        }
        .frame(height: CGFloat(units.count) * rowHeight)
    }

    private func point(_ index: Int, width: CGFloat) -> CGPoint {
        // Nodes (62pt) hug the left and right edges alternately.
        let x = index % 2 == 0 ? 31 : width - 31
        return CGPoint(x: x, y: rowHeight * CGFloat(index) + rowHeight / 2)
    }

    private func label(_ unit: ContentUnit, percent: Int?, status: MasteryStatus, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(unit.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ExamPalette.textPrimary)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                .lineLimit(2)
            Text(percent.map { "\(copy.text(status.key)) · \($0)%" } ?? copy.text(status.key))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(status == .notStarted ? ExamPalette.textSecondary : status.color)
        }
    }
}

/// A topic page from the learning path: Learn (an AI explainer, cached per topic),
/// Practice and Notes tabs.
private struct LessonView: View {
    let setup: StudySetup
    let unit: ContentUnit
    let copy: LocalizedCopy
    let onClose: () -> Void
    let onPractice: () -> Void
    let onLibrary: () -> Void

    private enum Tab: CaseIterable { case learn, practice, notes }

    @State private var tab: Tab = .learn
    @State private var lesson: String?
    @State private var error: String?

    private var cacheKey: String { "lesson.\(setup.exam.id).\(setup.languageCode).\(unit.id)" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ExamPalette.textPrimary)
                        .frame(width: 40, height: 40)
                }
                Text(unit.title)
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(1)
                Spacer()
            }

            HStack(spacing: 4) {
                ForEach(Tab.allCases, id: \.self) { item in
                    Button { tab = item } label: {
                        Text(copy.text(item == .learn ? "tab_learn" : item == .practice ? "practice" : "tab_notes"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tab == item ? ExamPalette.primary : ExamPalette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(tab == item ? ExamPalette.surface : .clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(ExamPalette.border.opacity(0.6))
            .clipShape(Capsule())
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    switch tab {
                    case .learn: learnTab
                    case .practice: actionTab(image: "focus_scene", text: copy.text("lesson_practice_hint", variables: ["topic": unit.title]),
                                              button: copy.text("start_questions", variables: ["count": "5"]), action: onPractice)
                    case .notes: actionTab(image: "calendar", text: copy.text("lesson_notes_hint"),
                                           button: copy.text("open_library"), action: onLibrary)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 20)
        .background(ExamPalette.background.ignoresSafeArea())
        .task { await loadLesson() }
    }

    private var learnTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image("hero_student")
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(ExamPalette.softBlue)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            if let lesson {
                Text(LocalizedStringKey(lesson))
                    .font(.system(size: 15))
                    .foregroundStyle(ExamPalette.textPrimary)
                    .lineSpacing(4)
                    .padding(16)
                    .examCard(radius: 20)
            } else if let error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(ExamPalette.coral)
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(copy.text("lesson_loading"))
                        .font(.system(size: 14))
                        .foregroundStyle(ExamPalette.textSecondary)
                }
                .padding(16)
            }
            Button(action: onPractice) {
                Text(copy.text("start_questions", variables: ["count": "5"]))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ExamPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func actionTab(image: String, text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Image(image)
                .resizable()
                .scaledToFill()
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(ExamPalette.textSecondary)
                .multilineTextAlignment(.center)
            Button(action: action) {
                Text(button)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ExamPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    @MainActor
    private func loadLesson() async {
        if let cached = UserDefaults.standard.string(forKey: cacheKey) {
            lesson = cached
            return
        }
        do {
            let text = try await AIGatewayClient().askTutor(
                setup: setup,
                message: "Teach the topic \"\(unit.title)\" for the \(setup.exam.shortName) exam as a short lesson: "
                    + "a two-sentence overview, then 4 key points as a bulleted list, then one worked example. Use **bold** for key terms."
            )
            lesson = text
            UserDefaults.standard.set(text, forKey: cacheKey)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

