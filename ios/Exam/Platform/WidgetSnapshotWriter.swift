import Foundation
import WidgetKit

@MainActor
enum WidgetSnapshotWriter {
    static func write(setup: StudySetup, plan: [PlanTask], dueReviews: Int, streak: Int) {
        let copy = LocalizedCopy.load(languageCode: setup.languageCode)
        let pool = SampleQuestionFactory.questions(for: setup)
        // Same question all day, a different one tomorrow.
        let dayIndex = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let question = pool.isEmpty ? nil : pool[dayIndex % pool.count]

        WidgetSnapshot(
            examName: setup.exam.shortName,
            streak: streak,
            tasksCompleted: plan.filter(\.completed).count,
            tasksTotal: plan.count,
            dueReviews: dueReviews,
            nextTaskTitle: plan.first { !$0.completed }?.title,
            question: question.map {
                .init(id: $0.id, topic: $0.topic, prompt: $0.prompt, options: $0.options,
                      correctIndex: $0.correctIndex, explanation: $0.explanation)
            },
            labels: .init(
                streak: copy.text("widget_streak"),
                tasksDone: copy.text("widget_tasks_done"),
                reviewsDue: copy.text("widget_reviews_due"),
                allDone: copy.text("widget_all_done"),
                questionTitle: copy.text("widget_question_title"),
                correct: copy.text("widget_correct"),
                incorrect: copy.text("widget_incorrect"),
                openApp: copy.text("widget_open_app")
            ),
            updatedAt: .now
        ).save()

        WidgetCenter.shared.reloadAllTimelines()
    }
}
