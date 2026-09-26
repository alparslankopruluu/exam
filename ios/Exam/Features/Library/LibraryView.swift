import SwiftUI

struct LibraryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Library")
                .font(.system(size: 28, weight: .bold))
            Text("Turn your own material into something you can study.")
                .font(.system(size: 13))
                .foregroundStyle(ExamPalette.textSecondary)
                .padding(.top, 3)

            Button {} label: {
                Label("Add material", systemImage: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ExamPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 20)

            VStack(spacing: 0) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(ExamPalette.primary)
                    .frame(width: 68, height: 68)
                    .background(ExamPalette.softBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text("Your study material lives here")
                    .font(.system(size: 18, weight: .bold))
                    .padding(.top, 16)

                Text("PDFs, photos, pasted text, audio and video can become summaries, flashcards and practice sets.")
                    .font(.system(size: 13))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 6)

                HStack(spacing: 8) {
                    formatChip("PDF")
                    formatChip("Photo")
                    formatChip("Audio")
                    formatChip("Video")
                }
                .padding(.top, 18)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .examCard(radius: 24)
            .padding(.top, 32)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func formatChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(ExamPalette.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(ExamPalette.background)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(ExamPalette.border, lineWidth: 1)
            }
    }
}
