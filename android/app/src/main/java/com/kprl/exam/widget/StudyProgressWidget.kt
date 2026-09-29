package com.kprl.exam.widget

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.LinearProgressIndicator
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import com.kprl.exam.MainActivity
import com.kprl.exam.platform.notifications.DeepLinkRouter

internal object WidgetColors {
    val Background = Color(0xFFF7F9FC)
    val TextPrimary = Color(0xFF0F172A)
    val TextSecondary = Color(0xFF64748B)
    val Primary = Color(0xFF3B6CF6)
    val Mint = Color(0xFF2CCB8C)
    val Amber = Color(0xFFF5A524)
    val Coral = Color(0xFFF26D6D)
    val Border = Color(0xFFE6EAF2)

    // The widget follows the app's light design language in both modes.
    fun of(color: Color) = ColorProvider(day = color, night = color)
}

internal fun openAppIntent(context: Context, route: String) =
    Intent(context, MainActivity::class.java)
        .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        .putExtra(DeepLinkRouter.EXTRA_ROUTE, route)

class StudyProgressWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val snapshot = WidgetSnapshot.load(context)
        provideContent { Content(context, snapshot) }
    }

    @Composable
    private fun Content(context: Context, s: WidgetSnapshot?) {
        Column(
            modifier = GlanceModifier.fillMaxSize()
                .background(WidgetColors.of(WidgetColors.Background))
                .cornerRadius(22.dp)
                .padding(14.dp)
                .clickable(actionStartActivity(openAppIntent(context, if ((s?.dueReviews ?: 0) > 0) "review" else "today"))),
            verticalAlignment = Alignment.Vertical.Top
        ) {
            if (s == null) {
                Text("Exam", style = TextStyle(color = WidgetColors.of(WidgetColors.TextPrimary), fontWeight = FontWeight.Bold))
                return@Column
            }
            Text(s.examName, style = TextStyle(color = WidgetColors.of(WidgetColors.Primary), fontSize = 11.sp, fontWeight = FontWeight.Bold))
            Text("🔥 ${s.streak}", style = TextStyle(color = WidgetColors.of(WidgetColors.TextPrimary), fontSize = 28.sp, fontWeight = FontWeight.Bold))
            Text(s.label("widget_streak"), style = TextStyle(color = WidgetColors.of(WidgetColors.TextSecondary), fontSize = 11.sp))
            Spacer(GlanceModifier.height(8.dp))
            Text(
                "${s.tasksCompleted}/${s.tasksTotal} ${s.label("widget_tasks_done")}",
                style = TextStyle(color = WidgetColors.of(WidgetColors.TextPrimary), fontSize = 12.sp, fontWeight = FontWeight.Medium)
            )
            Spacer(GlanceModifier.height(4.dp))
            LinearProgressIndicator(
                progress = if (s.tasksTotal == 0) 0f else s.tasksCompleted.toFloat() / s.tasksTotal,
                modifier = GlanceModifier.fillMaxWidth(),
                color = WidgetColors.of(WidgetColors.Mint),
                backgroundColor = WidgetColors.of(WidgetColors.Border)
            )
            if (s.dueReviews > 0) {
                Spacer(GlanceModifier.height(6.dp))
                Text(
                    "${s.dueReviews} ${s.label("widget_reviews_due")}",
                    style = TextStyle(color = WidgetColors.of(WidgetColors.Amber), fontSize = 12.sp, fontWeight = FontWeight.Bold)
                )
            }
        }
    }
}

class StudyProgressWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = StudyProgressWidget()
}
