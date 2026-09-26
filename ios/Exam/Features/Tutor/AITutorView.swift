import SwiftUI

struct AITutorView: View {
    let setup: StudySetup

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(ExamPalette.purple)
                            .frame(width: 48, height: 48)
                            .background(ExamPalette.softPurple)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("AI Tutor")
                                .font(.system(size: 27, weight: .bold))
                            Text("Context-aware for \(setup.exam.shortName)")
                                .font(.system(size: 12))
                                .foregroundStyle(ExamPalette.textSecondary)
                        }
                    }

                    Text("What do you need help with?")
                        .font(.system(size: 18, weight: .bold))
                        .padding(.top, 24)

                    VStack(spacing: 9) {
                        tutorRow("doc.viewfinder", "Solve a question", "Take a photo or upload", ExamPalette.primary)
                        tutorRow("lightbulb.fill", "Explain a concept", "Simple, visual or from zero", ExamPalette.amber)
                        tutorRow("folder.fill", "Study my notes", "Ask questions about your materials", ExamPalette.mint)
                        tutorRow("waveform", "Talk to tutor", "Practice with voice", ExamPalette.purple)
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            HStack(spacing: 6) {
                Button {} label: {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(ExamPalette.textSecondary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                Text("Ask anything…")
                    .font(.system(size: 14))
                    .foregroundStyle(ExamPalette.textSecondary)

                Spacer()

                Button {} label: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(ExamPalette.purple)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                Button {} label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(ExamPalette.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .examCard(radius: 20)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }

    private func tutorRow(_ symbol: String, _ title: String, _ subtitle: String, _ accent: Color) -> some View {
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
