import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @State private var importerPresented = false
    @State private var loading = false
    @State private var latestTitle: String?
    @State private var latestSummary: String?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Library")
                .font(.system(size: 28, weight: .bold))
            Text("Turn your own material into something you can study.")
                .font(.system(size: 13))
                .foregroundStyle(ExamPalette.textSecondary)
                .padding(.top, 3)

            Button {
                importerPresented = true
            } label: {
                HStack(spacing: 8) {
                    if loading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "plus")
                    }
                    Text(loading ? "Uploading & indexing…" : "Add material")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(ExamPalette.primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(loading)
            .padding(.top, 20)

            if let error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(ExamPalette.coral)
                    .padding(.top, 10)
            }

            if let latestTitle {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ExamPalette.mint)
                        Text(latestTitle)
                            .font(.system(size: 15, weight: .semibold))
                    }

                    if let latestSummary, !latestSummary.isEmpty {
                        Text(latestSummary)
                            .font(.system(size: 12))
                            .foregroundStyle(ExamPalette.textSecondary)
                            .lineLimit(5)
                    }

                    Text("Indexed · ready for summary, quiz, flashcards and Q&A")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ExamPalette.mint)
                }
                .padding(15)
                .examCard(radius: 18)
                .padding(.top, 18)
            }

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

                Text("PDFs, photos, pasted text, audio and video become searchable study context, summaries and practice sets.")
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
            .padding(.top, 24)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .fileImporter(
            isPresented: $importerPresented,
            allowedContentTypes: [.pdf, .image, .audio, .movie, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                loading = true
                error = nil

                Task { @MainActor in
                    do {
                        let uploaded = try await LibraryUploadService().uploadAndIndex(url: url)
                        latestTitle = uploaded.title
                        latestSummary = uploaded.summary
                    } catch {
                        self.error = error.localizedDescription
                    }
                    loading = false
                }

            case .failure(let error):
                self.error = error.localizedDescription
            }
        }
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
