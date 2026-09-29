import AppIntents
import SwiftUI
import WidgetKit

/// Answers the question of the day directly on the home screen.
struct AnswerQuestionIntent: AppIntent {
    static let title: LocalizedStringResource = "Answer question"

    @Parameter(title: "Question") var questionId: String
    @Parameter(title: "Choice") var choice: Int

    init() {}

    init(questionId: String, choice: Int) {
        self.questionId = questionId
        self.choice = choice
    }

    func perform() async throws -> some IntentResult {
        WidgetSnapshot.saveAnswer(questionId: questionId, choice: choice)
        return .result()
    }
}

struct DailyQuestionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyQuestionWidget", provider: SnapshotProvider()) { entry in
            DailyQuestionView(entry: entry)
                .containerBackground(WidgetPalette.background, for: .widget)
        }
        .configurationDisplayName("Question of the day")
        .description("Answer one exam question a day without opening the app.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct DailyQuestionView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let question = entry.snapshot.question {
            content(question)
        } else {
            Text(entry.snapshot.labels.openApp)
                .foregroundStyle(WidgetPalette.textSecondary)
        }
    }

    private func content(_ q: WidgetSnapshot.Question) -> some View {
        let answered = entry.answer
        let large = family == .systemLarge

        return VStack(alignment: .leading, spacing: large ? 10 : 6) {
            HStack {
                Text(entry.snapshot.labels.questionTitle)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetPalette.primary)
                Spacer()
                Text(q.topic)
                    .font(.system(size: 10))
                    .foregroundStyle(WidgetPalette.textSecondary)
            }

            Text(q.prompt)
                .font(.system(size: large ? 15 : 13, weight: .semibold))
                .foregroundStyle(WidgetPalette.textPrimary)
                .lineLimit(large ? 4 : 2)

            let columns = large ? 1 : 2
            let rows = stride(from: 0, to: q.options.count, by: columns).map { Array($0..<min($0 + columns, q.options.count)) }
            VStack(spacing: 5) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 5) {
                        ForEach(row, id: \.self) { index in
                            option(q, index: index, answered: answered)
                        }
                    }
                }
            }

            if let answered {
                let correct = answered == q.correctIndex
                Text(correct ? entry.snapshot.labels.correct : entry.snapshot.labels.incorrect)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(correct ? WidgetPalette.mint : WidgetPalette.coral)
                if large {
                    Text(q.explanation)
                        .font(.system(size: 11))
                        .foregroundStyle(WidgetPalette.textSecondary)
                        .lineLimit(3)
                }
            }
        }
        .widgetURL(URL(string: "exam://today"))
    }

    private func option(_ q: WidgetSnapshot.Question, index: Int, answered: Int?) -> some View {
        let isCorrect = index == q.correctIndex
        let isChosen = index == answered
        let fill: Color = {
            guard answered != nil else { return .white }
            if isCorrect { return WidgetPalette.mint.opacity(0.18) }
            if isChosen { return WidgetPalette.coral.opacity(0.18) }
            return .white
        }()

        return Button(intent: AnswerQuestionIntent(questionId: q.id, choice: index)) {
            Text(q.options[index])
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WidgetPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 26)
                .background(fill)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(WidgetPalette.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(answered != nil)
    }
}
