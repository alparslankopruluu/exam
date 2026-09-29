import SwiftUI

struct PracticeView: View {
    let setup: StudySetup
    var onQuickPractice: () -> Void = {}
    var onMockExam: () -> Void = {}
    var onMistakes: () -> Void = {}
    var onFlashcards: () -> Void = {}
    var onCreatePractice: () -> Void = {}
    var onFocus: () -> Void = {}

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
                    Text(copy.text("your_exam"))
                        .font(.system(size: 18, weight: .bold))
                        .padding(.top, 22)

                    VStack(spacing: 8) {
                        ForEach(pack.units.prefix(4)) { unit in
                            practiceRow(
                                "book.fill",
                                unit.title,
                                detail(for: unit),
                                ExamPalette.primary,
                                onQuickPractice
                            )
                        }
                    }
                    .padding(.top, 9)
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
