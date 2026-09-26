import SwiftUI
import SwiftData

struct QuestionSessionView: View {
    let setup: StudySetup
    let onClose: () -> Void
    var questionsOverride: [StudyQuestion]? = nil
    var sessionType: String = "quick_practice"
    var onSessionCompleted: (() -> Void)? = nil
    var onPaywall: (String) -> Void = { _ in }
    var timeLimitSeconds: Int? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var sessionStartedAt = Date()
    @State private var questionStartedAt = Date()
    @State private var index = 0
    @State private var selected: Int?
    @State private var correctCount = 0
    @State private var completed = false
    @State private var earnedXP = 0
    @State private var simplerExplanation: String?
    @State private var tutorAnswer: String?
    @State private var helperLoading = false
    @State private var remainingSeconds = 0

    private var questions: [StudyQuestion] {
        if let questionsOverride, !questionsOverride.isEmpty {
            return questionsOverride
        }
        return SampleQuestionFactory.questions(for: setup)
    }

    var body: some View {
        Group {
            if completed {
                completeView
            } else {
                questionView
            }
        }
        .task(id: timeLimitSeconds) {
            guard let limit = timeLimitSeconds, !completed else { return }
            if remainingSeconds <= 0 {
                remainingSeconds = limit
            }
            while remainingSeconds > 0 && !completed {
                try? await Task.sleep(for: .seconds(1))
                if !completed { remainingSeconds -= 1 }
            }
            if remainingSeconds <= 0 && !completed {
                finishSession()
            }
        }
    }

    private var questionView: some View {
        let question = questions[index]

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(ExamPalette.textPrimary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ExamPalette.border)
                        Capsule()
                            .fill(ExamPalette.primary)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 6)

                if timeLimitSeconds != nil {
                    Text(String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(remainingSeconds <= 60 ? ExamPalette.coral : ExamPalette.textSecondary)
                }

                Text("\(index + 1)/\(questions.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ExamPalette.textSecondary)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(question.topic.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ExamPalette.primary)
                        .padding(.top, 28)

                    Text(question.prompt)
                        .font(.system(size: 24, weight: .bold))
                        .lineSpacing(4)
                        .padding(.top, 10)

                    VStack(spacing: 10) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { optionIndex, option in
                            optionRow(question: question, index: optionIndex, option: option)
                        }
                    }
                    .padding(.top, 24)

                    if selected != nil {
                        feedbackCard(question)
                            .padding(.top, 18)
                    }
                }
            }

            if selected != nil {
                Button {
                    if index == questions.count - 1 {
                        finishSession()
                    } else {
                        index += 1
                        selected = nil
                        simplerExplanation = nil
                        tutorAnswer = nil
                        questionStartedAt = Date()
                    }
                } label: {
                    Text(index == questions.count - 1 ? "Finish session" : "Next question")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(ExamPalette.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(ExamPalette.background.ignoresSafeArea())
    }

    @MainActor
    private func finishSession() {
        guard !completed else { return }
        let completedAt = Date()
        try? LearningStore(context: modelContext).saveSession(
            examId: setup.exam.id,
            sessionType: sessionType,
            startedAt: sessionStartedAt,
            completedAt: completedAt,
            correctCount: correctCount,
            totalCount: questions.count
        )
        let before = UserProgressStore().snapshot()
        let after = UserProgressStore().recordSession(
            correct: correctCount,
            total: questions.count,
            durationSeconds: max(0, Int(completedAt.timeIntervalSince(sessionStartedAt)))
        )
        earnedXP = max(0, after.xp - before.xp)
        onSessionCompleted?()
        completed = true
    }

    private var progress: CGFloat {
        CGFloat(index + (selected == nil ? 0 : 1)) / CGFloat(max(questions.count, 1))
    }

    private func optionRow(question: StudyQuestion, index optionIndex: Int, option: String) -> some View {
        let isSelected = selected == optionIndex
        let isCorrect = selected != nil && optionIndex == question.correctIndex

        let border: Color = {
            if isCorrect { ExamPalette.mint }
            if isSelected { ExamPalette.coral }
            return ExamPalette.border
        }()

        let background: Color = {
            if isCorrect { ExamPalette.softMint }
            if isSelected { ExamPalette.coral.opacity(0.08) }
            return ExamPalette.surface
        }()

        return Button {
            guard selected == nil else { return }
            let answeredAt = Date()
            let correct = optionIndex == question.correctIndex
            selected = optionIndex
            if correct {
                correctCount += 1
            }

            let skillId = setup.exam.id + ":" + question.topic
                .lowercased()
                .replacingOccurrences(of: " ", with: "_")

            try? LearningStore(context: modelContext).recordAnswer(
                examId: setup.exam.id,
                skillId: skillId,
                questionId: question.id,
                correct: correct,
                responseTimeMs: max(0, Int(answeredAt.timeIntervalSince(questionStartedAt) * 1000)),
                selectedAnswer: option,
                correctAnswer: question.options[question.correctIndex],
                errorType: correct ? "none" : "concept"
            )
        } label: {
            HStack(spacing: 10) {
                Text(String(UnicodeScalar(65 + optionIndex)!))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isCorrect ? ExamPalette.mint : ExamPalette.textSecondary)
                    .frame(width: 28)

                Text(option)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ExamPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ExamPalette.mint)
                }
            }
            .padding(15)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(border, lineWidth: isCorrect || isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func feedbackCard(_ question: StudyQuestion) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(selected == question.correctIndex ? "Nice work." : "Almost — here's what matters.")
                .font(.system(size: 16, weight: .bold))
            Text(simplerExplanation ?? question.explanation)
                .font(.system(size: 13))
                .foregroundStyle(ExamPalette.textSecondary)
                .lineSpacing(3)
                .padding(.top, 6)

            if let tutorAnswer {
                Text("AI Tutor")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ExamPalette.purple)
                    .padding(.top, 10)
                Text(tutorAnswer)
                    .font(.system(size: 12))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .lineSpacing(3)
                    .padding(.top, 3)
            }

            if helperLoading {
                ProgressView()
                    .padding(.top, 10)
            }

            HStack(spacing: 8) {
                Button {
                    simplerExplanation = "Think of it in one step: identify what the question asks, isolate the key relationship, then check the answer against the original statement."
                } label: {
                    feedbackChip("Explain simpler")
                }
                .buttonStyle(.plain)

                Button {
                    guard !helperLoading else { return }
                    helperLoading = true
                    Task { @MainActor in
                        do {
                            tutorAnswer = try await AIGatewayClient().askTutor(
                                setup: setup,
                                message: "Explain this question and why the correct answer is '\(question.options[question.correctIndex])': \(question.prompt)"
                            )
                        } catch {
                            let message = error.localizedDescription
                            if message.localizedCaseInsensitiveContains("Daily AI limit") {
                                onPaywall("ai_limit")
                            } else {
                                tutorAnswer = message
                            }
                        }
                        helperLoading = false
                    }
                } label: {
                    feedbackChip("Ask tutor")
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
        }
        .padding(16)
        .examCard(radius: 20)
    }

    private func feedbackChip(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(ExamPalette.primary)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(ExamPalette.softBlue)
            .clipShape(Capsule())
    }

    private var completeView: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(ExamPalette.mint)
                .frame(width: 86, height: 86)
                .background(ExamPalette.softMint)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            Text("Session complete")
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 20)
            Text("\(correctCount)/\(questions.count) correct · \(setup.exam.shortName)")
                .font(.system(size: 14))
                .foregroundStyle(ExamPalette.textSecondary)
                .padding(.top, 7)

            HStack {
                completionStat("\(correctCount)", "Correct")
                Spacer()
                completionStat("\(questions.count - correctCount)", "Review")
                Spacer()
                completionStat("+\(earnedXP)", "XP")
            }
            .padding(18)
            .examCard(radius: 22)
            .padding(.top, 24)

            Spacer()

            Button(action: onClose) {
                Text("Done")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ExamPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(ExamPalette.background.ignoresSafeArea())
    }

    private func completionStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 22, weight: .bold))
            Text(label).font(.system(size: 11)).foregroundStyle(ExamPalette.textSecondary)
        }
    }
}
