import SwiftUI

struct QuestionSessionView: View {
    let setup: StudySetup
    let onClose: () -> Void

    @State private var index = 0
    @State private var selected: Int?
    @State private var correctCount = 0
    @State private var completed = false

    private var questions: [StudyQuestion] {
        SampleQuestionFactory.questions(for: setup)
    }

    var body: some View {
        if completed {
            completeView
        } else {
            questionView
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
                        completed = true
                    } else {
                        index += 1
                        selected = nil
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
            selected = optionIndex
            if optionIndex == question.correctIndex {
                correctCount += 1
            }
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
            Text(question.explanation)
                .font(.system(size: 13))
                .foregroundStyle(ExamPalette.textSecondary)
                .lineSpacing(3)
                .padding(.top, 6)

            HStack(spacing: 8) {
                feedbackChip("Explain simpler")
                feedbackChip("Ask tutor")
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
                completionStat("+80", "XP")
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
