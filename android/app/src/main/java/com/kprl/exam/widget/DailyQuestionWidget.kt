package com.kprl.exam.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.currentState
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.GlanceModifier
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.compose.ui.graphics.Color

private val QuestionIdKey = ActionParameters.Key<String>("question_id")
private val ChoiceKey = ActionParameters.Key<Int>("choice")
private val AnswerRevisionKey = intPreferencesKey("answer_revision")

/** Answers the question of the day directly on the home screen. */
class AnswerQuestionAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val questionId = parameters[QuestionIdKey] ?: return
        val choice = parameters[ChoiceKey] ?: return
        WidgetSnapshot.saveAnswer(context, questionId, choice)
        // Changing Glance state is what triggers recomposition of a running session.
        updateAppWidgetState(context, glanceId) { prefs ->
            prefs[AnswerRevisionKey] = (prefs[AnswerRevisionKey] ?: 0) + 1
        }
        DailyQuestionWidget().update(context, glanceId)
    }
}

class DailyQuestionWidget : GlanceAppWidget() {
    override val stateDefinition = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            // Read inside composition so an answer (revision bump) re-renders.
            currentState<Preferences>()[AnswerRevisionKey]
            val snapshot = WidgetSnapshot.load(context)
            val answer = snapshot?.question?.let { WidgetSnapshot.answer(context, it.id) }
            Content(context, snapshot, answer)
        }
    }

    @Composable
    private fun Content(context: Context, s: WidgetSnapshot?, answer: Int?) {
        Column(
            modifier = GlanceModifier.fillMaxSize()
                .background(WidgetColors.of(WidgetColors.Background))
                .cornerRadius(22.dp)
                .padding(14.dp)
        ) {
            val q = s?.question
            if (s == null || q == null) {
                Text(
                    s?.label("widget_open_app") ?: "Open Examly to get today's question",
                    modifier = GlanceModifier.clickable(actionStartActivity(openAppIntent(context, "today"))),
                    style = TextStyle(color = WidgetColors.of(WidgetColors.TextSecondary), fontSize = 13.sp)
                )
                return@Column
            }

            Text(s.label("widget_question_title"), style = TextStyle(color = WidgetColors.of(WidgetColors.Primary), fontSize = 11.sp, fontWeight = FontWeight.Bold))
            Spacer(GlanceModifier.height(4.dp))
            Text(q.prompt, maxLines = 3, style = TextStyle(color = WidgetColors.of(WidgetColors.TextPrimary), fontSize = 13.sp, fontWeight = FontWeight.Medium))
            Spacer(GlanceModifier.height(6.dp))

            // Glance caps a container at 10 children, so options get their own column.
            Column(modifier = GlanceModifier.fillMaxWidth()) {
            q.options.forEachIndexed { index, option ->
                val fill: Color = when {
                    answer == null -> Color.White
                    index == q.correctIndex -> Color(0xFFDDF7EC)
                    index == answer -> Color(0xFFFDE2E2)
                    else -> Color.White
                }
                val modifier = GlanceModifier.fillMaxWidth()
                    .background(WidgetColors.of(fill))
                    .cornerRadius(10.dp)
                    .padding(horizontal = 10.dp, vertical = 6.dp)
                Box(
                    modifier = if (answer == null) {
                        modifier.clickable(
                            actionRunCallback<AnswerQuestionAction>(
                                actionParametersOf(QuestionIdKey to q.id, ChoiceKey to index)
                            )
                        )
                    } else modifier
                ) {
                    Text(option, maxLines = 1, style = TextStyle(color = WidgetColors.of(WidgetColors.TextPrimary), fontSize = 12.sp))
                }
                Spacer(GlanceModifier.height(4.dp))
            }
            }

            if (answer != null) {
                val correct = answer == q.correctIndex
                Text(
                    s.label(if (correct) "widget_correct" else "widget_incorrect"),
                    modifier = GlanceModifier.clickable(actionStartActivity(openAppIntent(context, "today"))),
                    style = TextStyle(
                        color = WidgetColors.of(if (correct) WidgetColors.Mint else WidgetColors.Coral),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                )
            }
        }
    }
}

class DailyQuestionWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DailyQuestionWidget()
}
