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
import com.kprl.exam.data.StudySetup
import com.kprl.exam.domain.FlashcardRating
import com.kprl.exam.domain.FlashcardScheduler
import com.kprl.exam.domain.SampleQuestionFactory
import com.kprl.exam.domain.StudyQuestion
import com.kprl.exam.platform.ai.AIGatewayClient
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
    onStart: (List<StudyQuestion>) -> Unit
) {
    val gateway = remember { AIGatewayClient() }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var questionCount by remember { mutableIntStateOf(10) }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp)
    ) {
        ToolHeader("Mock Exam", "${setup.exam.shortName} · timed mixed set", onClose)
        Spacer(Modifier.height(18.dp))

        Surface(
            color = ExamColors.Surface,
            shape = RoundedCornerShape(22.dp),
            border = BorderStroke(1.dp, ExamColors.Border)
        ) {
            Column(Modifier.padding(18.dp)) {
                Text("Exam simulation", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                Text(
                    "Questions are generated against your selected exam context and recorded as a mock session.",
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
                            label = { Text("$count questions") }
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
                            error = result.message
                            val fallback = SampleQuestionFactory.forSetup(setup)
                            onStart(List(questionCount) { i -> fallback[i % fallback.size].copy(id = "mock_$i") })
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
            Text(if (loading) "Building mock…" else "Start mock", fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(12.dp))
    }
}

@Composable
fun MistakesScreen(setup: StudySetup, onClose: () -> Unit, onPractice: () -> Unit) {
    val context = LocalContext.current
    val repository = remember { LearningRepository(LearningDatabase(context.applicationContext)) }
    var mistakes by remember { mutableStateOf(repository.mistakes(setup.exam.id)) }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp)
    ) {
        ToolHeader("Mistakes", "Your unresolved Error DNA", onClose)
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
                    Text("No unresolved mistakes", fontWeight = FontWeight.Bold)
                    Text("New mistakes will appear here automatically.", color = ExamColors.TextSecondary, fontSize = 12.sp)
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
                                "${item.errorType.replace("_", " ")} · selected: ${item.selectedAnswer ?: "—"}",
                                color = ExamColors.TextSecondary,
                                fontSize = 11.sp
                            )
                            item.correctAnswer?.let {
                                Text("Correct: $it", color = ExamColors.Mint, fontSize = 12.sp, modifier = Modifier.padding(top = 5.dp))
                            }
                            TextButton(
                                onClick = {
                                    repository.resolveMistake(item.id)
                                    mistakes = repository.mistakes(setup.exam.id)
                                }
                            ) { Text("Mark resolved") }
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
            Text("Practice weak areas", fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(12.dp))
    }
}

@Composable
fun FlashcardsScreen(setup: StudySetup, onClose: () -> Unit) {
    val context = LocalContext.current
    val scheduler = remember { FlashcardScheduler(context.applicationContext) }
    val allCards = remember(setup.exam.id) { SampleQuestionFactory.forSetup(setup) }
    var cards by remember { mutableStateOf(allCards.filter { scheduler.isDue(it.id) }.ifEmpty { allCards }) }
    var index by remember { mutableIntStateOf(0) }
    var revealed by remember { mutableStateOf(false) }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp)
    ) {
        ToolHeader("Flashcards", "Spaced repetition", onClose)
        Spacer(Modifier.height(24.dp))

        if (cards.isEmpty()) {
            Text("Nothing due right now.", color = ExamColors.TextSecondary)
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
                    Text(if (revealed) "Rate your recall" else "Tap to reveal", color = ExamColors.TextSecondary, fontSize = 12.sp)
                }
            }

            if (revealed) {
                Spacer(Modifier.height(18.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    val ratings = listOf(
                        "Again" to FlashcardRating.AGAIN,
                        "Hard" to FlashcardRating.HARD,
                        "Good" to FlashcardRating.GOOD,
                        "Easy" to FlashcardRating.EASY
                    )
                    ratings.forEach { (label, rating) ->
                        OutlinedButton(
                            onClick = {
                                scheduler.review(card.id, rating)
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
    onStart: (List<StudyQuestion>) -> Unit
) {
    val gateway = remember { AIGatewayClient() }
    var topic by remember { mutableStateOf("") }
    var count by remember { mutableIntStateOf(5) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp)
    ) {
        ToolHeader("Create Practice", "Generate a focused set", onClose)
        Spacer(Modifier.height(18.dp))

        OutlinedTextField(
            value = topic,
            onValueChange = { topic = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Topic or instruction") },
            placeholder = { Text("e.g. Algebra inequalities, inference questions…") },
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
                            else error = "The generated set was invalid. Try a more specific topic."
                        }
                        is GatewayResult.Error -> error = result.message
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
            Text(if (loading) "Generating…" else "Generate practice", fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(12.dp))
    }
}

@Composable
fun FocusScreen(setup: StudySetup, onClose: () -> Unit) {
    val context = LocalContext.current
    var focusMinutes by remember { mutableIntStateOf(25) }
    var remaining by remember { mutableIntStateOf(25 * 60) }
    var running by remember { mutableStateOf(false) }

    LaunchedEffect(running, remaining) {
        if (running && remaining > 0) {
            delay(1_000)
            remaining--
        } else if (running && remaining == 0) {
            running = false
            sendFocusNotification(context, setup.exam.shortName)
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
        ToolHeader("Focus", "${setup.exam.shortName} Pomodoro", onClose)
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
                Text(if (running) "Stay with it" else "Ready", color = ExamColors.TextSecondary)
            }
        }
        Spacer(Modifier.height(32.dp))
        Button(
            onClick = { running = !running },
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary)
        ) {
            Icon(if (running) Icons.Rounded.Pause else Icons.Rounded.PlayArrow, null)
            Spacer(Modifier.width(8.dp))
            Text(if (running) "Pause" else "Start focus", fontWeight = FontWeight.Bold)
        }
        TextButton(onClick = { reset(focusMinutes) }) { Text("Reset") }
    }
}

private fun sendFocusNotification(context: Context, examName: String) {
    val manager = context.getSystemService(NotificationManager::class.java)
    val channelId = "focus_complete"
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        manager.createNotificationChannel(
            NotificationChannel(channelId, "Focus timer", NotificationManager.IMPORTANCE_DEFAULT)
        )
    }
    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        android.app.Notification.Builder(context, channelId)
    } else android.app.Notification.Builder(context)

    manager.notify(
        4201,
        builder.setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Focus session complete")
            .setContentText("$examName · Nice work. Take a short break.")
            .setAutoCancel(true)
            .build()
    )
}

@Composable
fun ProgressScreen(setup: StudySetup, onClose: () -> Unit) {
    val context = LocalContext.current
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
        item { ToolHeader("Progress", "${setup.exam.shortName} learning profile", onClose) }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MetricCard("$mastery%", "Mastery", Modifier.weight(1f))
                MetricCard("${user.streak}", "Streak", Modifier.weight(1f))
                MetricCard("${user.xp}", "XP", Modifier.weight(1f))
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MetricCard("${progress.sessions}", "Sessions", Modifier.weight(1f))
                MetricCard("$accuracy%", "Accuracy", Modifier.weight(1f))
                MetricCard("${progress.studyMinutes}m", "Study", Modifier.weight(1f))
            }
        }
        item { Text("Error DNA", fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp)) }
        if (errorDNA.isEmpty()) {
            item { Text("No active error pattern yet.", color = ExamColors.TextSecondary) }
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
    val activity = remember(context) { context.findActivity() }
    val billing = remember { GooglePlayBillingService(context.applicationContext) }
    var price by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }

    DisposableEffect(billing) {
        billing.start { billing.loadCreditPrice { price = it } }
        onDispose { billing.close() }
    }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp)
    ) {
        ToolHeader("AI Credits", "For high-cost image & video generation", onClose)
        Spacer(Modifier.height(20.dp))
        Surface(color = ExamColors.Surface, shape = RoundedCornerShape(24.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
            Column(Modifier.padding(20.dp)) {
                Text("25 credits", fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Text("Use credits only for expensive generated visuals/video. Core study stays subscription/free-limit based.", color = ExamColors.TextSecondary, fontSize = 13.sp)
                Spacer(Modifier.height(18.dp))
                Text(price ?: "Loading local price…", color = ExamColors.Primary, fontWeight = FontWeight.Bold)
            }
        }
        message?.let { Text(it, color = ExamColors.TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(top = 10.dp)) }
        Spacer(Modifier.weight(1f))
        Button(
            onClick = {
                val host = activity ?: return@Button
                loading = true
                billing.purchase(host, GooglePlayBillingService.ProductIds.AI_CREDITS_SMALL) { success, detail ->
                    loading = false
                    message = if (success) "Credits added." else detail ?: "Purchase not completed."
                }
            },
            enabled = price != null && !loading,
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary)
        ) {
            Text(if (loading) "Processing…" else "Buy 25 credits", fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(12.dp))
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
    val setupStore = remember { StudySetupStore(context.applicationContext) }
    val progressStore = remember { UserProgressStore(context.applicationContext) }
    var reminderHour by remember { mutableIntStateOf(progressStore.snapshot().reminderHour) }
    var languageExpanded by remember { mutableStateOf(false) }
    val languages = listOf(
        "en" to "English", "tr" to "Türkçe", "de" to "Deutsch", "es" to "Español",
        "fr" to "Français", "pt" to "Português", "ko" to "한국어", "ja" to "日本語", "hi" to "हिन्दी"
    )

    LazyColumn(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        item { ToolHeader("Profile & Settings", setup.exam.shortName, onClose) }
        item { SettingsRow(Icons.Rounded.Insights, "Progress", "Mastery, streak, XP and Error DNA", onProgress) }
        item { SettingsRow(Icons.Rounded.Diamond, "AI Credits", "High-cost image/video credits", onCredits) }
        item {
            Surface(color = ExamColors.Surface, shape = RoundedCornerShape(18.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
                Column(Modifier.padding(14.dp)) {
                    Text("App language", fontWeight = FontWeight.SemiBold)
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
                    Text("Daily reminder", fontWeight = FontWeight.SemiBold)
                    Text("$reminderHour:00 local time", color = ExamColors.TextSecondary, fontSize = 12.sp)
                    Slider(
                        value = reminderHour.toFloat(),
                        onValueChange = { reminderHour = it.toInt().coerceIn(6, 23) },
                        valueRange = 6f..23f,
                        steps = 16,
                        onValueChangeFinished = {
                            progressStore.setReminderHour(reminderHour)
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
            SettingsRow(Icons.Rounded.Restore, "Restore purchases", "Ask the store to restore active purchases") {
                GooglePlayBillingService(context.applicationContext).apply {
                    start { restorePurchases() }
                }
            }
        }
        item { SettingsRow(Icons.Rounded.RestartAlt, "Choose another exam", "Restart onboarding and build a new plan", onRestartOnboarding) }
        item {
            Text(
                "Privacy: study files stay scoped to your authenticated account. AI provider keys are server-side and are never shipped in the app.",
                color = ExamColors.TextSecondary,
                fontSize = 11.sp,
                lineHeight = 16.sp,
                modifier = Modifier.padding(vertical = 8.dp)
            )
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
                        status = result.value.status
                        result.value.assetUrl?.let { assetUrl = it }
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
        ToolHeader("Visual Explanation", setup.exam.shortName + " · credit-based AI media", onClose)
        Spacer(Modifier.height(18.dp))

        OutlinedTextField(
            value = prompt,
            onValueChange = { prompt = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("What should the visual explain?") },
            placeholder = { Text("e.g. Explain mitosis as a clean study diagram") },
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
                Text("Image · 1")
            }

            Button(
                onClick = { submit("video_explainer") },
                enabled = prompt.isNotBlank() && !submitting && AppServices.flags.snapshot.videoExplanationsEnabled,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Purple)
            ) {
                Icon(Icons.Rounded.Movie, null)
                Spacer(Modifier.width(6.dp))
                Text("Video · 5")
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
                    Text("Media ready", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    Text(
                        "The generated asset is ready to review.",
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
                        Text("Open generated asset")
                    }
                }
            }
        }

        Spacer(Modifier.weight(1f))
        Text(
            "Image/video generation is optional and uses credits because provider costs are materially higher than normal tutoring.",
            color = ExamColors.TextSecondary,
            fontSize = 11.sp,
            lineHeight = 16.sp
        )
        Spacer(Modifier.height(12.dp))
    }
}
