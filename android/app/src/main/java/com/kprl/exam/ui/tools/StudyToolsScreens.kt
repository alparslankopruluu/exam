package com.kprl.exam.ui.tools

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.content.ContextWrapper
import android.os.Build
import androidx.compose.foundation.BorderStroke
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.res.painterResource
import com.kprl.exam.R
import com.kprl.exam.debug.ScreenshotMode
import com.kprl.exam.content.ContentPackRepository
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.kprl.exam.platform.account.AuthService
import com.kprl.exam.ui.account.AccountScreen
import com.kprl.exam.ui.components.ExamDateField
import com.kprl.exam.ui.components.ExamIconBadge
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.messaging.FirebaseMessaging
import com.kprl.exam.platform.firebase.FirebaseBootstrap
import com.kprl.exam.billing.GooglePlayBillingService
import com.kprl.exam.billing.CreditPackPresentation
import com.kprl.exam.platform.entitlements.EntitlementService
import com.kprl.exam.analytics.AnalyticsEvents
import com.kprl.exam.analytics.AnalyticsParams
import com.kprl.exam.data.StudySetup
import com.kprl.exam.domain.FlashcardRating
import com.kprl.exam.domain.FlashcardScheduler
import com.kprl.exam.domain.SampleQuestionFactory
import com.kprl.exam.domain.StudyQuestion
import com.kprl.exam.localization.LocalizedCopy
import com.kprl.exam.platform.ai.AIGatewayClient
import com.kprl.exam.platform.account.AccountService
import com.kprl.exam.platform.AppServices
import com.kprl.exam.platform.ai.GatewayResult
import com.kprl.exam.platform.notifications.PushTokenRegistrar
import com.kprl.exam.platform.persistence.LearningDatabase
import com.kprl.exam.platform.persistence.LearningRepository
import com.kprl.exam.platform.persistence.StudySetupStore
import com.kprl.exam.platform.persistence.UserProgressStore
import com.kprl.exam.ui.theme.ExamColors
import kotlinx.coroutines.delay

@Composable
private fun ToolHeader(title: String, subtitle: String? = null, onClose: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onClose) { Icon(Icons.Rounded.ArrowBack, "Back") }
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 24.sp, fontWeight = FontWeight.Bold)
            subtitle?.let { Text(it, color = ExamColors.TextSecondary, fontSize = 12.sp) }
        }
    }
}

private fun parseGeneratedQuestions(payload: Map<*, *>): List<StudyQuestion> {
    val rows = payload["questions"] as? List<*> ?: return emptyList()
    return rows.mapNotNull { raw ->
        val item = raw as? Map<*, *> ?: return@mapNotNull null
        val options = (item["options"] as? List<*>)?.mapNotNull { it as? String }.orEmpty()
        val correct = (item["correctIndex"] as? Number)?.toInt() ?: return@mapNotNull null
        val prompt = item["prompt"] as? String ?: return@mapNotNull null
        if (options.size < 2 || correct !in options.indices) return@mapNotNull null
        StudyQuestion(
            id = item["id"] as? String ?: "generated_${prompt.hashCode()}",
            topic = item["topic"] as? String ?: "Practice",
            prompt = prompt,
            options = options,
            correctIndex = correct,
            explanation = item["explanation"] as? String ?: "Review the key relationship and eliminate distractors."
        )
    }
}

@Composable
fun MockExamScreen(
    setup: StudySetup,
    onClose: () -> Unit,
    onStart: (List<StudyQuestion>) -> Unit,
    onPaywall: (String) -> Unit = {}
) {
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    val gateway = remember { AIGatewayClient() }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var questionCount by remember { mutableIntStateOf(10) }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp)
    ) {
        ToolHeader(
            copy.text("mock_exam"),
            copy.text("mock_timed_set", mapOf("exam" to setup.exam.shortName)),
            onClose
        )
        Spacer(Modifier.height(18.dp))

        Surface(
            color = ExamColors.Surface,
            shape = RoundedCornerShape(22.dp),
            border = BorderStroke(1.dp, ExamColors.Border)
        ) {
            Column(Modifier.padding(18.dp)) {
                Text(copy.text("exam_simulation"), fontSize = 18.sp, fontWeight = FontWeight.Bold)
                Text(
                    copy.text("mock_desc"),
                    color = ExamColors.TextSecondary,
                    fontSize = 13.sp,
                    lineHeight = 19.sp
                )
                Spacer(Modifier.height(16.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(10, 20, 30).forEach { count ->
                        FilterChip(
                            selected = questionCount == count,
                            onClick = { questionCount = count },
                            label = { Text(copy.text("questions_count", mapOf("count" to count.toString()))) }
                        )
                    }
                }
            }
        }

        error?.let {
            Spacer(Modifier.height(10.dp))
            Text(it, color = ExamColors.Coral, fontSize = 12.sp)
        }

        Spacer(Modifier.weight(1f))
        Button(
            onClick = {
                loading = true
                error = null
                gateway.generatePractice(
                    setup = setup,
                    topic = "Mixed full-exam simulation across the highest-impact ${setup.exam.shortName} domains",
                    count = questionCount
                ) { result ->
                    loading = false
                    when (result) {
                        is GatewayResult.Success -> {
                            val generated = parseGeneratedQuestions(result.value)
                            onStart(
                                generated.ifEmpty {
                                    val fallback = SampleQuestionFactory.forSetup(setup)
                                    List(questionCount) { index ->
                                        fallback[index % fallback.size].copy(id = "mock_$index")
                                    }
                                }
                            )
                        }
                        is GatewayResult.Error -> {
                            if (result.message.contains("Daily AI limit", ignoreCase = true)) {
                                onPaywall("ai_limit")
                            } else {
                                error = result.message
                                val fallback = SampleQuestionFactory.forSetup(setup)
                                onStart(List(questionCount) { i -> fallback[i % fallback.size].copy(id = "mock_$i") })
                            }
                        }
                    }
                }
            },
            modifier = Modifier.fillMaxWidth().height(56.dp),
            enabled = !loading,
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary)
        ) {
            if (loading) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp, color = Color.White)
            else Icon(Icons.Rounded.Timer, null)
            Spacer(Modifier.width(8.dp))
            Text(if (loading) copy.text("building_mock") else copy.text("start_mock"), fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(12.dp))
    }
}

@Composable
fun MistakesScreen(setup: StudySetup, onClose: () -> Unit, onPractice: () -> Unit) {
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    val repository = remember { LearningRepository(LearningDatabase(context.applicationContext)) }
    var mistakes by remember { mutableStateOf(repository.mistakes(setup.exam.id)) }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp)
    ) {
        ToolHeader(copy.text("mistakes"), copy.text("mistakes_subtitle"), onClose)
        Spacer(Modifier.height(14.dp))

        if (mistakes.isEmpty()) {
            Surface(
                color = ExamColors.Surface,
                shape = RoundedCornerShape(22.dp),
                border = BorderStroke(1.dp, ExamColors.Border)
            ) {
                Column(Modifier.padding(22.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Rounded.CheckCircle, null, tint = ExamColors.Mint, modifier = Modifier.size(42.dp))
                    Spacer(Modifier.height(10.dp))
                    Text(copy.text("no_unresolved_mistakes"), fontWeight = FontWeight.Bold)
                    Text(copy.text("new_mistakes_hint"), color = ExamColors.TextSecondary, fontSize = 12.sp)
                }
            }
        } else {
            LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                items(mistakes, key = { it.id }) { item ->
                    Surface(
                        color = ExamColors.Surface,
                        shape = RoundedCornerShape(18.dp),
                        border = BorderStroke(1.dp, ExamColors.Border)
                    ) {
                        Column(Modifier.padding(14.dp)) {
                            Text(item.skillId.substringAfter(":"), fontWeight = FontWeight.SemiBold)
                            Text(
                                item.errorType.replace("_", " ") + " · " + copy.text("selected_answer", mapOf("answer" to (item.selectedAnswer ?: "—"))),
                                color = ExamColors.TextSecondary,
                                fontSize = 11.sp
                            )
                            item.correctAnswer?.let {
                                Text(copy.text("correct_answer", mapOf("answer" to it)), color = ExamColors.Mint, fontSize = 12.sp, modifier = Modifier.padding(top = 5.dp))
                            }
                            TextButton(
                                onClick = {
                                    repository.resolveMistake(item.id)
                                    mistakes = repository.mistakes(setup.exam.id)
                                }
                            ) { Text(copy.text("mark_resolved")) }
                        }
                    }
                }
            }
        }

        Button(
            onClick = onPractice,
            modifier = Modifier.fillMaxWidth().height(54.dp),
            shape = RoundedCornerShape(17.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary)
        ) {
            Icon(Icons.Rounded.Refresh, null)
            Spacer(Modifier.width(8.dp))
            Text(copy.text("practice_weak_areas"), fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(12.dp))
    }
}

@Composable
fun FlashcardsScreen(setup: StudySetup, onClose: () -> Unit) {
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    val scheduler = remember { FlashcardScheduler(context.applicationContext) }
    val allCards = remember(setup.exam.id) { SampleQuestionFactory.forSetup(setup) }
    var cards by remember { mutableStateOf(allCards.filter { scheduler.isDue(it.id) }.ifEmpty { allCards }) }
    var index by remember { mutableIntStateOf(0) }
    var revealed by remember { mutableStateOf(false) }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp)
    ) {
        ToolHeader(copy.text("flashcards"), copy.text("spaced_repetition"), onClose)
        Spacer(Modifier.height(24.dp))

        if (cards.isEmpty()) {
            Text(copy.text("nothing_due"), color = ExamColors.TextSecondary)
        } else {
            val card = cards[index.coerceAtMost(cards.lastIndex)]
            Surface(
                modifier = Modifier.fillMaxWidth().height(300.dp).clickable { revealed = !revealed },
                color = ExamColors.Surface,
                shape = RoundedCornerShape(28.dp),
                border = BorderStroke(1.dp, ExamColors.Border)
            ) {
                Column(
                    Modifier.padding(22.dp),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(card.topic.uppercase(), color = ExamColors.Primary, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(18.dp))
                    Text(
                        if (revealed) card.explanation else card.prompt,
                        fontSize = if (revealed) 17.sp else 21.sp,
                        lineHeight = 28.sp,
                        fontWeight = if (revealed) FontWeight.Medium else FontWeight.Bold
                    )
                    Spacer(Modifier.height(18.dp))
                    Text(if (revealed) copy.text("rate_recall") else copy.text("tap_reveal"), color = ExamColors.TextSecondary, fontSize = 12.sp)
                }
            }

            if (revealed) {
                Spacer(Modifier.height(18.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    val ratings = listOf(
                        copy.text("again") to FlashcardRating.AGAIN,
                        copy.text("hard") to FlashcardRating.HARD,
                        copy.text("good") to FlashcardRating.GOOD,
                        copy.text("easy") to FlashcardRating.EASY
                    )
                    ratings.forEach { (label, rating) ->
                        OutlinedButton(
                            onClick = {
                                scheduler.review(card.id, rating)
                                AppServices.analytics.event(
                                    AnalyticsEvents.FLASHCARD_REVIEWED,
                                    mapOf(
                                        AnalyticsParams.EXAM_ID to setup.exam.id,
                                        AnalyticsParams.TOPIC_ID to card.topic.lowercase().replace(" ", "_"),
                                        AnalyticsParams.SOURCE to rating.name.lowercase()
                                    )
                                )
                                if (index < cards.lastIndex) {
                                    index++
                                    revealed = false
                                } else {
                                    cards = emptyList()
                                }
                            },
                            modifier = Modifier.weight(1f),
                            contentPadding = PaddingValues(horizontal = 4.dp)
                        ) { Text(label, fontSize = 11.sp) }
                    }
                }
            }
        }
    }
}

@Composable
fun CreatePracticeScreen(
    setup: StudySetup,
    onClose: () -> Unit,
    onStart: (List<StudyQuestion>) -> Unit,
    onPaywall: (String) -> Unit = {}
) {
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    val gateway = remember { AIGatewayClient() }
    var topic by remember { mutableStateOf("") }
    var count by remember { mutableIntStateOf(5) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp)
    ) {
        ToolHeader(copy.text("create_practice"), copy.text("create_practice_hint"), onClose)
        Spacer(Modifier.height(18.dp))

        OutlinedTextField(
            value = topic,
            onValueChange = { topic = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(copy.text("topic_instruction")) },
            placeholder = { Text(copy.text("topic_placeholder")) },
            minLines = 3,
            shape = RoundedCornerShape(18.dp)
        )
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(5, 10, 20).forEach {
                FilterChip(selected = count == it, onClick = { count = it }, label = { Text("$it") })
            }
        }
        error?.let { Text(it, color = ExamColors.Coral, fontSize = 12.sp) }

        Spacer(Modifier.weight(1f))
        Button(
            onClick = {
                loading = true
                error = null
                gateway.generatePractice(setup, topic.ifBlank { "Mixed ${setup.exam.shortName}" }, count) { result ->
                    loading = false
                    when (result) {
                        is GatewayResult.Success -> {
                            val questions = parseGeneratedQuestions(result.value)
                            if (questions.isNotEmpty()) onStart(questions)
                            else error = copy.text("generated_set_invalid")
                        }
                        is GatewayResult.Error -> {
                            if (result.message.contains("Daily AI limit", ignoreCase = true)) onPaywall("ai_limit")
                            else error = result.message
                        }
                    }
                }
            },
            enabled = !loading,
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary)
        ) {
            if (loading) CircularProgressIndicator(Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp)
            else Icon(Icons.Rounded.AutoAwesome, null)
            Spacer(Modifier.width(8.dp))
            Text(if (loading) copy.text("generating") else copy.text("generate_practice"), fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(12.dp))
    }
}

private enum class FocusMode { POMODORO, DEEP_WORK }
private enum class FocusPhase { FOCUS, SHORT_BREAK, LONG_BREAK }

private fun focusMinutes(mode: FocusMode, phase: FocusPhase): Int = when (mode) {
    FocusMode.POMODORO -> when (phase) { FocusPhase.FOCUS -> 25; FocusPhase.SHORT_BREAK -> 5; FocusPhase.LONG_BREAK -> 15 }
    FocusMode.DEEP_WORK -> when (phase) { FocusPhase.FOCUS -> 50; FocusPhase.SHORT_BREAK -> 10; FocusPhase.LONG_BREAK -> 20 }
}

@Composable
fun FocusScreen(setup: StudySetup, onClose: () -> Unit) {
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    var mode by remember { mutableStateOf(FocusMode.POMODORO) }
    var phase by remember { mutableStateOf(FocusPhase.FOCUS) }
    val total = focusMinutes(mode, phase) * 60
    // Store screenshots show a session midway, with the sapling half grown.
    var pausedRemaining by remember { mutableStateOf<Int?>(if (ScreenshotMode.screen != null) total * 2 / 5 else null) }
    var endAt by remember { mutableStateOf<Long?>(null) }
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }

    val remaining = endAt?.let { maxOf(0, ((it - now + 999) / 1000).toInt()) } ?: (pausedRemaining ?: total)
    val running = endAt != null
    val growth = if (phase == FocusPhase.FOCUS) 1f - remaining.toFloat() / total else 1f

    LaunchedEffect(endAt) {
        while (endAt != null) {
            now = System.currentTimeMillis()
            if (now >= endAt!!) {
                if (phase == FocusPhase.FOCUS) {
                    AppServices.analytics.event(
                        AnalyticsEvents.FOCUS_COMPLETED,
                        mapOf(AnalyticsParams.EXAM_ID to setup.exam.id, AnalyticsParams.DURATION_SECONDS to total)
                    )
                }
                sendFocusNotification(
                    context,
                    copy.text(if (phase == FocusPhase.FOCUS) "focus_complete" else "break_complete"),
                    copy.text(if (phase == FocusPhase.FOCUS) "focus_break" else "break_over", mapOf("exam" to setup.exam.shortName))
                )
                endAt = null
                pausedRemaining = 0
                break
            }
            delay(250)
        }
    }

    fun switchTo(newMode: FocusMode, newPhase: FocusPhase) {
        mode = newMode
        phase = newPhase
        endAt = null
        pausedRemaining = null
    }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp).padding(bottom = 12.dp)
    ) {
        ToolHeader(copy.text("focus_mode"), null, onClose)

        Row(
            Modifier.padding(top = 8.dp).fillMaxWidth()
                .background(ExamColors.Border.copy(alpha = 0.6f), RoundedCornerShape(50))
                .padding(4.dp)
        ) {
            FocusMode.entries.forEach { item ->
                val selected = mode == item
                Box(
                    Modifier.weight(1f).height(38.dp)
                        .shadow(if (selected) 3.dp else 0.dp, RoundedCornerShape(50))
                        .background(if (selected) ExamColors.Surface else Color.Transparent, RoundedCornerShape(50))
                        .clickable { switchTo(item, FocusPhase.FOCUS) },
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        copy.text(if (item == FocusMode.POMODORO) "pomodoro" else "deep_work"),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = if (selected) ExamColors.TextPrimary else ExamColors.TextSecondary
                    )
                }
            }
        }

        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
            FocusScene(growth, Modifier.padding(top = 110.dp).fillMaxSize().clip(RoundedCornerShape(28.dp)))
            Box(
                Modifier.padding(top = 18.dp).size(210.dp)
                    .shadow(16.dp, CircleShape, ambientColor = ExamColors.Primary.copy(alpha = 0.2f), spotColor = ExamColors.Primary.copy(alpha = 0.2f))
                    .background(ExamColors.Surface, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                val sweep by animateFloatAsState(360f * (1f - remaining.toFloat() / total), tween(900), label = "ring")
                Canvas(Modifier.fillMaxSize().padding(14.dp)) {
                    val stroke = 10.dp.toPx()
                    drawArc(ExamColors.SoftBlue, 0f, 360f, false, style = Stroke(stroke))
                    drawArc(ExamColors.Primary, -90f, sweep, false, style = Stroke(stroke, cap = StrokeCap.Round))
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "%02d:%02d".format(remaining / 60, remaining % 60),
                        fontSize = 44.sp,
                        fontWeight = FontWeight.Bold,
                        color = ExamColors.TextPrimary
                    )
                    Text(
                        copy.text(if (phase == FocusPhase.FOCUS) "focus_time" else "break_time"),
                        fontSize = 13.sp,
                        color = ExamColors.TextSecondary
                    )
                }
            }
        }

        Button(
            onClick = {
                if (running) {
                    pausedRemaining = remaining
                    endAt = null
                } else {
                    if (phase == FocusPhase.FOCUS) {
                        AppServices.analytics.event(
                            AnalyticsEvents.FOCUS_STARTED,
                            mapOf(AnalyticsParams.EXAM_ID to setup.exam.id, AnalyticsParams.DURATION_SECONDS to remaining)
                        )
                    }
                    now = System.currentTimeMillis()
                    endAt = now + remaining * 1000L
                    pausedRemaining = null
                }
            },
            modifier = Modifier.padding(top = 14.dp).fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ExamColors.TextPrimary)
        ) {
            Text(
                copy.text(if (running) "pause" else if (phase == FocusPhase.FOCUS) "start_focus" else "start_break"),
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
        }

        Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            FocusPhase.entries.forEach { item ->
                val selected = phase == item
                Column(
                    Modifier.weight(1f)
                        .background(if (selected) ExamColors.SoftBlue else ExamColors.Surface, RoundedCornerShape(16.dp))
                        .border(if (selected) 1.5.dp else 1.dp, if (selected) ExamColors.Primary else ExamColors.Border, RoundedCornerShape(16.dp))
                        .clickable { switchTo(mode, item) }
                        .padding(vertical = 12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        "${focusMinutes(mode, item)}",
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (selected) ExamColors.Primary else ExamColors.TextPrimary
                    )
                    Text(
                        copy.text(when (item) { FocusPhase.FOCUS -> "focus"; FocusPhase.SHORT_BREAK -> "short_break"; FocusPhase.LONG_BREAK -> "long_break" }),
                        fontSize = 11.sp,
                        color = ExamColors.TextSecondary,
                        maxLines = 1
                    )
                }
            }
        }
    }
}

/**
 * The focus illustration (design/illustrations/focus_scene.svg, 400x440) aspect-filled and
 * centre-cropped, with a sapling on the soil mound at scene point (200, 380) that grows with [growth].
 */
@Composable
private fun FocusScene(growth: Float, modifier: Modifier = Modifier) {
    val animated by animateFloatAsState(growth, tween(800), label = "growth")
    val scene = painterResource(R.drawable.illu_focus_scene)
    Canvas(modifier) {
        val scale = maxOf(size.width / 400f, size.height / 440f)
        val origin = Offset((size.width - 400f * scale) / 2f, (size.height - 440f * scale) / 2f)
        translate(origin.x, origin.y) {
            with(scene) { draw(Size(400f * scale, 440f * scale)) }
            drawSapling(animated, base = Offset(200f * scale, 380f * scale), unit = scale)
        }
    }
}

/** Mirrors the iOS `Sapling` view: a 120x110 sapling whose base sits at [base]. */
private fun DrawScope.drawSapling(growth: Float, base: Offset, unit: Float) {
    val g = growth.coerceIn(0.08f, 1f)
    val height = 100f * unit * g
    val stemColor = Color(0xFF5EA880)
    val leafA = Color(0xFF7DC499)
    val leafB = Color(0xFF6BB58A)
    val stem = Path().apply {
        moveTo(base.x, base.y)
        quadraticTo(base.x + 8f * unit, base.y - height / 2f, base.x, base.y - height)
    }
    drawPath(stem, stemColor, style = Stroke(5f * unit, cap = StrokeCap.Round))

    fun leaf(t: Float, appearAt: Float, length: Float, left: Boolean, color: Color) {
        val p = ((g - appearAt) / 0.2f).coerceIn(0f, 1f)
        if (p <= 0f) return
        val y = base.y - height * t
        val dir = if (left) -1f else 1f
        val path = Path().apply {
            moveTo(base.x, y)
            quadraticTo(base.x + dir * length * 0.4f * unit * p, y - 22f * unit * p, base.x + dir * length * unit * p, y - 14f * unit * p)
            quadraticTo(base.x + dir * length * 0.7f * unit * p, y + 4f * unit * p, base.x, y)
        }
        drawPath(path, color)
    }
    leaf(0.35f, 0.15f, 34f, true, leafB)
    leaf(0.45f, 0.3f, 30f, false, leafA)
    leaf(0.7f, 0.55f, 28f, true, leafA)
    leaf(0.8f, 0.7f, 26f, false, leafB)
    leaf(1f, 0.85f, 20f, false, leafA)
    leaf(1f, 0.85f, 20f, true, leafB)
}

private fun sendFocusNotification(context: Context, title: String, body: String) {
    val manager = context.getSystemService(NotificationManager::class.java)
    val channelId = "focus_complete"
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        manager.createNotificationChannel(
            NotificationChannel(channelId, title, NotificationManager.IMPORTANCE_DEFAULT)
        )
    }
    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        android.app.Notification.Builder(context, channelId)
    } else android.app.Notification.Builder(context)

    manager.notify(
        4201,
        builder.setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .build()
    )
}

private val SectionColors = listOf(ExamColors.Mint, ExamColors.Amber, ExamColors.Purple, ExamColors.Primary, ExamColors.Coral)

@Composable
fun ProgressScreen(setup: StudySetup, onClose: () -> Unit) {
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    val repository = remember { LearningRepository(LearningDatabase(context.applicationContext)) }
    val demo = ScreenshotMode.screen != null
    // Store screenshots show an established learner.
    val progress = remember {
        repository.progressSummary(setup.exam.id).let {
            if (demo) it.copy(sessions = 38, questions = 412, correct = 346, studyMinutes = 335) else it
        }
    }
    val errorDNA = remember { repository.errorDNA(setup.exam.id) }
    val user = remember { UserProgressStore(context.applicationContext).snapshot() }
    val fortnight = remember { repository.weeklyMinutes(setup.exam.id, days = 14) }
    val weekly = remember { if (demo) listOf(35, 50, 20, 65, 45, 80, 40) else fortnight.takeLast(7) }
    val lastWeekMinutes = if (demo) 260 else fortnight.take(7).sum()
    val masteredSkills = remember { if (demo) 3 else repository.masteredSkillCount(setup.exam.id) }
    val sections = remember {
        val titles = ContentPackRepository.load(context, setup.exam.syllabusPackId)?.units?.take(5)?.map { it.title }.orEmpty()
        val percents = repository.sectionMastery(setup.exam.id, titles)
        titles.mapIndexed { index, title -> title to if (demo) listOf(76, 62, 48, 70, 55)[index % 5] else percents[index] }
    }
    val mastery = if (progress.masteryPercent == 0) setup.diagnosticPercent else progress.masteryPercent
    val accuracy = if (progress.questions == 0) 0 else progress.correct * 100 / progress.questions

    LazyColumn(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        contentPadding = PaddingValues(bottom = 20.dp)
    ) {
        item { ToolHeader(copy.text("your_progress"), copy.text("learning_profile", mapOf("exam" to setup.exam.shortName)), onClose) }
        item {
            val focus = sections.filter { it.second != null }.minByOrNull { it.second ?: 0 }?.first ?: sections.firstOrNull()?.first
            WeeklyReport(copy, weekly.sum(), lastWeekMinutes, focus)
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                ProgressCard(Modifier.weight(1f), copy.text("mastery")) {
                    Box(Modifier.size(78.dp), contentAlignment = Alignment.Center) {
                        Canvas(Modifier.fillMaxSize().padding(4.dp)) {
                            val stroke = 8.dp.toPx()
                            drawArc(ExamColors.SoftMint, 0f, 360f, false, style = Stroke(stroke))
                            drawArc(ExamColors.Mint, -90f, 360f * mastery / 100f, false, style = Stroke(stroke, cap = StrokeCap.Round))
                        }
                        Text("$mastery%", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = ExamColors.Mint)
                    }
                }
                ProgressCard(Modifier.weight(1f), copy.text("questions_solved")) {
                    Box(Modifier.height(78.dp), contentAlignment = Alignment.Center) {
                        Text(
                            "${maxOf(progress.questions, user.totalQuestions)}",
                            fontSize = 32.sp,
                            fontWeight = FontWeight.Bold,
                            color = ExamColors.Purple
                        )
                    }
                }
            }
        }
        item { WeeklyChart(copy, weekly, copy.text("this_week"), setup.languageCode) }
        if (sections.isNotEmpty()) {
            item { Text(copy.text("subject_progress"), fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 4.dp)) }
            item {
                Surface(color = ExamColors.Surface, shape = RoundedCornerShape(20.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        sections.forEachIndexed { index, (title, percent) ->
                            SectionRow(title, percent, SectionColors[index % SectionColors.size])
                        }
                    }
                }
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MetricCard("${user.streak}", copy.text("streak"), Modifier.weight(1f))
                MetricCard("$accuracy%", copy.text("accuracy"), Modifier.weight(1f))
                MetricCard("${maxOf(progress.sessions, user.totalSessions)}", copy.text("sessions"), Modifier.weight(1f))
            }
        }
        item {
            val questions = maxOf(progress.questions, user.totalQuestions)
            Achievements(
                copy,
                listOf(
                    BadgeSpec("badge_streak_7", Icons.Rounded.LocalFireDepartment, ExamColors.Amber, user.streak, 7),
                    BadgeSpec("badge_streak_30", Icons.Rounded.Whatshot, ExamColors.Coral, user.streak, 30),
                    BadgeSpec("badge_questions_100", Icons.Rounded.Verified, ExamColors.Primary, questions, 100),
                    BadgeSpec("badge_questions_500", Icons.Rounded.Stars, ExamColors.Purple, questions, 500),
                    BadgeSpec("badge_study_10h", Icons.Rounded.Schedule, ExamColors.Mint, progress.studyMinutes, 600),
                    BadgeSpec("badge_mastered_5", Icons.Rounded.School, ExamColors.Indigo, masteredSkills, 5)
                )
            )
        }
        item {
            Surface(
                onClick = {
                    shareProgressCard(
                        context, copy, setup.exam.shortName, user.streak, progress.studyMinutes,
                        maxOf(progress.questions, user.totalQuestions), mastery
                    )
                },
                color = ExamColors.SoftBlue,
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth().height(50.dp)
            ) {
                Row(horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.IosShare, null, tint = ExamColors.Primary)
                    Spacer(Modifier.width(8.dp))
                    Text(copy.text("share_progress"), color = ExamColors.Primary, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                }
            }
        }
        item { Text(copy.text("error_dna"), fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 4.dp)) }
        if (errorDNA.isEmpty()) {
            item { Text(copy.text("no_error_pattern"), fontSize = 14.sp, color = ExamColors.TextSecondary) }
        } else {
            items(errorDNA.take(8)) { item ->
                Surface(
                    color = ExamColors.Surface,
                    shape = RoundedCornerShape(16.dp),
                    border = BorderStroke(1.dp, ExamColors.Border)
                ) {
                    Row(Modifier.padding(13.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.Insights, null, tint = ExamColors.Coral)
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text(item.skillId.substringAfter(":"), fontWeight = FontWeight.SemiBold)
                            Text(item.errorType.replace("_", " "), color = ExamColors.TextSecondary, fontSize = 11.sp)
                        }
                        Text("${item.count}×", color = ExamColors.Coral, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

@Composable
private fun WeeklyReport(copy: LocalizedCopy, thisWeek: Int, lastWeek: Int, focus: String?) {
    val change = if (lastWeek == 0) null else (thisWeek - lastWeek) * 100 / lastWeek
    Column(
        Modifier.fillMaxWidth()
            .background(androidx.compose.ui.graphics.Brush.linearGradient(listOf(ExamColors.Primary, ExamColors.Indigo)), RoundedCornerShape(22.dp))
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(copy.text("your_week"), fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.8f))
        Text(copy.text("duration_hm", mapOf("h" to "${thisWeek / 60}", "m" to "${thisWeek % 60}")), fontSize = 34.sp, fontWeight = FontWeight.Bold, color = Color.White)
        change?.let {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(if (it >= 0) Icons.Rounded.NorthEast else Icons.Rounded.SouthEast, null, tint = Color.White, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text(
                    copy.text("vs_last_week", mapOf("change" to (if (it >= 0) "+" else "") + "$it%")),
                    fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White
                )
            }
        }
        focus?.let {
            Text(copy.text("focus_next", mapOf("topic" to it)), fontSize = 13.sp, fontWeight = FontWeight.Medium, color = Color.White.copy(alpha = 0.85f))
        }
    }
}

private class BadgeSpec(val key: String, val icon: androidx.compose.ui.graphics.vector.ImageVector, val color: Color, val value: Int, val target: Int) {
    val unlocked get() = value >= target
}

@Composable
private fun Achievements(copy: LocalizedCopy, badges: List<BadgeSpec>) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(copy.text("achievements"), fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 4.dp))
        badges.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { badge ->
                    Surface(Modifier.weight(1f), color = ExamColors.Surface, shape = RoundedCornerShape(18.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
                        Column(Modifier.padding(vertical = 12.dp, horizontal = 4.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Box(
                                Modifier.size(52.dp).background(if (badge.unlocked) badge.color.copy(alpha = 0.14f) else ExamColors.Background, CircleShape),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(badge.icon, null, tint = if (badge.unlocked) badge.color else ExamColors.Border, modifier = Modifier.size(26.dp))
                            }
                            Text(
                                copy.text(badge.key), fontSize = 11.sp, fontWeight = FontWeight.SemiBold, maxLines = 2,
                                color = if (badge.unlocked) ExamColors.TextPrimary else ExamColors.TextSecondary,
                                textAlign = androidx.compose.ui.text.style.TextAlign.Center
                            )
                            Text(
                                if (badge.unlocked) "✓" else "${minOf(badge.value, badge.target)}/${badge.target}",
                                fontSize = 10.sp, fontWeight = FontWeight.Medium,
                                color = if (badge.unlocked) badge.color else ExamColors.TextSecondary
                            )
                        }
                    }
                }
            }
        }
    }
}

/** Draws the story-sized progress card (mirrors iOS ProgressShareCard) and opens the share sheet. */
private fun shareProgressCard(context: Context, copy: LocalizedCopy, exam: String, streak: Int, minutes: Int, questions: Int, mastery: Int) {
    val w = 1080
    val h = 1680
    val bitmap = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
    val canvas = android.graphics.Canvas(bitmap)
    val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
    paint.shader = android.graphics.LinearGradient(0f, 0f, 0f, h.toFloat(), 0xFF3A4A7A.toInt(), 0xFF1C2440.toInt(), android.graphics.Shader.TileMode.CLAMP)
    canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), paint)
    paint.shader = null

    fun text(value: String, x: Float, y: Float, size: Float, bold: Boolean, alpha: Int = 255, align: android.graphics.Paint.Align = android.graphics.Paint.Align.CENTER) {
        paint.color = android.graphics.Color.argb(alpha, 255, 255, 255)
        paint.textSize = size
        paint.typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, if (bold) android.graphics.Typeface.BOLD else android.graphics.Typeface.NORMAL)
        paint.textAlign = align
        canvas.drawText(value, x, y, paint)
    }
    text("🔥 $streak", w / 2f, 420f, 170f, true)
    text(copy.text("day_streak").uppercase(), w / 2f, 520f, 46f, true, 205)
    paint.color = android.graphics.Color.argb(36, 255, 255, 255)
    canvas.drawRoundRect(100f, 620f, w - 100f, 1180f, 60f, 60f, paint)
    listOf(
        copy.text("study_time") to copy.text("duration_hm", mapOf("h" to "${minutes / 60}", "m" to "${minutes % 60}")),
        copy.text("questions_solved") to "$questions",
        copy.text("mastery") to "$mastery%"
    ).forEachIndexed { index, (label, value) ->
        val y = 780f + index * 160f
        text(label, 160f, y, 46f, false, 220, android.graphics.Paint.Align.LEFT)
        text(value, w - 160f, y, 60f, true, 255, android.graphics.Paint.Align.RIGHT)
    }
    text("Examly · $exam", w / 2f, 1420f, 50f, true)

    val dir = java.io.File(context.cacheDir, "share").apply { mkdirs() }
    val file = java.io.File(dir, "progress.png")
    file.outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
    val uri = androidx.core.content.FileProvider.getUriForFile(context, context.packageName + ".share", file)
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "image/png"
        putExtra(Intent.EXTRA_STREAM, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(intent, copy.text("share_progress")))
}

@Composable
private fun ProgressCard(modifier: Modifier, label: String, content: @Composable () -> Unit) {
    Surface(modifier = modifier, color = ExamColors.Surface, shape = RoundedCornerShape(20.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
        Column(Modifier.padding(vertical = 16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            content()
            Text(label, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = ExamColors.TextSecondary)
        }
    }
}

@Composable
private fun WeeklyChart(copy: LocalizedCopy, weekly: List<Int>, title: String, languageCode: String) {
    val peak = maxOf(weekly.maxOrNull() ?: 0, 1)
    val total = weekly.sum()
    val today = java.time.LocalDate.now()
    val locale = java.util.Locale.forLanguageTag(languageCode)
    Surface(color = ExamColors.Surface, shape = RoundedCornerShape(20.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text(title, fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                Text(copy.text("duration_hm", mapOf("h" to "${total / 60}", "m" to "${total % 60}")), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = ExamColors.Primary)
            }
            Row(Modifier.fillMaxWidth().height(146.dp), verticalAlignment = Alignment.Bottom) {
                weekly.forEachIndexed { index, value ->
                    val isToday = index == 6
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Box(
                            Modifier.width(18.dp).height(maxOf(8f, 114f * value / peak).dp)
                                .background(
                                    androidx.compose.ui.graphics.Brush.verticalGradient(
                                        if (isToday) listOf(ExamColors.Indigo, ExamColors.Primary)
                                        else listOf(ExamColors.Primary.copy(alpha = 0.45f), ExamColors.Primary.copy(alpha = 0.25f))
                                    ),
                                    RoundedCornerShape(50)
                                )
                        )
                        Text(
                            today.minusDays((6 - index).toLong()).dayOfWeek.getDisplayName(java.time.format.TextStyle.SHORT, locale),
                            fontSize = 11.sp,
                            fontWeight = if (isToday) FontWeight.Bold else FontWeight.Medium,
                            color = if (isToday) ExamColors.TextPrimary else ExamColors.TextSecondary,
                            maxLines = 1
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionRow(title: String, percent: Int?, color: Color) {
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(28.dp).background(color.copy(alpha = 0.16f), CircleShape), contentAlignment = Alignment.Center) {
                Box(Modifier.size(12.dp).border(2.dp, color, CircleShape))
            }
            Spacer(Modifier.width(10.dp))
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, modifier = Modifier.weight(1f))
            Text(percent?.let { "$it%" } ?: "—", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = ExamColors.TextSecondary)
        }
        Box(Modifier.padding(start = 38.dp).fillMaxWidth().height(7.dp).background(ExamColors.Border, RoundedCornerShape(50))) {
            Box(Modifier.fillMaxWidth((percent ?: 0) / 100f).fillMaxHeight().background(color, RoundedCornerShape(50)))
        }
    }
}

@Composable
private fun MetricCard(value: String, label: String, modifier: Modifier = Modifier) {
    Surface(modifier = modifier, color = ExamColors.Surface, shape = RoundedCornerShape(16.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
        Column(Modifier.padding(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(value, fontSize = 19.sp, fontWeight = FontWeight.Bold)
            Text(label, color = ExamColors.TextSecondary, fontSize = 10.sp)
        }
    }
}

@Composable
fun CreditStoreScreen(setup: StudySetup, onClose: () -> Unit) {
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    val activity = remember(context) { context.findActivity() }
    val billing = remember { GooglePlayBillingService(context.applicationContext) }
    val entitlements = remember { EntitlementService() }
    var packs by remember { mutableStateOf<List<CreditPackPresentation>>(emptyList()) }
    var selectedId by remember { mutableStateOf(GooglePlayBillingService.ProductIds.AI_CREDITS_MEDIUM) }
    var balance by remember { mutableStateOf<Int?>(null) }
    var loading by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        AppServices.analytics.event(
            AnalyticsEvents.CREDIT_STORE_VIEWED,
            mapOf(AnalyticsParams.EXAM_ID to setup.exam.id)
        )
        entitlements.fetch { balance = it.credits }
    }

    DisposableEffect(billing) {
        billing.start { billing.loadCreditPacks { packs = it } }
        onDispose { billing.close() }
    }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp)
    ) {
        ToolHeader(copy.text("ai_credits"), copy.text("credits_subtitle"), onClose)
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item {
                Spacer(Modifier.height(10.dp))
                Surface(color = ExamColors.Surface, shape = RoundedCornerShape(24.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
                    Column(Modifier.fillMaxWidth().padding(20.dp)) {
                        Text(
                            copy.text("credits_balance", mapOf("count" to (balance?.toString() ?: "—"))),
                            fontSize = 26.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(copy.text("credits_desc"), color = ExamColors.TextSecondary, fontSize = 13.sp)
                    }
                }
            }
            if (packs.isEmpty()) {
                item { Text(copy.text("loading_price"), color = ExamColors.TextSecondary, fontSize = 13.sp) }
            }
            items(packs, key = { it.productId }) { pack ->
                CreditPackCard(
                    pack = pack,
                    title = copy.text("credits_pack", mapOf("count" to (CREDIT_AMOUNTS[pack.productId] ?: 0).toString())),
                    popularLabel = copy.text("most_popular").takeIf {
                        pack.productId == GooglePlayBillingService.ProductIds.AI_CREDITS_MEDIUM
                    },
                    selected = pack.productId == selectedId
                ) { selectedId = pack.productId }
            }
            message?.let { item { Text(it, color = ExamColors.TextSecondary, fontSize = 12.sp) } }
        }
        Button(
            onClick = {
                val host = activity ?: return@Button
                val productId = selectedId
                loading = true
                message = null
                AppServices.analytics.event(
                    AnalyticsEvents.CREDIT_PURCHASE_STARTED,
                    mapOf(AnalyticsParams.EXAM_ID to setup.exam.id, AnalyticsParams.PRODUCT_ID to productId)
                )
                billing.purchase(host, productId) { success, detail ->
                    loading = false
                    if (detail == "cancelled") return@purchase
                    message = if (success) copy.text("credits_added") else copy.text("purchase_not_completed")
                    AppServices.analytics.event(
                        if (success) AnalyticsEvents.CREDIT_PURCHASE_COMPLETED else AnalyticsEvents.PURCHASE_FAILED,
                        if (success) {
                            mapOf(AnalyticsParams.EXAM_ID to setup.exam.id, AnalyticsParams.PRODUCT_ID to productId)
                        } else {
                            mapOf(AnalyticsParams.PLACEMENT to "credit_store", AnalyticsParams.PRODUCT_ID to productId)
                        }
                    )
                    if (success) entitlements.fetch { balance = it.credits }
                }
            },
            enabled = !loading && packs.any { it.productId == selectedId },
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary)
        ) {
            Text(if (loading) copy.text("processing") else copy.text("buy_credits"), fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(12.dp))
    }
}

// Display only; the backend catalog decides what a verified purchase grants.
private val CREDIT_AMOUNTS = mapOf(
    GooglePlayBillingService.ProductIds.AI_CREDITS_SMALL to 50,
    GooglePlayBillingService.ProductIds.AI_CREDITS_MEDIUM to 150,
    GooglePlayBillingService.ProductIds.AI_CREDITS_LARGE to 500
)

@Composable
private fun CreditPackCard(
    pack: CreditPackPresentation,
    title: String,
    popularLabel: String?,
    selected: Boolean,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        color = ExamColors.Surface,
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(if (selected) 1.5.dp else 1.dp, if (selected) ExamColors.Primary else ExamColors.Border)
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(40.dp).background(ExamColors.SoftPurple, RoundedCornerShape(12.dp)),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Rounded.Diamond, null, tint = ExamColors.Purple)
            }
            Spacer(Modifier.width(12.dp))
            Text(title, fontWeight = FontWeight.Bold)
            popularLabel?.let {
                Spacer(Modifier.width(6.dp))
                Text(
                    it,
                    color = ExamColors.Primary,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.background(ExamColors.SoftBlue, RoundedCornerShape(50)).padding(horizontal = 7.dp, vertical = 4.dp)
                )
            }
            Spacer(Modifier.weight(1f))
            Text(pack.localizedPrice, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
fun ProfileSettingsScreen(
    setup: StudySetup,
    onClose: () -> Unit,
    onSetupChanged: (StudySetup) -> Unit,
    onProgress: () -> Unit,
    onCredits: () -> Unit,
    onRestartOnboarding: () -> Unit
) {
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    val setupStore = remember { StudySetupStore(context.applicationContext) }
    val progressStore = remember { UserProgressStore(context.applicationContext) }
    val accountService = remember { AccountService() }
    var deleteConfirm by remember { mutableStateOf(false) }
    var deletingAccount by remember { mutableStateOf(false) }
    var deleteError by remember { mutableStateOf<String?>(null) }
    var reminderHour by remember { mutableIntStateOf(progressStore.snapshot().reminderHour) }
    var languageExpanded by remember { mutableStateOf(false) }
    var showAccount by remember { mutableStateOf(false) }
    var examDate by remember { mutableStateOf(setupStore.examDate()) }
    val account by AuthService.account.collectAsState()
    val languages = com.kprl.exam.localization.AppLanguage.supported

    LazyColumn(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        item { ToolHeader(copy.text("profile_settings"), setup.exam.shortName, onClose) }
        item {
            SettingsRow(
                if (account.isAnonymous) Icons.Rounded.PersonAdd else Icons.Rounded.VerifiedUser,
                copy.text(if (account.isAnonymous) "account_save_progress" else "account_title_linked"),
                if (account.isAnonymous) copy.text("account_save_progress_hint") else account.email.orEmpty()
            ) { showAccount = true }
        }
        item {
            ExamDateField(
                title = copy.text("exam_date_label"),
                copy = copy,
                languageCode = setup.languageCode,
                date = examDate
            ) {
                examDate = it
                setupStore.setExamDate(it)
            }
        }
        item { SettingsRow(Icons.Rounded.Insights, copy.text("progress"), copy.text("progress_hint"), onProgress) }
        item { SettingsRow(Icons.Rounded.Diamond, copy.text("ai_credits"), copy.text("credits_hint"), onCredits) }
        item {
            Surface(color = ExamColors.Surface, shape = RoundedCornerShape(18.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
                Column(Modifier.padding(14.dp)) {
                    Text(copy.text("app_language"), fontWeight = FontWeight.SemiBold)
                    Box {
                        TextButton(onClick = { languageExpanded = true }) {
                            Text(languages.firstOrNull { it.first == setup.languageCode }?.second ?: setup.languageCode)
                            Icon(Icons.Rounded.ArrowDropDown, null)
                        }
                        DropdownMenu(expanded = languageExpanded, onDismissRequest = { languageExpanded = false }) {
                            languages.forEach { (code, label) ->
                                DropdownMenuItem(
                                    text = { Text(label) },
                                    onClick = {
                                        languageExpanded = false
                                        val updated = setup.copy(languageCode = code)
                                        setupStore.save(updated)
                                        onSetupChanged(updated)
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
        item {
            Surface(color = ExamColors.Surface, shape = RoundedCornerShape(18.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
                Column(Modifier.padding(14.dp)) {
                    Text(copy.text("daily_reminder"), fontWeight = FontWeight.SemiBold)
                    Text(copy.text("local_time", mapOf("hour" to reminderHour.toString())), color = ExamColors.TextSecondary, fontSize = 12.sp)
                    Slider(
                        value = reminderHour.toFloat(),
                        onValueChange = { reminderHour = it.toInt().coerceIn(6, 23) },
                        valueRange = 6f..23f,
                        steps = 16,
                        onValueChangeFinished = {
                            progressStore.setReminderHour(reminderHour)
                            AppServices.analytics.event(
                                AnalyticsEvents.REMINDER_CHANGED,
                                mapOf(
                                    AnalyticsParams.EXAM_ID to setup.exam.id,
                                    AnalyticsParams.REMINDER_HOUR to reminderHour
                                )
                            )
                            if (FirebaseBootstrap.isConfigured()) FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
                                PushTokenRegistrar.register(
                                    context = context,
                                    token = token,
                                    examId = setup.exam.id,
                                    examName = setup.exam.shortName,
                                    localReminderHour = reminderHour
                                )
                            }
                        }
                    )
                }
            }
        }
        item {
            SettingsRow(Icons.Rounded.Restore, copy.text("restore_purchases"), copy.text("restore_hint")) {
                GooglePlayBillingService(context.applicationContext).apply {
                    start { restorePurchases() }
                }
            }
        }
        item { SettingsRow(Icons.Rounded.RestartAlt, copy.text("choose_another_exam"), copy.text("choose_exam_hint"), onRestartOnboarding) }
        item {
            SettingsRow(
                Icons.Rounded.DeleteForever,
                copy.text("delete_account"),
                copy.text("delete_account_hint")
            ) { deleteConfirm = true }
        }
        deleteError?.let { message ->
            item { Text(message, color = ExamColors.Coral, fontSize = 12.sp) }
        }
        item {
            Text(
                copy.text("privacy_note"),
                color = ExamColors.TextSecondary,
                fontSize = 11.sp,
                lineHeight = 16.sp,
                modifier = Modifier.padding(vertical = 8.dp)
            )
        }
    }

    if (deleteConfirm) {
        AlertDialog(
            onDismissRequest = { if (!deletingAccount) deleteConfirm = false },
            title = { Text(copy.text("delete_confirm_title")) },
            text = {
                Text(copy.text("delete_confirm_body"))
            },
            confirmButton = {
                TextButton(
                    enabled = !deletingAccount,
                    onClick = {
                        deletingAccount = true
                        deleteError = null
                        accountService.deleteAccount { result ->
                            deletingAccount = false
                            result.onSuccess {
                                AppServices.analytics.event(
                                    AnalyticsEvents.ACCOUNT_DELETED,
                                    mapOf(AnalyticsParams.EXAM_ID to setup.exam.id)
                                )
                                setupStore.clear()
                                progressStore.reset()
                                deleteConfirm = false
                                onRestartOnboarding()
                            }.onFailure {
                                deleteError = it.message ?: "Account deletion failed."
                            }
                        }
                    }
                ) {
                    Text(if (deletingAccount) copy.text("deleting") else copy.text("delete_permanently"), color = ExamColors.Coral)
                }
            },
            dismissButton = {
                TextButton(
                    enabled = !deletingAccount,
                    onClick = { deleteConfirm = false }
                ) { Text(copy.text("cancel")) }
            }
        )
    }

    if (showAccount) {
        Dialog(
            onDismissRequest = { showAccount = false },
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            AccountScreen(copy) { showAccount = false }
        }
    }
}

@Composable
private fun SettingsRow(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, subtitle: String, onClick: () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        color = ExamColors.Surface,
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(1.dp, ExamColors.Border)
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            ExamIconBadge(icon, ExamColors.Primary, size = 34.dp)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.SemiBold)
                Text(subtitle, color = ExamColors.TextSecondary, fontSize = 11.sp)
            }
            Icon(Icons.Rounded.ChevronRight, null, tint = ExamColors.TextSecondary)
        }
    }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}


@Composable
fun MediaLabScreen(
    setup: StudySetup,
    onClose: () -> Unit,
    onNeedCredits: () -> Unit
) {
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    val ai = remember { AIGatewayClient() }

    var prompt by remember { mutableStateOf("") }
    var requestId by remember { mutableStateOf<String?>(null) }
    var status by remember { mutableStateOf<String?>(null) }
    var assetUrl by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var submitting by remember { mutableStateOf(false) }

    fun submit(kind: String) {
        val value = prompt.trim()
        if (value.isEmpty() || submitting) return
        submitting = true
        error = null
        assetUrl = null
        status = "submitting"
        AppServices.analytics.event(
            AnalyticsEvents.MEDIA_REQUESTED,
            mapOf(
                AnalyticsParams.EXAM_ID to setup.exam.id,
                AnalyticsParams.MEDIA_KIND to kind,
                AnalyticsParams.CREDIT_COST to if (kind == "video_explainer") 5 else 1
            )
        )

        ai.generateMedia(kind, value) { result ->
            submitting = false
            when (result) {
                is GatewayResult.Success -> {
                    requestId = result.value.requestId
                    status = "queued · " + result.value.creditCost + " credits"
                }
                is GatewayResult.Error -> {
                    error = result.message
                    if (result.message.contains("credit", ignoreCase = true)) {
                        onNeedCredits()
                    }
                }
            }
        }
    }

    LaunchedEffect(requestId) {
        val id = requestId ?: return@LaunchedEffect
        while (assetUrl == null && error == null) {
            delay(2_500)
            ai.mediaStatus(id) { result ->
                when (result) {
                    is GatewayResult.Success -> {
                        val previousStatus = status
                        status = result.value.status
                        result.value.assetUrl?.let { assetUrl = it }
                        if (
                            previousStatus != "completed" &&
                            (result.value.status == "completed" || result.value.assetUrl != null)
                        ) {
                            AppServices.analytics.event(
                                AnalyticsEvents.MEDIA_COMPLETED,
                                mapOf(
                                    AnalyticsParams.EXAM_ID to setup.exam.id,
                                    AnalyticsParams.MEDIA_KIND to if (result.value.assetUrl?.contains("video", ignoreCase = true) == true) "video" else "generated_media"
                                )
                            )
                        }
                    }
                    is GatewayResult.Error -> error = result.message
                }
            }
            if (status == "completed" && assetUrl == null) break
        }
    }

    Column(
        Modifier.fillMaxSize()
            .background(ExamColors.Background)
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
    ) {
        ToolHeader(
            copy.text("visual_explanation"),
            copy.text("visual_media_subtitle", mapOf("exam" to setup.exam.shortName)),
            onClose
        )
        Spacer(Modifier.height(18.dp))

        OutlinedTextField(
            value = prompt,
            onValueChange = { prompt = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(copy.text("visual_prompt_label")) },
            placeholder = { Text(copy.text("visual_prompt_placeholder")) },
            minLines = 4,
            shape = RoundedCornerShape(18.dp)
        )

        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            Button(
                onClick = { submit("image_explainer") },
                enabled = prompt.isNotBlank() && !submitting && AppServices.flags.snapshot.imageExplanationsEnabled,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary)
            ) {
                Icon(Icons.Rounded.Image, null)
                Spacer(Modifier.width(6.dp))
                Text(copy.text("image_credit"))
            }

            Button(
                onClick = { submit("video_explainer") },
                enabled = prompt.isNotBlank() && !submitting && AppServices.flags.snapshot.videoExplanationsEnabled,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Purple)
            ) {
                Icon(Icons.Rounded.Movie, null)
                Spacer(Modifier.width(6.dp))
                Text(copy.text("video_credit"))
            }
        }

        status?.let {
            Spacer(Modifier.height(14.dp))
            Surface(
                color = ExamColors.Surface,
                shape = RoundedCornerShape(16.dp),
                border = BorderStroke(1.dp, ExamColors.Border)
            ) {
                Row(Modifier.padding(13.dp), verticalAlignment = Alignment.CenterVertically) {
                    if (assetUrl == null) {
                        CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                        Spacer(Modifier.width(10.dp))
                    }
                    Text(it.replace("_", " "), fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }

        error?.let {
            Spacer(Modifier.height(10.dp))
            Text(it, color = ExamColors.Coral, fontSize = 12.sp)
        }

        assetUrl?.let { url ->
            Spacer(Modifier.height(18.dp))
            Surface(
                color = ExamColors.SoftMint,
                shape = RoundedCornerShape(20.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(Modifier.padding(18.dp)) {
                    Icon(Icons.Rounded.CheckCircle, null, tint = ExamColors.Mint)
                    Spacer(Modifier.height(8.dp))
                    Text(copy.text("media_ready"), fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    Text(
                        copy.text("generated_asset_ready"),
                        color = ExamColors.TextSecondary,
                        fontSize = 12.sp
                    )
                    Spacer(Modifier.height(12.dp))
                    Button(
                        onClick = {
                            context.startActivity(
                                Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                            )
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary)
                    ) {
                        Text(copy.text("open_generated_asset"))
                    }
                }
            }
        }

        Spacer(Modifier.weight(1f))
        Text(
            copy.text("media_cost_note"),
            color = ExamColors.TextSecondary,
            fontSize = 11.sp,
            lineHeight = 16.sp
        )
        Spacer(Modifier.height(12.dp))
    }
}
