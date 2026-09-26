import SwiftUI

struct PracticeView: View {
    let setup: StudySetup

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Practice")
                    .font(.system(size: 28, weight: .bold))
                Text("Built around your \(setup.exam.shortName) content pack")
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
                        Text("5 MIN")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Text("Quick Practice")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 22)
                    Text("A short adaptive set from what matters most right now.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.top, 3)

                    Button {} label: {
                        Text("Start 5 questions")
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

                VStack(spacing: 9) {
                    practiceRow("timer", "Mock Exam", "Use the official-style blueprint", ExamPalette.purple)
                    practiceRow("arrow.clockwise", "Mistakes", "Review patterns that cost you points", ExamPalette.coral)
                    practiceRow("rectangle.stack.fill", "Flashcards", "Spaced repetition due today", ExamPalette.mint)
                    practiceRow("sparkles", "Create Practice", "Topic, note, PDF or pasted text", ExamPalette.amber)
                }
                .padding(.top, 22)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    private func practiceRow(_ symbol: String, _ title: String, _ subtitle: String, _ accent: Color) -> some View {
        Button {} label: {
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
