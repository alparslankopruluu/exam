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
    @State private var completedDurationSeconds = 0
    @State private var simplerExplanation: String?
    @State private var tutorAnswer: String?
    @State private var helperLoading = false
    @State private var remainingSeconds = 0
    /// Mock exams hide feedback until the end: answers and flags per question index.
    @State private var mockAnswers: [Int: Int] = [:]
    @State private var flagged: Set<Int> = []

    private var isMock: Bool { timeLimitSeconds != nil }

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

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
        .task {
            AppServices.shared.analytics.event(
                AnalyticsEvent.studySessionStarted,
                params: [
                    AnalyticsParam.examId: setup.exam.id,
                    AnalyticsParam.contentPackId: setup.exam.syllabusPackId,
                    AnalyticsParam.sessionType: sessionType,
                    AnalyticsParam.itemCount: questions.count
                ]
            )
            if sessionType == "daily_plan" {
                AppServices.shared.analytics.event(
                    AnalyticsEvent.dailyMissionStarted,
                    params: [AnalyticsParam.examId: setup.exam.id]
                )
            } else if sessionType == "mock_exam" {
                AppServices.shared.analytics.event(
                    AnalyticsEvent.mockStarted,
                    params: [
                        AnalyticsParam.examId: setup.exam.id,
                        AnalyticsParam.itemCount: questions.count
                    ]
                )
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

                if isMock {
                    Label(String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60), systemImage: "clock.fill")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(ExamPalette.coral)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ExamPalette.coral.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text("\(index + 1)/\(questions.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ExamPalette.textSecondary)
                }
            }

            if isMock {
                mockTopicTabs
                    .padding(.top, 12)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(isMock
                         ? copy.text("question_n_of", variables: ["n": String(index + 1), "total": String(questions.count)])
                         : question.topic.uppercased())
                        .font(.system(size: isMock ? 13 : 11, weight: .bold))
                        .foregroundStyle(isMock ? ExamPalette.textSecondary : ExamPalette.primary)
                        .padding(.top, isMock ? 18 : 28)

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

                    if selected != nil && !isMock {
                        feedbackCard(question)
                            .padding(.top, 18)
                    }
                }
            }

            if isMock {
                mockControls
                    .padding(.top, 12)
            } else if selected != nil {
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
                    Text(index == questions.count - 1 ? copy.text("finish_session") : copy.text("next_question"))
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
        if isMock { scoreMock() }
        let completedAt = Date()
        try? LearningStore(context: modelContext).saveSession(
            examId: setup.exam.id,
            sessionType: sessionType,
            startedAt: sessionStartedAt,
            completedAt: completedAt,
            correctCount: correctCount,
            totalCount: questions.count
        )
        completedDurationSeconds = max(0, Int(completedAt.timeIntervalSince(sessionStartedAt)))
        let before = UserProgressStore().snapshot()
        let after = UserProgressStore().recordSession(
            correct: correctCount,
            total: questions.count,
            durationSeconds: max(0, Int(completedAt.timeIntervalSince(sessionStartedAt)))
        )
        earnedXP = max(0, after.xp - before.xp)
        let scorePercent = questions.isEmpty ? 0 : correctCount * 100 / questions.count

        AppServices.shared.analytics.event(
            AnalyticsEvent.studySessionCompleted,
            params: [
                AnalyticsParam.examId: setup.exam.id,
                AnalyticsParam.contentPackId: setup.exam.syllabusPackId,
                AnalyticsParam.sessionType: sessionType,
                AnalyticsParam.itemCount: questions.count,
                AnalyticsParam.scorePercent: scorePercent,
                AnalyticsParam.durationSeconds: completedDurationSeconds,
                AnalyticsParam.xpEarned: earnedXP
            ]
        )
        if sessionType == "daily_plan" {
            AppServices.shared.analytics.event(
                AnalyticsEvent.dailyMissionCompleted,
                params: [
                    AnalyticsParam.examId: setup.exam.id,
                    AnalyticsParam.scorePercent: scorePercent,
                    AnalyticsParam.durationSeconds: completedDurationSeconds
                ]
            )
        } else if sessionType == "mock_exam" {
            AppServices.shared.analytics.event(
                AnalyticsEvent.mockCompleted,
                params: [
                    AnalyticsParam.examId: setup.exam.id,
                    AnalyticsParam.scorePercent: scorePercent,
                    AnalyticsParam.durationSeconds: completedDurationSeconds
                ]
            )
        }
        if after.streak > before.streak {
            AppServices.shared.analytics.event(
                AnalyticsEvent.streakExtended,
                params: [
                    AnalyticsParam.examId: setup.exam.id,
                    AnalyticsParam.streakCount: after.streak
                ]
            )
        }

        onSessionCompleted?()
        completed = true
    }

    private var progress: CGFloat {
        CGFloat(index + (selected == nil ? 0 : 1)) / CGFloat(max(questions.count, 1))
    }

    private func optionRow(question: StudyQuestion, index optionIndex: Int, option: String) -> some View {
        if isMock {
            return AnyView(mockOptionRow(index: optionIndex, option: option))
        }
        return AnyView(answerOptionRow(question: question, index: optionIndex, option: option))
    }

    /// Mock option: selectable and changeable, no correctness shown until the end.
    private func mockOptionRow(index optionIndex: Int, option: String) -> some View {
        let chosen = mockAnswers[index] == optionIndex
        return Button {
            mockAnswers[index] = optionIndex
        } label: {
            HStack(spacing: 10) {
                Text(String(UnicodeScalar(65 + optionIndex)!))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(chosen ? .white : ExamPalette.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(chosen ? ExamPalette.primary : ExamPalette.background)
                    .clipShape(Circle())
                Text(option)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ExamPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(15)
            .background(chosen ? ExamPalette.softBlue : ExamPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(chosen ? ExamPalette.primary : ExamPalette.border, lineWidth: chosen ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    /// One chip per topic in question order; tapping jumps to that topic's first question.
    private var mockTopicTabs: some View {
        let topics = questions.map(\.topic).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(topics, id: \.self) { topic in
                    let current = questions[index].topic == topic
                    Button {
                        if let first = questions.firstIndex(where: { $0.topic == topic }) { index = first }
                    } label: {
                        Text(topic)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(current ? ExamPalette.primary : ExamPalette.textSecondary)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(current ? ExamPalette.softBlue : ExamPalette.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(current ? ExamPalette.primary.opacity(0.4) : ExamPalette.border))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var mockControls: some View {
        let last = index == questions.count - 1
        return HStack(spacing: 10) {
            Button {
                if flagged.contains(index) { flagged.remove(index) } else { flagged.insert(index) }
            } label: {
                Label(copy.text("mark"), systemImage: flagged.contains(index) ? "flag.fill" : "flag")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(flagged.contains(index) ? ExamPalette.amber : ExamPalette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .examCard(radius: 18)
            }
            .buttonStyle(.plain)

            Button {
                if last { finishSession() } else { index += 1 }
            } label: {
                Text(copy.text(last ? "finish_session" : "next"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ExamPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    /// Records every mock answer once the exam ends (on finish or when time runs out).
    @MainActor
    private func scoreMock() {
        let store = LearningStore(context: modelContext)
        correctCount = 0
        for (questionIndex, question) in questions.enumerated() {
            guard let answer = mockAnswers[questionIndex] else { continue }
            let correct = answer == question.correctIndex
            if correct { correctCount += 1 }
            try? store.recordAnswer(
                examId: setup.exam.id,
                skillId: setup.exam.id + ":" + question.topic.lowercased().replacingOccurrences(of: " ", with: "_"),
                questionId: question.id,
                correct: correct,
                responseTimeMs: 0,
                selectedAnswer: question.options[answer],
                correctAnswer: question.options[question.correctIndex],
                errorType: correct ? "none" : "concept"
            )
        }
    }

    private func answerOptionRow(question: StudyQuestion, index optionIndex: Int, option: String) -> some View {
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

            let responseMs = max(0, Int(answeredAt.timeIntervalSince(questionStartedAt) * 1000))
            try? LearningStore(context: modelContext).recordAnswer(
                examId: setup.exam.id,
                skillId: skillId,
                questionId: question.id,
                correct: correct,
                responseTimeMs: responseMs,
                selectedAnswer: option,
                correctAnswer: question.options[question.correctIndex],
                errorType: correct ? "none" : "concept"
            )

            AppServices.shared.analytics.event(
                AnalyticsEvent.questionAnswered,
                params: [
                    AnalyticsParam.examId: setup.exam.id,
                    AnalyticsParam.contentPackId: setup.exam.syllabusPackId,
                    AnalyticsParam.topicId: question.topic.lowercased().replacingOccurrences(of: " ", with: "_"),
                    AnalyticsParam.answerCorrect: correct,
                    AnalyticsParam.responseTimeMs: responseMs,
                    AnalyticsParam.sessionType: sessionType,
                    AnalyticsParam.errorType: correct ? "none" : "concept"
                ]
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
            let correct = selected == question.correctIndex
            HStack(spacing: 12) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(correct ? ExamPalette.mint : ExamPalette.coral)
                VStack(alignment: .leading, spacing: 2) {
                    Text(copy.text(correct ? "nice_work" : "not_quite"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(correct ? ExamPalette.textPrimary : ExamPalette.coral)
                    if !correct {
                        Text(copy.text("correct_answer_is", variables: ["letter": String(UnicodeScalar(65 + question.correctIndex)!)]))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ExamPalette.textSecondary)
                    }
                }
            }
            Text(copy.text("explanation").uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ExamPalette.textSecondary)
                .padding(.top, 14)
            Text(simplerExplanation ?? question.explanation)
                .font(.system(size: 13))
                .foregroundStyle(ExamPalette.textSecondary)
                .lineSpacing(3)
                .padding(.top, 6)

            if let tutorAnswer {
                Text(copy.text("ai_tutor"))
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
                    AppServices.shared.analytics.event(
                        AnalyticsEvent.explanationRequested,
                        params: [
                            AnalyticsParam.examId: setup.exam.id,
                            AnalyticsParam.source: "simpler_local",
                            AnalyticsParam.sessionType: sessionType
                        ]
                    )
                    simplerExplanation = copy.text("simpler_explanation")
                } label: {
                    feedbackChip(copy.text("explain_simpler"))
                }
                .buttonStyle(.plain)

                Button {
                    guard !helperLoading else { return }
                    AppServices.shared.analytics.event(
                        AnalyticsEvent.explanationRequested,
                        params: [
                            AnalyticsParam.examId: setup.exam.id,
                            AnalyticsParam.source: "ai_tutor",
                            AnalyticsParam.sessionType: sessionType
                        ]
                    )
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
                    feedbackChip(copy.text("ask_tutor"))
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

            Text(copy.text("session_complete"))
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 20)
            Text(
                copy.text(
                    "result_correct",
                    variables: [
                        "correct": "\(correctCount)",
                        "total": "\(questions.count)",
                        "exam": setup.exam.shortName
                    ]
                )
            )
                .font(.system(size: 14))
                .foregroundStyle(ExamPalette.textSecondary)
                .padding(.top, 7)

            HStack {
                completionStat("\(correctCount)", copy.text("correct"))
                Spacer()
                completionStat("\(questions.count - correctCount)", copy.text("review"))
                Spacer()
                completionStat("+\(earnedXP)", copy.text("xp"))
            }
            .padding(18)
            .examCard(radius: 22)
            .padding(.top, 24)

            if sessionType == "mock_exam" {
                VStack(alignment: .leading, spacing: 8) {
                    let accuracy = questions.isEmpty ? 0 : correctCount * 100 / questions.count
                    Text(copy.text("mock_analysis"))
                        .font(.system(size: 17, weight: .bold))
                    Text(copy.text("accuracy") + " · \(accuracy)%")
                        .font(.system(size: 14, weight: .semibold))
                    Text(
                        copy.text("time") + " · " + String(
                            format: "%02d:%02d",
                            completedDurationSeconds / 60,
                            completedDurationSeconds % 60
                        )
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(ExamPalette.textSecondary)

                    Text(
                        accuracy >= 85
                        ? copy.text("mock_result_strong")
                        : accuracy >= 65
                        ? copy.text("mock_result_good")
                        : copy.text("mock_result_review")
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .examCard(radius: 20)
                .padding(.top, 14)
            }

            Spacer()

            Button(action: onClose) {
                Text(copy.text("done"))
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
