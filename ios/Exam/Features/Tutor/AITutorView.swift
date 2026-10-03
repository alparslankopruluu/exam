import SwiftUI
import PhotosUI
import AVFoundation

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
    @State private var scanning = false

    private let scanner = QuestionScanner()

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 4) {
                        TutorMascot()
                            .frame(width: 128, height: 128)
                        Text(copy.text("ai_tutor"))
                            .font(.system(size: 27, weight: .bold))
                        Text(copy.text("tutor_context", variables: ["exam": setup.exam.shortName]))
                            .font(.system(size: 13))
                            .foregroundStyle(ExamPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    Text(copy.text("what_help"))
                        .font(.system(size: 18, weight: .bold))
                        .padding(.top, 24)

                    VStack(spacing: 9) {
                        Button {
                            scanning = true
                        } label: {
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
        .fullScreenCover(isPresented: $scanning) {
            ScanQuestionView(copy: copy, onClose: { scanning = false }) { data in
                scanning = false
                solveCapture(data)
            }
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
                try await solveImage(data, source: "photo_picker")
            } catch {
                handle(error)
            }
            loading = false
            photoItem = nil
        }
    }

    private func solveCapture(_ data: Data) {
        loading = true
        answer = nil
        error = nil
        AppServices.shared.analytics.event(
            AnalyticsEvent.scanStarted,
            params: [AnalyticsParam.examId: setup.exam.id, AnalyticsParam.source: "camera"]
        )
        Task { @MainActor in
            do {
                try await solveImage(data, source: "camera")
            } catch {
                handle(error)
            }
            loading = false
        }
    }

    private func handle(_ error: Error) {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("Daily AI limit") {
            onPaywall("ai_limit")
        } else {
            self.error = message
        }
    }

    private func solveImage(_ data: Data, source: String) async throws {
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
                AnalyticsParam.source: source
            ]
        )
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

/// The tutor robot (design/illustrations/tutor_bot.svg) floating gently.
struct TutorMascot: View {
    @State private var floating = false

    var body: some View {
        Image("tutor_bot")
            .resizable()
            .scaledToFit()
            .offset(y: floating ? -5 : 5)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { floating = true }
            }
    }
}

/// "Scan a question": live camera with a framing guide, a Scan/Gallery switch and a shutter.
private struct ScanQuestionView: View {
    let copy: LocalizedCopy
    let onClose: () -> Void
    let onImage: (Data) -> Void

    @StateObject private var camera = QuestionCamera()
    @State private var galleryItem: PhotosPickerItem?
    @State private var galleryMode = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: camera.session)
                .ignoresSafeArea()
                .opacity(camera.authorized ? 1 : 0)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                    Text(copy.text("scan_title"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()
                ScanFrame()
                    .frame(width: 290, height: 220)
                Text(copy.text(camera.authorized ? "scan_hint" : "scan_camera_denied"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.top, 18)
                    .padding(.horizontal, 32)
                Spacer()

                VStack(spacing: 22) {
                    HStack(spacing: 4) {
                        modeButton(copy.text("scan_mode"), selected: !galleryMode) { galleryMode = false }
                        PhotosPicker(selection: $galleryItem, matching: .images) {
                            modeLabel(copy.text("gallery"), selected: galleryMode)
                        }
                    }
                    .padding(4)
                    .background(.white.opacity(0.14))
                    .clipShape(Capsule())

                    Button {
                        camera.capture { data in onImage(data) }
                    } label: {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 76, height: 76)
                            .overlay(Circle().fill(.white).padding(8))
                    }
                    .disabled(!camera.authorized)
                    .opacity(camera.authorized ? 1 : 0.4)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.55).ignoresSafeArea(edges: .bottom))
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: galleryItem) { _, item in
            guard let item else { return }
            galleryMode = true
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self) { onImage(data) }
                galleryItem = nil
            }
        }
    }

    private func modeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { modeLabel(title, selected: selected) }
    }

    private func modeLabel(_ title: String, selected: Bool) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(selected ? ExamPalette.textPrimary : .white)
            .frame(width: 104, height: 36)
            .background(selected ? Color.white : .clear)
            .clipShape(Capsule())
    }
}

/// Four rounded corner brackets marking where the question should sit.
private struct ScanFrame: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height, arm: CGFloat = 34, r: CGFloat = 18
            Path { path in
                path.move(to: CGPoint(x: 0, y: arm)); path.addLine(to: CGPoint(x: 0, y: r))
                path.addQuadCurve(to: CGPoint(x: r, y: 0), control: .zero); path.addLine(to: CGPoint(x: arm, y: 0))
                path.move(to: CGPoint(x: w - arm, y: 0)); path.addLine(to: CGPoint(x: w - r, y: 0))
                path.addQuadCurve(to: CGPoint(x: w, y: r), control: CGPoint(x: w, y: 0)); path.addLine(to: CGPoint(x: w, y: arm))
                path.move(to: CGPoint(x: w, y: h - arm)); path.addLine(to: CGPoint(x: w, y: h - r))
                path.addQuadCurve(to: CGPoint(x: w - r, y: h), control: CGPoint(x: w, y: h)); path.addLine(to: CGPoint(x: w - arm, y: h))
                path.move(to: CGPoint(x: arm, y: h)); path.addLine(to: CGPoint(x: r, y: h))
                path.addQuadCurve(to: CGPoint(x: 0, y: h - r), control: CGPoint(x: 0, y: h)); path.addLine(to: CGPoint(x: 0, y: h - arm))
            }
            .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Back camera session with photo capture; reports JPEG data.
private final class QuestionCamera: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    @Published var authorized = false

    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "question.camera")
    private var configured = false
    private var completion: ((Data) -> Void)?

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { self.authorized = granted }
            guard granted else { return }
            self.queue.async {
                self.configureIfNeeded()
                if !self.session.isRunning { self.session.startRunning() }
            }
        }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    func capture(_ completion: @escaping (Data) -> Void) {
        self.completion = completion
        queue.async {
            guard self.session.isRunning else { return }
            self.output.capturePhoto(with: AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg]), delegate: self)
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        DispatchQueue.main.async { self.completion?(data) }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

