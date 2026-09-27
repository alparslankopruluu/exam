import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import FirebaseCore
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore

private struct CloudMaterial: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let mimeType: String
    let summary: String
}

struct LibraryView: View {
    let setup: StudySetup
    var onStartPractice: ([StudyQuestion]) -> Void = { _ in }
    var onPaywall: (String) -> Void = { _ in }

    @State private var importerPresented = false
    @State private var loading = false
    @State private var listLoading = false
    @State private var materials: [CloudMaterial] = []
    @State private var selected: CloudMaterial?
    @State private var error: String?

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    var body: some View {
        Group {
            if let selected {
                MaterialChatView(
                    setup: setup,
                    material: selected,
                    onBack: { self.selected = nil },
                    onStartPractice: onStartPractice,
                    onPaywall: onPaywall,
                    copy: copy
                )
            } else {
                libraryList
            }
        }
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
                        _ = try await LibraryUploadService().uploadAndIndex(url: url)
                        AppServices.shared.analytics.event(
                            AnalyticsEvent.materialAdded,
                            params: [
                                AnalyticsParam.examId: setup.exam.id,
                                AnalyticsParam.materialType: materialType(for: url)
                            ]
                        )
                        loadMaterials()
                    } catch {
                        let message = error.localizedDescription
                        if message.localizedCaseInsensitiveContains("material limit") {
                            onPaywall("document_limit")
                        } else if message.localizedCaseInsensitiveContains("Daily AI limit") {
                            onPaywall("ai_limit")
                        } else {
                            self.error = message
                        }
                    }
                    loading = false
                }
            case .failure(let error):
                self.error = error.localizedDescription
            }
        }
        .onAppear(perform: loadMaterials)
    }

    private var libraryList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(copy.text("library"))
                .font(.system(size: 28, weight: .bold))
            Text("Your PDFs, photos, audio, video and notes become searchable study context.")
                .font(.system(size: 13))
                .foregroundStyle(ExamPalette.textSecondary)
                .padding(.top, 3)

            Button {
                importerPresented = true
            } label: {
                HStack(spacing: 8) {
                    if loading { ProgressView().tint(.white) }
                    else { Image(systemName: "plus") }
                    Text(loading ? copy.text("uploading_indexing") : copy.text("add_material"))
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(ExamPalette.primary)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(loading)
            .padding(.top, 18)

            if let error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(ExamPalette.coral)
                    .padding(.top, 8)
            }

            if listLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            } else if materials.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(ExamPalette.primary)
                    Text(copy.text("no_materials"))
                        .font(.system(size: 18, weight: .bold))
                    Text(copy.text("material_empty_hint"))
                        .font(.system(size: 12))
                        .foregroundStyle(ExamPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .examCard(radius: 24)
                .padding(.top, 20)
            } else {
                Text(copy.text("your_materials"))
                    .font(.system(size: 18, weight: .bold))
                    .padding(.top, 20)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 9) {
                        ForEach(materials) { material in
                            Button {
                                AppServices.shared.analytics.event(
                                    AnalyticsEvent.materialOpened,
                                    params: [
                                        AnalyticsParam.examId: setup.exam.id,
                                        AnalyticsParam.materialType: material.mimeType.split(separator: "/").first.map(String.init) ?? "unknown"
                                    ]
                                )
                                selected = material
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: icon(for: material.mimeType))
                                        .foregroundStyle(ExamPalette.primary)
                                        .frame(width: 34)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(material.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(ExamPalette.textPrimary)
                                        Text(material.summary.isEmpty ? "Indexed and ready for Q&A" : material.summary)
                                            .font(.system(size: 11))
                                            .foregroundStyle(ExamPalette.textSecondary)
                                            .lineLimit(2)
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
                    .padding(.top, 8)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func loadMaterials() {
        guard FirebaseApp.app() != nil, let uid = Auth.auth().currentUser?.uid else { return }
        listLoading = true
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("materials")
            .getDocuments { snapshot, error in
                let rows: [CloudMaterial] = snapshot?.documents.map { doc in
                    let data = doc.data()
                    return CloudMaterial(
                        id: doc.documentID,
                        title: data["title"] as? String ?? "Study material",
                        mimeType: data["mimeType"] as? String ?? "application/octet-stream",
                        summary: data["summary"] as? String ?? ""
                    )
                }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending } ?? []

                DispatchQueue.main.async {
                    self.materials = rows
                    self.listLoading = false
                    if let error { self.error = error.localizedDescription }
                }
            }
    }

    private func materialType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "pdf"
        case "jpg", "jpeg", "png", "heic", "webp": return "image"
        case "mp3", "wav", "m4a", "aac": return "audio"
        case "mp4", "mov", "m4v": return "video"
        case "txt", "md": return "text"
        default: return "file"
        }
    }

    private func icon(for mime: String) -> String {
        if mime.hasPrefix("audio") { return "waveform" }
        if mime.hasPrefix("video") { return "film.fill" }
        if mime.hasPrefix("image") { return "photo.fill" }
        return "doc.fill"
    }
}

private struct MaterialChatView: View {
    let setup: StudySetup
    let material: CloudMaterial
    let onBack: () -> Void
    let onStartPractice: ([StudyQuestion]) -> Void
    let onPaywall: (String) -> Void
    let copy: LocalizedCopy

    @State private var question = ""
    @State private var answer: String?
    @State private var asking = false
    @State private var generating = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(ExamPalette.textPrimary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(material.title)
                        .font(.system(size: 20, weight: .bold))
                    Text("Answers are grounded in this material")
                        .font(.system(size: 11))
                        .foregroundStyle(ExamPalette.mint)
                }
                Spacer()
            }

            if !material.summary.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Summary").font(.system(size: 14, weight: .bold))
                    Text(material.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(ExamPalette.textSecondary)
                        .lineLimit(8)
                }
                .padding(14)
                .examCard(radius: 18)
                .padding(.top, 10)
            }

            HStack(spacing: 8) {
                quizButton(title: copy.text("quiz_me"), count: 5)
                quizButton(title: "10 questions", count: 10)
            }
            .padding(.top, 12)

            if let error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(ExamPalette.coral)
                    .padding(.top, 8)
            }

            if let answer {
                VStack(alignment: .leading, spacing: 5) {
                    Text("AI Tutor")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ExamPalette.purple)
                    Text(answer)
                        .font(.system(size: 13))
                        .lineSpacing(3)
                }
                .padding(14)
                .examCard(radius: 18)
                .padding(.top, 14)
            }

            Spacer()

            HStack(spacing: 8) {
                TextField(copy.text("ask_material"), text: $question, axis: .vertical)
                    .lineLimit(1...4)
                Button {
                    ask()
                } label: {
                    if asking { ProgressView() }
                    else { Image(systemName: "arrow.up.circle.fill").font(.system(size: 28)) }
                }
                .buttonStyle(.plain)
                .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || asking)
            }
            .padding(12)
            .examCard(radius: 18)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .background(ExamPalette.background.ignoresSafeArea())
    }

    private func quizButton(title: String, count: Int) -> some View {
        Button {
            generating = true
            error = nil
            Task { @MainActor in
                do {
                    let rows = try await AIGatewayClient().generateMaterialPractice(
                        materialId: material.id,
                        language: setup.languageCode,
                        count: count
                    )
                    let questions = rows.compactMap { row -> StudyQuestion? in
                        guard
                            let prompt = row["prompt"] as? String,
                            let options = row["options"] as? [String],
                            let correct = row["correctIndex"] as? Int,
                            options.indices.contains(correct)
                        else { return nil }
                        return StudyQuestion(
                            id: row["id"] as? String ?? "material_\(prompt.hashValue)",
                            topic: row["topic"] as? String ?? "Material",
                            prompt: prompt,
                            options: options,
                            correctIndex: correct,
                            explanation: row["explanation"] as? String ?? "Based on your study material."
                        )
                    }
                    if questions.isEmpty {
                        error = "Could not create a valid quiz from this material."
                    } else {
                        AppServices.shared.analytics.event(
                            AnalyticsEvent.quizGenerated,
                            params: [
                                AnalyticsParam.examId: setup.exam.id,
                                AnalyticsParam.source: "material",
                                AnalyticsParam.itemCount: questions.count
                            ]
                        )
                        onStartPractice(questions)
                    }
                } catch {
                    let message = error.localizedDescription
                    if message.localizedCaseInsensitiveContains("Daily AI limit") {
                        onPaywall("ai_limit")
                    } else {
                        self.error = message
                    }
                }
                generating = false
            }
        } label: {
            HStack {
                if generating { ProgressView() }
                else { Image(systemName: "questionmark.circle.fill") }
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(ExamPalette.softBlue)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(generating)
    }

    private func ask() {
        let value = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        asking = true
        error = nil
        AppServices.shared.analytics.event(
            AnalyticsEvent.materialQA,
            params: [
                AnalyticsParam.examId: setup.exam.id,
                AnalyticsParam.materialType: material.mimeType.split(separator: "/").first.map(String.init) ?? "unknown"
            ]
        )

        Task { @MainActor in
            do {
                answer = try await AIGatewayClient().askMaterial(
                    materialId: material.id,
                    question: value,
                    language: setup.languageCode
                )
                question = ""
            } catch {
                self.error = error.localizedDescription
            }
            asking = false
        }
    }
}
