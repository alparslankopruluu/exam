import SwiftUI
import PhotosUI

struct AITutorView: View {
    let setup: StudySetup
    var onVoiceTutor: () -> Void = {}
    var onStudyNotes: () -> Void = {}

    @State private var prompt = ""
    @State private var answer: String?
    @State private var error: String?
    @State private var loading = false
    @State private var photoItem: PhotosPickerItem?

    private let scanner = QuestionScanner()

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
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            TutorActionRowContent(
                                symbol: "doc.viewfinder",
                                title: "Solve a question",
                                subtitle: "Upload a photo · OCR + vision",
                                accent: ExamPalette.primary
                            )
                        }
                        .buttonStyle(.plain)

                        tutorRow(
                            "lightbulb.fill",
                            "Explain a concept",
                            "Simple, visual or from zero",
                            ExamPalette.amber
                        ) {
                            prompt = "Explain this concept simply: "
                        }

                        tutorRow(
                            "folder.fill",
                            "Study my notes",
                            "Ask questions from indexed Library materials",
                            ExamPalette.mint,
                            action: onStudyNotes
                        )

                        tutorRow(
                            "waveform",
                            "Talk to tutor",
                            "Interactive voice · Premium",
                            ExamPalette.purple,
                            action: onVoiceTutor
                        )
                    }
                    .padding(.top, 12)

                    if loading || answer != nil || error != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            if loading {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text("Tutor is working…")
                                        .foregroundStyle(ExamPalette.textSecondary)
                                }
                            }

                            if let answer {
                                Text("Tutor")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(ExamPalette.purple)
                                Text(answer)
                                    .font(.system(size: 13))
                                    .lineSpacing(3)
                            }

                            if let error {
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundStyle(ExamPalette.coral)
                            }
                        }
                        .padding(15)
                        .examCard(radius: 18)
                        .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            HStack(spacing: 6) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(ExamPalette.textSecondary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                TextField("Ask anything…", text: $prompt, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(1...3)

                Button(action: onVoiceTutor) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(ExamPalette.purple)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                Button {
                    sendPrompt()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? ExamPalette.border
                            : ExamPalette.primary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loading)
            }
            .padding(10)
            .examCard(radius: 20)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            solvePhoto(newItem)
        }
    }

    @ViewBuilder
    private func tutorRow(
        _ symbol: String,
        _ title: String,
        _ subtitle: String,
        _ accent: Color,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            TutorActionRowContent(
                symbol: symbol,
                title: title,
                subtitle: subtitle,
                accent: accent
            )
        }
        .buttonStyle(.plain)
    }

    private func sendPrompt() {
        let message = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !loading else { return }

        loading = true
        answer = nil
        error = nil

        Task { @MainActor in
            do {
                answer = try await AIGatewayClient().askTutor(
                    setup: setup,
                    message: message
                )
                prompt = ""
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    private func solvePhoto(_ item: PhotosPickerItem) {
        loading = true
        answer = nil
        error = nil

        Task { @MainActor in
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw AIGatewayError.message("Could not load the selected image.")
                }

                let extracted = try scanner.recognize(
                    imageData: data,
                    languageCode: setup.languageCode
                )

                let dataURL = "data:image/jpeg;base64," + data.base64EncodedString()

                answer = try await AIGatewayClient().solveQuestion(
                    setup: setup,
                    extractedText: extracted.isEmpty ? nil : extracted,
                    imageDataURL: dataURL
                )
            } catch {
                self.error = error.localizedDescription
            }

            loading = false
            photoItem = nil
        }
    }
}


private struct TutorActionRowContent: View {
    let symbol: String
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
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
}
