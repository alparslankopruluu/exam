package com.kprl.exam.ui.question

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.material.icons.rounded.OutlinedFlag
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.border
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.data.StudySetup
import com.kprl.exam.analytics.AnalyticsEvents
import com.kprl.exam.analytics.AnalyticsParams
import com.kprl.exam.platform.AppServices
import com.kprl.exam.domain.SampleQuestionFactory
import com.kprl.exam.domain.StudyQuestion
import com.kprl.exam.localization.LocalizedCopy
import com.kprl.exam.platform.ai.AIGatewayClient
import com.kprl.exam.platform.ai.GatewayResult
import com.kprl.exam.platform.persistence.LearningDatabase
import com.kprl.exam.platform.persistence.LearningRepository
import com.kprl.exam.platform.persistence.UserProgressStore
import com.kprl.exam.ui.theme.ExamColors
import kotlinx.coroutines.delay

@Composable
fun QuestionSessionScreen(
    setup: StudySetup,
    onClose: () -> Unit,
    questionsOverride: List<StudyQuestion>? = null,
    sessionType: String = "quick_practice",
    onSessionCompleted: (() -> Unit)? = null,
    onPaywall: (String) -> Unit = {},
    timeLimitSeconds: Int? = null
) {
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    val repository = remember { LearningRepository(LearningDatabase(context.applicationContext)) }
    val progressStore = remember { UserProgressStore(context.applicationContext) }
    val aiGateway = remember { AIGatewayClient() }
    val questions = remember(setup.exam.id, questionsOverride) {
        questionsOverride?.takeIf { it.isNotEmpty() } ?: SampleQuestionFactory.forSetup(setup)
    }
    val sessionStartedAt = remember { System.currentTimeMillis() }
    var questionStartedAt by remember { mutableLongStateOf(System.currentTimeMillis()) }
    var index by remember { mutableIntStateOf(0) }
    var selected by remember { mutableStateOf<Int?>(null) }
    var correctCount by remember { mutableIntStateOf(0) }
    var completed by remember { mutableStateOf(false) }
    var earnedXp by remember { mutableIntStateOf(0) }
    var completedDurationSeconds by remember { mutableIntStateOf(0) }
    var simplerExplanation by remember { mutableStateOf<String?>(null) }
    var tutorAnswer by remember { mutableStateOf<String?>(null) }
    var helperLoading by remember { mutableStateOf(false) }
    var remainingSeconds by remember(timeLimitSeconds) {
        mutableIntStateOf(timeLimitSeconds ?: 0)
    }
    // Mock exams hide feedback until the end: answers and flags per question index.
    val isMock = timeLimitSeconds != null
    val mockAnswers = remember { mutableStateMapOf<Int, Int>() }
    val flagged = remember { mutableStateListOf<Int>() }

    /** Records every mock answer once the exam ends (on finish or when time runs out). */
    fun scoreMock() {
        correctCount = 0
        questions.forEachIndexed { questionIndex, question ->
            val answer = mockAnswers[questionIndex] ?: return@forEachIndexed
            val correct = answer == question.correctIndex
            if (correct) correctCount++
            repository.recordAnswer(
                examId = setup.exam.id,
                skillId = setup.exam.id + ":" + question.topic.lowercase().replace(" ", "_"),
                questionId = question.id,
                correct = correct,
                responseTimeMs = 0,
                selectedAnswer = question.options[answer],
                correctAnswer = question.options[question.correctIndex],
                errorType = if (correct) "none" else "concept"
            )
        }
    }

    LaunchedEffect(Unit) {
        AppServices.analytics.event(
            AnalyticsEvents.STUDY_SESSION_STARTED,
            mapOf(
                AnalyticsParams.EXAM_ID to setup.exam.id,
                AnalyticsParams.CONTENT_PACK_ID to setup.exam.syllabusPackId,
                AnalyticsParams.SESSION_TYPE to sessionType,
                AnalyticsParams.ITEM_COUNT to questions.size
            )
        )
        if (sessionType == "daily_plan") {
            AppServices.analytics.event(
                AnalyticsEvents.DAILY_MISSION_STARTED,
                mapOf(AnalyticsParams.EXAM_ID to setup.exam.id)
            )
        } else if (sessionType == "mock_exam") {
            AppServices.analytics.event(
                AnalyticsEvents.MOCK_STARTED,
                mapOf(
                    AnalyticsParams.EXAM_ID to setup.exam.id,
                    AnalyticsParams.ITEM_COUNT to questions.size
                )
            )
        }
    }

    fun finishSession() {
        if (completed) return
        if (isMock) scoreMock()
        val completedAt = System.currentTimeMillis()
        repository.saveSession(
            examId = setup.exam.id,
            sessionType = sessionType,
            startedAt = sessionStartedAt,
            completedAt = completedAt,
            correctCount = correctCount,
            totalCount = questions.size
        )
        completedDurationSeconds = ((completedAt - sessionStartedAt) / 1000L).toInt().coerceAtLeast(0)
        val before = progressStore.snapshot()
        val after = progressStore.recordSession(
            correct = correctCount,
            total = questions.size,
            durationSeconds = ((completedAt - sessionStartedAt) / 1000L).toInt()
        )
        earnedXp = (after.xp - before.xp).coerceAtLeast(0)
        val scorePercent = if (questions.isEmpty()) 0 else correctCount * 100 / questions.size

        AppServices.analytics.event(
            AnalyticsEvents.STUDY_SESSION_COMPLETED,
            mapOf(
                AnalyticsParams.EXAM_ID to setup.exam.id,
                AnalyticsParams.CONTENT_PACK_ID to setup.exam.syllabusPackId,
                AnalyticsParams.SESSION_TYPE to sessionType,
                AnalyticsParams.ITEM_COUNT to questions.size,
                AnalyticsParams.SCORE_PERCENT to scorePercent,
                AnalyticsParams.DURATION_SECONDS to completedDurationSeconds,
                AnalyticsParams.XP_EARNED to earnedXp
            )
        )
        if (sessionType == "daily_plan") {
            AppServices.analytics.event(
                AnalyticsEvents.DAILY_MISSION_COMPLETED,
                mapOf(
                    AnalyticsParams.EXAM_ID to setup.exam.id,
                    AnalyticsParams.SCORE_PERCENT to scorePercent,
                    AnalyticsParams.DURATION_SECONDS to completedDurationSeconds
                )
            )
        } else if (sessionType == "mock_exam") {
            AppServices.analytics.event(
                AnalyticsEvents.MOCK_COMPLETED,
                mapOf(
                    AnalyticsParams.EXAM_ID to setup.exam.id,
                    AnalyticsParams.SCORE_PERCENT to scorePercent,
                    AnalyticsParams.DURATION_SECONDS to completedDurationSeconds
                )
            )
        }
        if (after.streak > before.streak) {
            AppServices.analytics.event(
                AnalyticsEvents.STREAK_EXTENDED,
                mapOf(
                    AnalyticsParams.STREAK_COUNT to after.streak,
                    AnalyticsParams.EXAM_ID to setup.exam.id
                )
            )
        }

        onSessionCompleted?.invoke()
        completed = true
    }

    LaunchedEffect(timeLimitSeconds, completed) {
        if (timeLimitSeconds != null && !completed) {
            while (remainingSeconds > 0 && !completed) {
                delay(1_000)
                remainingSeconds--
            }
            if (remainingSeconds <= 0 && !completed) {
                finishSession()
            }
        }
    }

    if (completed) {
        SessionCompleteScreen(
            examName = setup.exam.shortName,
            correct = correctCount,
            total = questions.size,
            earnedXp = earnedXp,
            sessionType = sessionType,
            durationSeconds = completedDurationSeconds,
            copy = copy,
            onDone = onClose
        )
        return
    }

    val question = questions[index]

    Column(
        Modifier.fillMaxSize()
            .background(ExamColors.Background)
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onClose) {
                Icon(Icons.Rounded.Close, "Close")
            }
            LinearProgressIndicator(
                progress = { (index + if (selected != null) 1f else 0f) / questions.size.toFloat() },
                modifier = Modifier.weight(1f).height(6.dp),
                color = ExamColors.Primary,
                trackColor = ExamColors.Border
            )
            Spacer(Modifier.width(10.dp))
            if (isMock) {
                Row(
                    Modifier.background(ExamColors.Coral.copy(alpha = 0.1f), RoundedCornerShape(50)).padding(horizontal = 10.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Rounded.Schedule, null, tint = ExamColors.Coral, modifier = Modifier.size(15.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(
                        "%02d:%02d".format(remainingSeconds / 60, remainingSeconds % 60),
                        color = ExamColors.Coral, fontSize = 13.sp, fontWeight = FontWeight.Bold
                    )
                }
            } else {
                Text("${index + 1}/${questions.size}", color = ExamColors.TextSecondary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            }
        }

        if (isMock) {
            // One chip per topic in question order; tapping jumps to that topic's first question.
            val topics = questions.map { it.topic }.distinct()
            Row(Modifier.padding(top = 12.dp).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                topics.forEach { topic ->
                    val current = question.topic == topic
                    Box(
                        Modifier.height(34.dp)
                            .background(if (current) ExamColors.SoftBlue else ExamColors.Surface, RoundedCornerShape(50))
                            .border(1.dp, if (current) ExamColors.Primary.copy(alpha = 0.4f) else ExamColors.Border, RoundedCornerShape(50))
                            .clickable { questions.indexOfFirst { it.topic == topic }.takeIf { it >= 0 }?.let { index = it } }
                            .padding(horizontal = 14.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(topic, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = if (current) ExamColors.Primary else ExamColors.TextSecondary)
                    }
                }
            }
        }

        Spacer(Modifier.height(if (isMock) 18.dp else 28.dp))
        Text(
            if (isMock) copy.text("question_n_of", mapOf("n" to "${index + 1}", "total" to "${questions.size}")) else question.topic.uppercase(),
            color = if (isMock) ExamColors.TextSecondary else ExamColors.Primary,
            fontSize = if (isMock) 13.sp else 11.sp,
            fontWeight = FontWeight.Bold
        )
        Spacer(Modifier.height(10.dp))
        Text(question.prompt, fontSize = 24.sp, lineHeight = 31.sp, fontWeight = FontWeight.Bold)

        Spacer(Modifier.height(24.dp))
        question.options.forEachIndexed { optionIndex, option ->
            if (isMock) {
                // Mock option: selectable and changeable, no correctness shown until the end.
                val chosen = mockAnswers[index] == optionIndex
                Surface(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp).clickable { mockAnswers[index] = optionIndex },
                    shape = RoundedCornerShape(18.dp),
                    color = if (chosen) ExamColors.SoftBlue else ExamColors.Surface,
                    border = BorderStroke(if (chosen) 1.5.dp else 1.dp, if (chosen) ExamColors.Primary else ExamColors.Border)
                ) {
                    Row(Modifier.padding(15.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            Modifier.size(28.dp).background(if (chosen) ExamColors.Primary else ExamColors.Background, CircleShape),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(('A'.code + optionIndex).toChar().toString(), color = if (chosen) Color.White else ExamColors.TextSecondary, fontWeight = FontWeight.Bold)
                        }
                        Spacer(Modifier.width(10.dp))
                        Text(option, modifier = Modifier.weight(1f), fontWeight = FontWeight.Medium)
                    }
                }
                return@forEachIndexed
            }
            val isSelected = selected == optionIndex
            val isCorrect = selected != null && optionIndex == question.correctIndex
            val border = when {
                isCorrect -> ExamColors.Mint
                isSelected -> ExamColors.Coral
                else -> ExamColors.Border
            }
            val background = when {
                isCorrect -> ExamColors.SoftMint
                isSelected -> ExamColors.Coral.copy(alpha = .08f)
                else -> ExamColors.Surface
            }

            Surface(
                modifier = Modifier.fillMaxWidth()
                    .padding(vertical = 5.dp)
                    .clickable(enabled = selected == null) {
                        val answeredAt = System.currentTimeMillis()
                        val correct = optionIndex == question.correctIndex
                        selected = optionIndex
                        if (correct) correctCount++

                        val responseMs = answeredAt - questionStartedAt

                        repository.recordAnswer(
                            examId = setup.exam.id,
                            skillId = setup.exam.id + ":" + question.topic.lowercase().replace(" ", "_"),
                            questionId = question.id,
                            correct = correct,
                            responseTimeMs = responseMs,
                            selectedAnswer = option,
                            correctAnswer = question.options[question.correctIndex],
                            errorType = if (correct) "none" else "concept"
                        )
                        AppServices.analytics.event(
                            AnalyticsEvents.QUESTION_ANSWERED,
                            mapOf(
                                AnalyticsParams.EXAM_ID to setup.exam.id,
                                AnalyticsParams.CONTENT_PACK_ID to setup.exam.syllabusPackId,
                                AnalyticsParams.TOPIC_ID to question.topic.lowercase().replace(" ", "_"),
                                AnalyticsParams.ANSWER_CORRECT to correct,
                                AnalyticsParams.RESPONSE_TIME_MS to responseMs,
                                AnalyticsParams.SESSION_TYPE to sessionType,
                                AnalyticsParams.ERROR_TYPE to if (correct) "none" else "concept"
                            )
                        )
                    },
                shape = RoundedCornerShape(18.dp),
                color = background,
                border = BorderStroke(if (isCorrect || isSelected) 1.5.dp else 1.dp, border)
            ) {
                Row(Modifier.padding(15.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        ('A'.code + optionIndex).toChar().toString(),
                        color = if (isCorrect) ExamColors.Mint else ExamColors.TextSecondary,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.width(28.dp)
                    )
                    Text(option, modifier = Modifier.weight(1f), fontWeight = FontWeight.Medium)
                    if (isCorrect) Icon(Icons.Rounded.CheckCircle, null, tint = ExamColors.Mint)
                }
            }
        }

        if (isMock) {
            Spacer(Modifier.weight(1f))
            val last = index == questions.lastIndex
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                val isFlagged = index in flagged
                Surface(
                    onClick = { if (isFlagged) flagged.remove(index) else flagged.add(index) },
                    modifier = Modifier.weight(1f).height(56.dp),
                    shape = RoundedCornerShape(18.dp),
                    color = ExamColors.Surface,
                    border = BorderStroke(1.dp, ExamColors.Border)
                ) {
                    Row(horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                        Icon(if (isFlagged) Icons.Rounded.Flag else Icons.Rounded.OutlinedFlag, null, tint = if (isFlagged) ExamColors.Amber else ExamColors.TextPrimary)
                        Spacer(Modifier.width(6.dp))
                        Text(copy.text("mark"), fontWeight = FontWeight.Bold, color = if (isFlagged) ExamColors.Amber else ExamColors.TextPrimary)
                    }
                }
                Button(
                    onClick = { if (last) finishSession() else index++ },
                    modifier = Modifier.weight(1f).height(56.dp),
                    shape = RoundedCornerShape(18.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary),
                    elevation = ButtonDefaults.buttonElevation(0.dp)
                ) {
                    Text(copy.text(if (last) "finish_session" else "next"), fontWeight = FontWeight.Bold)
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        if (selected != null && !isMock) {
            Spacer(Modifier.height(18.dp))
            Surface(
                color = ExamColors.Surface,
                shape = RoundedCornerShape(20.dp),
                border = BorderStroke(1.dp, ExamColors.Border)
            ) {
                Column(Modifier.padding(16.dp)) {
                    val correct = selected == question.correctIndex
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            if (correct) Icons.Rounded.CheckCircle else Icons.Rounded.Cancel, null,
                            tint = if (correct) ExamColors.Mint else ExamColors.Coral,
                            modifier = Modifier.size(30.dp)
                        )
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text(
                                copy.text(if (correct) "nice_work" else "not_quite"),
                                fontWeight = FontWeight.Bold,
                                fontSize = 17.sp,
                                color = if (correct) ExamColors.TextPrimary else ExamColors.Coral
                            )
                            if (!correct) {
                                Text(
                                    copy.text("correct_answer_is", mapOf("letter" to ('A'.code + question.correctIndex).toChar().toString())),
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = ExamColors.TextSecondary
                                )
                            }
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                    Text(copy.text("explanation").uppercase(), fontSize = 11.sp, fontWeight = FontWeight.Bold, color = ExamColors.TextSecondary)
                    Spacer(Modifier.height(6.dp))
                    Text(
                        simplerExplanation ?: question.explanation,
                        color = ExamColors.TextSecondary,
                        fontSize = 13.sp,
                        lineHeight = 19.sp
                    )
                    tutorAnswer?.let {
                        Spacer(Modifier.height(10.dp))
                        Text(copy.text("ai_tutor"), color = ExamColors.Purple, fontWeight = FontWeight.Bold, fontSize = 11.sp)
                        Text(it, color = ExamColors.TextSecondary, fontSize = 12.sp, lineHeight = 18.sp)
                    }
                    if (helperLoading) {
                        Spacer(Modifier.height(10.dp))
                        LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                    }
                    Spacer(Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        AssistChip(
                            onClick = {
                                AppServices.analytics.event(
                                    AnalyticsEvents.EXPLANATION_REQUESTED,
                                    mapOf(
                                        AnalyticsParams.EXAM_ID to setup.exam.id,
                                        AnalyticsParams.SOURCE to "simpler_local",
                                        AnalyticsParams.SESSION_TYPE to sessionType
                                    )
                                )
                                simplerExplanation = copy.text("simpler_explanation")
                            },
                            label = { Text(copy.text("explain_simpler")) }
                        )
                        AssistChip(
                            onClick = {
                                if (!helperLoading) {
                                    AppServices.analytics.event(
                                        AnalyticsEvents.EXPLANATION_REQUESTED,
                                        mapOf(
                                            AnalyticsParams.EXAM_ID to setup.exam.id,
                                            AnalyticsParams.SOURCE to "ai_tutor",
                                            AnalyticsParams.SESSION_TYPE to sessionType
                                        )
                                    )
                                    helperLoading = true
                                    aiGateway.askTutor(
                                        setup,
                                        "Explain this question and why the correct answer is '${question.options[question.correctIndex]}': ${question.prompt}"
                                    ) { result ->
                                        helperLoading = false
                                        when (result) {
                                            is GatewayResult.Success -> tutorAnswer = result.value
                                            is GatewayResult.Error -> {
                                                if (result.message.contains("Daily AI limit", ignoreCase = true)) {
                                                    onPaywall("ai_limit")
                                                } else {
                                                    tutorAnswer = result.message
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            label = { Text(copy.text("ask_tutor")) }
                        )
                    }
                }
            }

            Spacer(Modifier.weight(1f))
            Button(
                onClick = {
                    if (index == questions.lastIndex) {
                        finishSession()
                    } else {
                        index++
                        selected = null
                        simplerExplanation = null
                        tutorAnswer = null
                        questionStartedAt = System.currentTimeMillis()
                    }
                },
                modifier = Modifier.fillMaxWidth().height(56.dp),
                shape = RoundedCornerShape(18.dp),
                colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary),
                elevation = ButtonDefaults.buttonElevation(0.dp)
            ) {
                Text(
                    if (index == questions.lastIndex) copy.text("finish_session") else copy.text("next_question"),
                    fontWeight = FontWeight.Bold
                )
            }
            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
private fun SessionCompleteScreen(
    examName: String,
    correct: Int,
    total: Int,
    earnedXp: Int,
    sessionType: String,
    durationSeconds: Int,
    copy: LocalizedCopy,
    onDone: () -> Unit
) {
    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(
            Modifier.size(86.dp).background(ExamColors.SoftMint, RoundedCornerShape(28.dp)),
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Rounded.CheckCircle, null, tint = ExamColors.Mint, modifier = Modifier.size(44.dp))
        }
        Spacer(Modifier.height(20.dp))
        Text(copy.text("session_complete"), fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(7.dp))
        Text(
            copy.text(
                "result_correct",
                mapOf(
                    "correct" to correct.toString(),
                    "total" to total.toString(),
                    "exam" to examName
                )
            ),
            color = ExamColors.TextSecondary
        )
        Spacer(Modifier.height(24.dp))
        Surface(color = ExamColors.Surface, shape = RoundedCornerShape(22.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
            Row(Modifier.fillMaxWidth().padding(18.dp), horizontalArrangement = Arrangement.SpaceAround) {
                Stat("$correct", copy.text("correct"))
                Stat("${total - correct}", copy.text("review"))
                Stat("+$earnedXp", copy.text("xp"))
            }
        }
        if (sessionType == "mock_exam") {
            Spacer(Modifier.height(14.dp))
            val accuracy = if (total == 0) 0 else correct * 100 / total
            val minutes = durationSeconds / 60
            val seconds = durationSeconds % 60
            Surface(
                color = ExamColors.Surface,
                shape = RoundedCornerShape(20.dp),
                border = BorderStroke(1.dp, ExamColors.Border),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(Modifier.padding(16.dp)) {
                    Text(copy.text("mock_analysis"), fontWeight = FontWeight.Bold, fontSize = 17.sp)
                    Spacer(Modifier.height(10.dp))
                    Text(copy.text("accuracy") + " · " + accuracy + "%", fontWeight = FontWeight.SemiBold)
                    Text(
                        copy.text("time") + " · %02d:%02d".format(minutes, seconds),
                        color = ExamColors.TextSecondary,
                        fontSize = 12.sp
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        when {
                            accuracy >= 85 -> copy.text("mock_result_strong")
                            accuracy >= 65 -> copy.text("mock_result_good")
                            else -> copy.text("mock_result_review")
                        },
                        color = ExamColors.TextSecondary,
                        fontSize = 12.sp,
                        lineHeight = 18.sp
                    )
                }
            }
        }

        Spacer(Modifier.height(24.dp))
        Button(
            onClick = onDone,
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary),
            elevation = ButtonDefaults.buttonElevation(0.dp)
        ) { Text(copy.text("done"), fontWeight = FontWeight.Bold) }
    }
}

@Composable
private fun Stat(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text(label, color = ExamColors.TextSecondary, fontSize = 11.sp)
    }
}
