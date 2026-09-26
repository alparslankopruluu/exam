package com.kprl.exam.ui.onboarding

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.spring
import androidx.compose.animation.togetherWith
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.data.*
import com.kprl.exam.analytics.AnalyticsEvents
import com.kprl.exam.analytics.AnalyticsParams
import com.kprl.exam.platform.AppServices
import com.kprl.exam.ui.components.ExamPrimaryButton
import com.kprl.exam.ui.components.ExamSelectionCard
import com.kprl.exam.ui.theme.ExamColors

private data class Choice(val title: String, val subtitle: String, val icon: ImageVector, val accent: Color)

@Composable
fun OnboardingScreen(onComplete: (StudySetup) -> Unit) {
    var step by rememberSaveable { mutableIntStateOf(0) }
    var countryIndex by rememberSaveable { mutableIntStateOf(ExamCatalog.suggestedCountryIndex()) }
    var examIndex by rememberSaveable { mutableIntStateOf(-1) }
    val selected = remember { mutableStateMapOf<Int, Int>() }
    val total = 6

    val country = ExamCatalog.countries[countryIndex]
    val exams = ExamCatalog.examsFor(country)

    LaunchedEffect(Unit) {
        AppServices.analytics.event(AnalyticsEvents.ONBOARDING_STARTED)
    }

    LaunchedEffect(step) {
        when (step) {
            4 -> AppServices.analytics.event(
                AnalyticsEvents.DIAGNOSTIC_STARTED,
                mapOf(
                    AnalyticsParams.COUNTRY_CODE to country.code,
                    AnalyticsParams.EXAM_ID to exams.getOrNull(examIndex)?.id
                )
            )
            5 -> AppServices.analytics.event(
                AnalyticsEvents.DIAGNOSTIC_COMPLETED,
                mapOf(
                    AnalyticsParams.COUNTRY_CODE to country.code,
                    AnalyticsParams.EXAM_ID to exams.getOrNull(examIndex)?.id
                )
            )
        }
    }

    fun canContinue(): Boolean = when (step) {
        0 -> true
        1 -> examIndex in exams.indices
        2, 3, 4 -> selected[step] != null
        else -> true
    }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp)
    ) {
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (step > 0) {
                IconButton(onClick = { step-- }, modifier = Modifier.size(38.dp)) {
                    Icon(Icons.Rounded.ArrowBack, "Back")
                }
            } else Spacer(Modifier.size(38.dp))

            Row(Modifier.weight(1f).padding(horizontal = 10.dp), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                repeat(total) { index ->
                    Box(
                        Modifier.weight(1f).height(4.dp).background(
                            if (index <= step) ExamColors.Primary else ExamColors.Border,
                            RoundedCornerShape(50)
                        )
                    )
                }
            }
            Spacer(Modifier.size(38.dp))
        }

        AnimatedContent(
            targetState = step,
            transitionSpec = {
                slideInHorizontally(spring()) { it / 4 } togetherWith slideOutHorizontally(spring()) { -it / 4 }
            },
            modifier = Modifier.weight(1f),
            label = "onboarding"
        ) { current ->
            when (current) {
                0 -> CountryStep(countryIndex) {
                    countryIndex = it
                    examIndex = -1
                    AppServices.analytics.event(
                        AnalyticsEvents.COUNTRY_SELECTED,
                        mapOf(AnalyticsParams.COUNTRY_CODE to ExamCatalog.countries[it].code)
                    )
                }
                1 -> ExamStep(country, exams, examIndex) {
                    examIndex = it
                    AppServices.analytics.event(
                        AnalyticsEvents.EXAM_SELECTED,
                        mapOf(
                            AnalyticsParams.COUNTRY_CODE to country.code,
                            AnalyticsParams.EXAM_ID to exams[it].id,
                            AnalyticsParams.CONTENT_PACK_ID to exams[it].syllabusPackId
                        )
                    )
                }
                2 -> ChoiceStep("What's your goal?", "We'll tune pace, difficulty and your weekly plan.", goalChoices(), selected[current]) {
                    selected[current] = it
                    AppServices.analytics.event(
                        AnalyticsEvents.GOAL_SELECTED,
                        mapOf("goal_index" to it)
                    )
                }
                3 -> ChoiceStep("How much time can you study daily?", "Choose something realistic. Consistency wins.", timeChoices(), selected[current]) { selected[current] = it }
                4 -> DiagnosticStep(exams[examIndex]) { score -> selected[current] = score }
                else -> PlanReadyStep(
                    exam = exams[examIndex],
                    diagnosticPercent = selected[4] ?: 50,
                    dailyMinutes = dailyMinutesFor(selected[3] ?: 1)
                )
            }
        }

        ExamPrimaryButton(
            text = if (step == total - 1) "Start my plan" else "Continue",
            enabled = canContinue()
        ) {
            if (step == total - 1) {
                AppServices.analytics.event(
                    AnalyticsEvents.PLAN_GENERATED,
                    mapOf(
                        AnalyticsParams.COUNTRY_CODE to country.code,
                        AnalyticsParams.EXAM_ID to exams[examIndex].id,
                        AnalyticsParams.CONTENT_PACK_ID to exams[examIndex].syllabusPackId,
                        AnalyticsParams.LANGUAGE_CODE to ExamCatalog.languageCode()
                    )
                )
                AppServices.analytics.userProperty("exam_id", exams[examIndex].id)
                AppServices.analytics.userProperty("country_code", country.code)
                onComplete(
                    StudySetup(
                        country = country,
                        exam = exams[examIndex],
                        languageCode = ExamCatalog.languageCode(),
                        goalKey = goalKeyFor(selected[2] ?: 2),
                        dailyMinutes = dailyMinutesFor(selected[3] ?: 1),
                        diagnosticPercent = selected[4] ?: 50
                    )
                )
            } else step++
        }
        Spacer(Modifier.height(12.dp))
    }
}

@Composable
private fun CountryStep(selectedIndex: Int, onSelected: (Int) -> Unit) {
    Column {
        Spacer(Modifier.height(28.dp))
        Text("Where are you studying?", fontSize = 30.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text("We use your region to suggest the right exams. You can still choose international exams anywhere.", color = ExamColors.TextSecondary, fontSize = 15.sp)
        Spacer(Modifier.height(22.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(9.dp)) {
            itemsIndexed(ExamCatalog.countries) { index, item ->
                Surface(
                    onClick = { onSelected(index) },
                    color = ExamColors.Surface,
                    shape = RoundedCornerShape(18.dp),
                    border = BorderStroke(if (selectedIndex == index) 1.5.dp else 1.dp, if (selectedIndex == index) ExamColors.Primary else ExamColors.Border)
                ) {
                    Row(Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(item.flag, fontSize = 26.sp, modifier = Modifier.width(42.dp))
                        Spacer(Modifier.width(10.dp))
                        Text(item.name, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                        if (selectedIndex == index) Icon(Icons.Rounded.CheckCircle, null, tint = ExamColors.Primary)
                    }
                }
            }
        }
    }
}

@Composable
private fun ExamStep(country: CountryDefinition, exams: List<ExamDefinition>, selectedIndex: Int, onSelected: (Int) -> Unit) {
    Column {
        Spacer(Modifier.height(28.dp))
        Text("Which exam are you preparing for?", fontSize = 30.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text("${country.flag} ${country.name} exams first, followed by international options.", color = ExamColors.TextSecondary, fontSize = 15.sp)
        Spacer(Modifier.height(22.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(9.dp)) {
            itemsIndexed(exams) { index, exam ->
                val accent = when (exam.category) {
                    ExamCategory.LANGUAGE -> ExamColors.Mint
                    ExamCategory.SCHOOL -> ExamColors.Amber
                    ExamCategory.PROFESSIONAL -> ExamColors.Purple
                    ExamCategory.INTERNATIONAL -> ExamColors.Indigo
                    ExamCategory.UNIVERSITY -> ExamColors.Primary
                }
                val icon = when (exam.category) {
                    ExamCategory.LANGUAGE -> Icons.Rounded.Language
                    ExamCategory.SCHOOL -> Icons.Rounded.MenuBook
                    ExamCategory.PROFESSIONAL -> Icons.Rounded.Work
                    ExamCategory.INTERNATIONAL -> Icons.Rounded.Public
                    ExamCategory.UNIVERSITY -> Icons.Rounded.School
                }
                ExamSelectionCard(
                    exam.shortName,
                    if (exam.international) "International · ${exam.title}" else exam.title,
                    icon,
                    accent,
                    selectedIndex == index
                ) { onSelected(index) }
            }
        }
    }
}

@Composable
private fun ChoiceStep(title: String, subtitle: String, choices: List<Choice>, selectedIndex: Int?, onSelected: (Int) -> Unit) {
    Column {
        Spacer(Modifier.height(28.dp))
        Text(title, fontSize = 30.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(subtitle, color = ExamColors.TextSecondary, fontSize = 15.sp)
        Spacer(Modifier.height(24.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            itemsIndexed(choices) { index, choice ->
                ExamSelectionCard(choice.title, choice.subtitle, choice.icon, choice.accent, selectedIndex == index) { onSelected(index) }
            }
        }
    }
}

@Composable
private fun DiagnosticStep(exam: ExamDefinition, onCompleted: (Int) -> Unit) {
    val questions = remember(exam.id) { diagnosticQuestions(exam) }
    var index by remember(exam.id) { mutableIntStateOf(0) }
    var selectedIndex by remember(exam.id) { mutableStateOf<Int?>(null) }
    var correctCount by remember(exam.id) { mutableIntStateOf(0) }
    var finished by remember(exam.id) { mutableStateOf(false) }

    val question = questions[index]

    Column {
        Spacer(Modifier.height(28.dp))
        Text("Let's find your starting point.", fontSize = 30.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(
            "A short ${exam.shortName} diagnostic adapts your first week. It won't affect any official score.",
            color = ExamColors.TextSecondary
        )
        Spacer(Modifier.height(18.dp))

        LinearProgressIndicator(
            progress = { (index + if (selectedIndex != null || finished) 1 else 0).toFloat() / questions.size.toFloat() },
            modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(50)),
            color = ExamColors.Primary,
            trackColor = ExamColors.Border
        )

        Spacer(Modifier.height(18.dp))
        Surface(
            color = ExamColors.Surface,
            shape = RoundedCornerShape(22.dp),
            border = BorderStroke(1.dp, ExamColors.Border)
        ) {
            Column(Modifier.padding(20.dp)) {
                Text(
                    if (finished) "DIAGNOSTIC COMPLETE" else "QUESTION ${index + 1} OF ${questions.size}",
                    color = ExamColors.Primary,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.height(14.dp))

                if (finished) {
                    val score = (correctCount * 100 / questions.size).coerceIn(0, 100)
                    Text("$score%", fontSize = 42.sp, fontWeight = FontWeight.Bold)
                    Text(
                        when {
                            score >= 80 -> "Strong starting point. We'll begin with harder mixed practice."
                            score >= 55 -> "Good base. We'll balance review with exam-style practice."
                            else -> "We'll rebuild the highest-impact foundations first."
                        },
                        color = ExamColors.TextSecondary,
                        fontSize = 14.sp,
                        lineHeight = 20.sp
                    )
                } else {
                    Text(question.prompt, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(14.dp))

                    question.options.forEachIndexed { optionIndex, answer ->
                        val chosen = selectedIndex == optionIndex
                        val correct = selectedIndex != null && optionIndex == question.correctIndex
                        val wrongChosen = chosen && optionIndex != question.correctIndex

                        Surface(
                            onClick = {
                                if (selectedIndex == null) {
                                    selectedIndex = optionIndex
                                    if (optionIndex == question.correctIndex) correctCount++
                                }
                            },
                            modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp),
                            color = when {
                                correct -> ExamColors.SoftMint
                                wrongChosen -> ExamColors.SoftCoral
                                else -> ExamColors.Background
                            },
                            shape = RoundedCornerShape(15.dp),
                            border = BorderStroke(
                                1.dp,
                                when {
                                    correct -> ExamColors.Mint
                                    wrongChosen -> ExamColors.Coral
                                    else -> ExamColors.Border
                                }
                            )
                        ) {
                            Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                                Text(('A'.code + optionIndex).toChar().toString(), color = ExamColors.TextSecondary, fontWeight = FontWeight.Bold)
                                Spacer(Modifier.width(14.dp))
                                Text(answer, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
                                if (correct) Icon(Icons.Rounded.CheckCircle, null, tint = ExamColors.Mint)
                                if (wrongChosen) Icon(Icons.Rounded.Cancel, null, tint = ExamColors.Coral)
                            }
                        }
                    }

                    if (selectedIndex != null) {
                        Spacer(Modifier.height(12.dp))
                        Text(question.explanation, color = ExamColors.TextSecondary, fontSize = 12.sp)
                        Spacer(Modifier.height(12.dp))
                        Button(
                            onClick = {
                                if (index == questions.lastIndex) {
                                    finished = true
                                    onCompleted((correctCount * 100 / questions.size).coerceIn(0, 100))
                                } else {
                                    index++
                                    selectedIndex = null
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(15.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary)
                        ) {
                            Text(if (index == questions.lastIndex) "See my level" else "Next question")
                        }
                    }
                }
            }
        }
    }
}

private data class DiagnosticQuestion(
    val prompt: String,
    val options: List<String>,
    val correctIndex: Int,
    val explanation: String
)

private fun diagnosticQuestions(exam: ExamDefinition): List<DiagnosticQuestion> {
    val common = listOf(
        DiagnosticQuestion(
            "If 3x + 6 = 21, what is x?",
            listOf("3", "5", "7", "9"),
            1,
            "Subtract 6, then divide 15 by 3."
        ),
        DiagnosticQuestion(
            "Which value is equivalent to 3/5?",
            listOf("0.3", "0.5", "0.6", "1.5"),
            2,
            "3 divided by 5 equals 0.6."
        ),
        DiagnosticQuestion(
            "A claim is best supported by evidence that is…",
            listOf("Relevant and verifiable", "Long", "Emotional", "Repeated"),
            0,
            "Strong evidence directly supports the claim and can be checked."
        ),
        DiagnosticQuestion(
            "A quantity rises from 80 to 100. What is the percentage increase?",
            listOf("10%", "20%", "25%", "80%"),
            2,
            "The increase is 20; 20/80 = 25%."
        ),
        DiagnosticQuestion(
            "Which strategy is best when two answer choices look plausible?",
            listOf("Guess immediately", "Re-read the exact requirement", "Choose the longest", "Skip every time"),
            1,
            "Returning to the precise requirement helps eliminate attractive distractors."
        )
    )

    return when (exam.category) {
        ExamCategory.LANGUAGE -> listOf(
            DiagnosticQuestion(
                "Choose the grammatically correct sentence.",
                listOf("She have finished.", "She has finished.", "She finishing.", "She finish yesterday."),
                1,
                "Present perfect uses has/have + past participle."
            ),
            DiagnosticQuestion(
                "The word 'concise' most nearly means…",
                listOf("brief and clear", "uncertain", "very old", "unrelated"),
                0,
                "Concise means expressing much in few words."
            ),
            common[2], common[4],
            DiagnosticQuestion(
                "Which transition signals contrast?",
                listOf("Therefore", "However", "For example", "Similarly"),
                1,
                "However introduces a contrast."
            )
        )
        else -> common
    }
}

private fun goalKeyFor(index: Int): String = when (index) {
    0 -> "top_score"
    1 -> "target_score"
    3 -> "pass"
    4 -> "explore"
    else -> "improve"
}

private fun dailyMinutesFor(index: Int): Int = when (index) {
    0 -> 10
    2 -> 30
    3 -> 45
    else -> 20
}

@Composable
private fun PlanReadyStep(exam: ExamDefinition, diagnosticPercent: Int, dailyMinutes: Int) {
    Column {
        Spacer(Modifier.height(28.dp))
        Text("Your ${exam.shortName} week is ready.", fontSize = 30.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text("Starting level $diagnosticPercent% · $dailyMinutes min/day. The plan adapts as your mastery changes.", color = ExamColors.TextSecondary)
        Spacer(Modifier.height(24.dp))
        Surface(color = ExamColors.Surface, shape = RoundedCornerShape(24.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
            Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                PlanRow("MON", "Core concept", "Learn + Practice", "12 min", ExamColors.Primary)
                PlanRow("TUE", "Targeted practice", "Exam-style questions", "17 min", ExamColors.Mint)
                PlanRow("WED", "Review", "Mistake session", "14 min", ExamColors.Amber)
                PlanRow("THU", "Mini mock", "Exam blueprint", "20 min", ExamColors.Purple)
            }
        }
    }
}

@Composable
private fun PlanRow(day: String, title: String, subtitle: String, time: String, accent: Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(44.dp).background(accent.copy(alpha = .12f), RoundedCornerShape(14.dp)), contentAlignment = Alignment.Center) {
            Text(day, fontSize = 10.sp, fontWeight = FontWeight.Bold, color = accent)
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.SemiBold)
            Text(subtitle, color = ExamColors.TextSecondary, fontSize = 12.sp)
        }
        Text(time, color = ExamColors.TextSecondary, fontSize = 12.sp)
    }
}

private fun goalChoices() = listOf(
    Choice("Highest possible score", "Push for the top range", Icons.Rounded.EmojiEvents, ExamColors.Amber),
    Choice("Strong target score", "Build competitive options", Icons.Rounded.TrendingUp, ExamColors.Primary),
    Choice("Improve significantly", "Raise your current level", Icons.Rounded.TrackChanges, ExamColors.Mint),
    Choice("Pass comfortably", "Study with less stress", Icons.Rounded.CheckCircle, ExamColors.Purple),
    Choice("I don't know yet", "We'll help you decide", Icons.Rounded.Explore, ExamColors.Indigo)
)

private fun timeChoices() = listOf(
    Choice("10 min", "Quick habit", Icons.Rounded.Bolt, ExamColors.Mint),
    Choice("20 min", "Recommended", Icons.Rounded.Timer, ExamColors.Primary),
    Choice("30 min", "Serious progress", Icons.Rounded.LocalFireDepartment, ExamColors.Amber),
    Choice("45+ min", "Intensive", Icons.Rounded.RocketLaunch, ExamColors.Purple)
)
