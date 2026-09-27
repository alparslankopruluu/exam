package com.kprl.exam.ui.question

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.CheckCircle
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
import com.kprl.exam.domain.SampleQuestionFactory
import com.kprl.exam.domain.StudyQuestion
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

    fun finishSession() {
        if (completed) return
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
            if (timeLimitSeconds != null) {
                Text(
                    "%02d:%02d".format(remainingSeconds / 60, remainingSeconds % 60),
                    color = if (remainingSeconds <= 60) ExamColors.Coral else ExamColors.TextSecondary,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.width(8.dp))
            }
            Text("${index + 1}/${questions.size}", color = ExamColors.TextSecondary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        }

        Spacer(Modifier.height(28.dp))
        Text(question.topic.uppercase(), color = ExamColors.Primary, fontSize = 11.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(10.dp))
        Text(question.prompt, fontSize = 24.sp, lineHeight = 31.sp, fontWeight = FontWeight.Bold)

        Spacer(Modifier.height(24.dp))
        question.options.forEachIndexed { optionIndex, option ->
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

                        repository.recordAnswer(
                            examId = setup.exam.id,
                            skillId = setup.exam.id + ":" + question.topic.lowercase().replace(" ", "_"),
                            questionId = question.id,
                            correct = correct,
                            responseTimeMs = answeredAt - questionStartedAt,
                            selectedAnswer = option,
                            correctAnswer = question.options[question.correctIndex],
                            errorType = if (correct) "none" else "concept"
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

        if (selected != null) {
            Spacer(Modifier.height(18.dp))
            Surface(
                color = ExamColors.Surface,
                shape = RoundedCornerShape(20.dp),
                border = BorderStroke(1.dp, ExamColors.Border)
            ) {
                Column(Modifier.padding(16.dp)) {
                    Text(
                        if (selected == question.correctIndex) "Nice work." else "Almost — here's what matters.",
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        simplerExplanation ?: question.explanation,
                        color = ExamColors.TextSecondary,
                        fontSize = 13.sp,
                        lineHeight = 19.sp
                    )
                    tutorAnswer?.let {
                        Spacer(Modifier.height(10.dp))
                        Text("AI Tutor", color = ExamColors.Purple, fontWeight = FontWeight.Bold, fontSize = 11.sp)
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
                                simplerExplanation =
                                    "Think of it in one step: identify what the question asks, isolate the key relationship, then check the answer against the original statement."
                            },
                            label = { Text("Explain simpler") }
                        )
                        AssistChip(
                            onClick = {
                                if (!helperLoading) {
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
                            label = { Text("Ask tutor") }
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
                Text(if (index == questions.lastIndex) "Finish session" else "Next question", fontWeight = FontWeight.Bold)
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
        Text("Session complete", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(7.dp))
        Text("${correct}/${total} correct · $examName", color = ExamColors.TextSecondary)
        Spacer(Modifier.height(24.dp))
        Surface(color = ExamColors.Surface, shape = RoundedCornerShape(22.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
            Row(Modifier.fillMaxWidth().padding(18.dp), horizontalArrangement = Arrangement.SpaceAround) {
                Stat("$correct", "Correct")
                Stat("${total - correct}", "Review")
                Stat("+$earnedXp", "XP")
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
                    Text("Mock analysis", fontWeight = FontWeight.Bold, fontSize = 17.sp)
                    Spacer(Modifier.height(10.dp))
                    Text("Accuracy · " + accuracy + "%", fontWeight = FontWeight.SemiBold)
                    Text(
                        "Time · %02d:%02d".format(minutes, seconds),
                        color = ExamColors.TextSecondary,
                        fontSize = 12.sp
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        when {
                            accuracy >= 85 -> "Strong result. Move to harder mixed sets and protect timing."
                            accuracy >= 65 -> "Good base. Review your Error DNA, then repeat a timed mixed set."
                            else -> "Prioritize weak-skill review before the next timed mock."
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
        ) { Text("Done", fontWeight = FontWeight.Bold) }
    }
}

@Composable
private fun Stat(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text(label, color = ExamColors.TextSecondary, fontSize = 11.sp)
    }
}
