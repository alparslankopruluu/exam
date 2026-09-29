import SwiftUI
import PhotosUI

struct AITutorView: View {
    let setup: StudySetup
    var onVoiceTutor: () -> Void = {}
    var onStudyNotes: () -> Void = {}
    var onMediaLab: () -> Void = {}
    var onPaywall: (String) -> Void = { _ in }

    @State private var prompt = ""
    @State private var answer: String?
    @State private var error: String?
    @State private var loading = false
    @State private var photoItem: PhotosPickerItem?

    private let scanner = QuestionScanner()

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

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
                            Text(copy.text("ai_tutor"))
                                .font(.system(size: 27, weight: .bold))
                            Text(copy.text("tutor_context", variables: ["exam": setup.exam.shortName]))
                                .font(.system(size: 12))
                                .foregroundStyle(ExamPalette.textSecondary)
                        }
                    }

                    Text(copy.text("what_help"))
                        .font(.system(size: 18, weight: .bold))
                        .padding(.top, 24)

                    VStack(spacing: 9) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            TutorActionRowContent(
                                symbol: "doc.viewfinder",
                                title: copy.text("solve_question"),
                                subtitle: copy.text("solve_question_hint"),
                                accent: ExamPalette.primary
                            )
                        }
                        .buttonStyle(.plain)

                        tutorRow(
                            "lightbulb.fill",
                            copy.text("explain_concept"),
                            copy.text("explain_concept_hint"),
                            ExamPalette.amber
                        ) {
                            prompt = "Explain this concept simply: "
                        }

                        tutorRow(
                            "folder.fill",
                            copy.text("study_notes"),
                            copy.text("study_notes_hint"),
                            ExamPalette.mint,
                            action: onStudyNotes
                        )

                        tutorRow(
                            "photo.on.rectangle.angled",
                            copy.text("visual_explanation"),
                            copy.text("visual_explanation_hint"),
                            ExamPalette.primary,
                            action: onMediaLab
                        )

                        tutorRow(
                            "waveform",
                            copy.text("talk_tutor"),
                            copy.text("talk_tutor_hint"),
                            ExamPalette.purple
                        ) {
                            AppServices.shared.analytics.event(
                                AnalyticsEvent.voiceTutorStarted,
                                params: [AnalyticsParam.examId: setup.exam.id]
                            )
                            onVoiceTutor()
                        }
                    }
                    .padding(.top, 12)

                    if loading || answer != nil || error != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            if loading {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text(copy.text("tutor_working"))
                                        .foregroundStyle(ExamPalette.textSecondary)
                                }
                            }

                            if let answer {
                                Text(copy.text("tutor_label"))
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

                TextField(copy.text("ask_anything"), text: $prompt, axis: .vertical)
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
        .task {
            AppServices.shared.analytics.event(
                AnalyticsEvent.aiTutorStarted,
                params: [
                    AnalyticsParam.examId: setup.exam.id,
                    AnalyticsParam.contentPackId: setup.exam.syllabusPackId
                ]
            )
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

        AppServices.shared.analytics.event(
            AnalyticsEvent.aiMessageSent,
            params: [
                AnalyticsParam.examId: setup.exam.id,
                AnalyticsParam.source: "text"
            ]
        )

        Task { @MainActor in
            do {
                answer = try await AIGatewayClient().askTutor(
                    setup: setup,
                    message: message
                )
                prompt = ""
            } catch {
                let message = error.localizedDescription
                if message.localizedCaseInsensitiveContains("Daily AI limit") {
                    onPaywall("ai_limit")
                } else {
                    self.error = message
                }
            }
            loading = false
        }
    }

    private func solvePhoto(_ item: PhotosPickerItem) {
        loading = true
        answer = nil
        error = nil
        AppServices.shared.analytics.event(
            AnalyticsEvent.scanStarted,
            params: [
                AnalyticsParam.examId: setup.exam.id,
                AnalyticsParam.source: "photo_picker"
            ]
        )

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
                AppServices.shared.analytics.event(
                    AnalyticsEvent.scanCompleted,
                    params: [
                        AnalyticsParam.examId: setup.exam.id,
                        AnalyticsParam.source: "photo_picker"
                    ]
                )
            } catch {
                let message = error.localizedDescription
                if message.localizedCaseInsensitiveContains("Daily AI limit") {
                    onPaywall("ai_limit")
                } else {
                    self.error = message
                }
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
