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

@Composable
fun FocusScreen(setup: StudySetup, onClose: () -> Unit) {
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    var focusMinutes by remember { mutableIntStateOf(25) }
    var remaining by remember { mutableIntStateOf(25 * 60) }
    var running by remember { mutableStateOf(false) }

    LaunchedEffect(running, remaining) {
        if (running && remaining > 0) {
            delay(1_000)
            remaining--
        } else if (running && remaining == 0) {
            running = false
            AppServices.analytics.event(
                AnalyticsEvents.FOCUS_COMPLETED,
                mapOf(
                    AnalyticsParams.EXAM_ID to setup.exam.id,
                    AnalyticsParams.DURATION_SECONDS to focusMinutes * 60
                )
            )
            sendFocusNotification(
                context,
                copy.text("focus_complete"),
                copy.text("focus_break", mapOf("exam" to setup.exam.shortName))
            )
        }
    }

    fun reset(minutes: Int) {
        focusMinutes = minutes
        remaining = minutes * 60
        running = false
    }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        ToolHeader(copy.text("focus"), copy.text("focus_pomodoro", mapOf("exam" to setup.exam.shortName)), onClose)
        Spacer(Modifier.height(28.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(25, 40, 50).forEach { minutes ->
                FilterChip(selected = focusMinutes == minutes, onClick = { reset(minutes) }, label = { Text("$minutes min") })
            }
        }
        Spacer(Modifier.height(46.dp))
        Box(
            Modifier.size(230.dp).background(ExamColors.Surface, RoundedCornerShape(115.dp)),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    "%02d:%02d".format(remaining / 60, remaining % 60),
                    fontSize = 46.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(if (running) copy.text("stay_with_it") else copy.text("ready"), color = ExamColors.TextSecondary)
            }
        }
        Spacer(Modifier.height(32.dp))
        Button(
            onClick = {
                if (!running) {
                    AppServices.analytics.event(
                        AnalyticsEvents.FOCUS_STARTED,
                        mapOf(
                            AnalyticsParams.EXAM_ID to setup.exam.id,
                            AnalyticsParams.DURATION_SECONDS to remaining
                        )
                    )
                }
                running = !running
            },
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary)
        ) {
            Icon(if (running) Icons.Rounded.Pause else Icons.Rounded.PlayArrow, null)
            Spacer(Modifier.width(8.dp))
            Text(if (running) copy.text("pause") else copy.text("start_focus"), fontWeight = FontWeight.Bold)
        }
        TextButton(onClick = { reset(focusMinutes) }) { Text(copy.text("reset")) }
    }
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

@Composable
fun ProgressScreen(setup: StudySetup, onClose: () -> Unit) {
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    val repository = remember { LearningRepository(LearningDatabase(context.applicationContext)) }
    val progress = remember { repository.progressSummary(setup.exam.id) }
    val errorDNA = remember { repository.errorDNA(setup.exam.id) }
    val user = remember { UserProgressStore(context.applicationContext).snapshot() }
    val mastery = if (progress.masteryPercent == 0) setup.diagnosticPercent else progress.masteryPercent
    val accuracy = if (progress.questions == 0) 0 else progress.correct * 100 / progress.questions

    LazyColumn(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        item { ToolHeader(copy.text("progress"), copy.text("learning_profile", mapOf("exam" to setup.exam.shortName)), onClose) }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MetricCard("$mastery%", copy.text("mastery"), Modifier.weight(1f))
                MetricCard("${user.streak}", copy.text("streak"), Modifier.weight(1f))
                MetricCard("${user.xp}", copy.text("xp"), Modifier.weight(1f))
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MetricCard("${progress.sessions}", copy.text("sessions"), Modifier.weight(1f))
                MetricCard("$accuracy%", copy.text("accuracy"), Modifier.weight(1f))
                MetricCard("${progress.studyMinutes}m", copy.text("study_time"), Modifier.weight(1f))
            }
        }
        item { Text(copy.text("error_dna"), fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp)) }
        if (errorDNA.isEmpty()) {
            item { Text(copy.text("no_error_pattern"), color = ExamColors.TextSecondary) }
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
    val account by AuthService.account.collectAsState()
    val languages = listOf(
        "en" to "English", "tr" to "Türkçe", "de" to "Deutsch", "es" to "Español",
        "fr" to "Français", "pt" to "Português", "ko" to "한국어", "ja" to "日本語", "hi" to "हिन्दी"
    )

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
                            FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
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
            Icon(icon, null, tint = ExamColors.Primary)
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
