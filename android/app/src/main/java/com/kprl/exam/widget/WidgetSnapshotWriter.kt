package com.kprl.exam.widget

import android.content.Context
import androidx.glance.appwidget.updateAll
import com.kprl.exam.data.StudySetup
import com.kprl.exam.domain.SampleQuestionFactory
import com.kprl.exam.localization.LocalizedCopy
import com.kprl.exam.platform.persistence.PlanTask
import java.time.LocalDate

object WidgetSnapshotWriter {
    private val LABEL_KEYS = listOf(
        "widget_streak", "widget_tasks_done", "widget_reviews_due", "widget_all_done",
        "widget_question_title", "widget_correct", "widget_incorrect", "widget_open_app"
    )

    suspend fun write(context: Context, setup: StudySetup, plan: List<PlanTask>, dueReviews: Int, streak: Int) {
        val copy = LocalizedCopy.load(context, setup.languageCode)
        val pool = SampleQuestionFactory.forSetup(setup)
        // Same question all day, a different one tomorrow.
        val question = pool.takeIf { it.isNotEmpty() }?.get((LocalDate.now().toEpochDay() % pool.size).toInt())

        WidgetSnapshot.save(
            context,
            WidgetSnapshot(
                examName = setup.exam.shortName,
                streak = streak,
                tasksCompleted = plan.count { it.completed },
                tasksTotal = plan.size,
                dueReviews = dueReviews,
                nextTaskTitle = plan.firstOrNull { !it.completed }?.title,
                question = question?.let {
                    WidgetSnapshot.Question(it.id, it.topic, it.prompt, it.options, it.correctIndex, it.explanation)
                },
                labels = LABEL_KEYS.associateWith { copy.text(it) }
            )
        )
        StudyProgressWidget().updateAll(context)
        DailyQuestionWidget().updateAll(context)
    }
}
