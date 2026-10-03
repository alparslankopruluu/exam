package com.kprl.exam.ui.onboarding

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.*
import androidx.compose.animation.togetherWith
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.R
import com.kprl.exam.analytics.AnalyticsEvents
import com.kprl.exam.analytics.AnalyticsParams
import com.kprl.exam.data.*
import com.kprl.exam.debug.ScreenshotMode
import com.kprl.exam.localization.LocalizedCopy
import com.kprl.exam.platform.AppServices
import com.kprl.exam.platform.persistence.StudySetupStore
import com.kprl.exam.ui.components.ExamDateField
import com.kprl.exam.ui.components.ExamPrimaryButton
import com.kprl.exam.ui.components.ExamSelectionCard
import com.kprl.exam.ui.theme.ExamColors
import java.text.DecimalFormatSymbols
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.Locale
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlinx.coroutines.delay

private data class Choice(val title: String, val subtitle: String, val icon: ImageVector, val accent: Color)

/** Steps mirror iOS: country, exam, goal, exam date, daily time, diagnostic, analysis, Study DNA, first-week plan. */
private object Step {
    const val GOAL = 2
    const val EXAM_DATE = 3
    const val TIME = 4
    const val DIAGNOSTIC = 5
    const val ANALYSIS = 6
    const val DNA = 7
    const val PLAN = 8
    const val TOTAL = 9
}

@Composable
fun OnboardingScreen(onComplete: (StudySetup) -> Unit) {
    val onboardingContext = LocalContext.current
    var examDate by remember { mutableStateOf<LocalDate?>(LocalDate.now().plusMonths(3)) }
    var step by rememberSaveable { mutableIntStateOf(0) }
    var countryIndex by rememberSaveable { mutableIntStateOf(ExamCatalog.suggestedCountryIndex()) }
    var examIndex by rememberSaveable { mutableIntStateOf(-1) }
    val selected = remember { mutableStateMapOf<Int, Int>() }
    var diagnostic by remember { mutableStateOf<DiagnosticResult?>(null) }

    val country = ExamCatalog.countries[countryIndex]
    val exams = ExamCatalog.examsFor(country)
    val context = LocalContext.current
    val copy = remember { LocalizedCopy.load(context, ExamCatalog.languageCode()) }

    LaunchedEffect(Unit) {
        AppServices.analytics.event(AnalyticsEvents.ONBOARDING_STARTED)
        // Store screenshots jump straight to a later step with a plausible learner.
        val shot = ScreenshotMode.screen
        if (shot != null && shot.startsWith("onboarding_")) {
            ExamCatalog.countries.indexOfFirst { c -> ExamCatalog.examsFor(c).any { it.id == ScreenshotMode.examId } }
                .takeIf { it >= 0 }?.let { index ->
                    countryIndex = index
                    examIndex = ExamCatalog.examsFor(ExamCatalog.countries[index]).indexOfFirst { it.id == ScreenshotMode.examId }
                }
            selected[Step.GOAL] = 1
            selected[Step.TIME] = 1
            examDate = LocalDate.now().plusDays(60)
            diagnostic = DiagnosticResult(
                listOf(
                    DiagnosticAnswer(DiagnosticDimension.APPLICATION, true, 14_000),
                    DiagnosticAnswer(DiagnosticDimension.CONCEPTS, true, 11_000),
                    DiagnosticAnswer(DiagnosticDimension.CONCEPTS, true, 18_000),
                    DiagnosticAnswer(DiagnosticDimension.APPLICATION, false, 26_000),
                    DiagnosticAnswer(DiagnosticDimension.STRATEGY, true, 16_000)
                )
            )
            step = when (shot) {
                "onboarding_date" -> Step.EXAM_DATE
                "onboarding_analysis" -> Step.ANALYSIS
                "onboarding_dna" -> Step.DNA
                else -> Step.PLAN
            }
        }
    }

    LaunchedEffect(step) {
        when (step) {
            Step.DIAGNOSTIC -> AppServices.analytics.event(
                AnalyticsEvents.DIAGNOSTIC_STARTED,
                mapOf(
                    AnalyticsParams.COUNTRY_CODE to country.code,
                    AnalyticsParams.EXAM_ID to exams.getOrNull(examIndex)?.id
                )
            )
            Step.ANALYSIS -> AppServices.analytics.event(
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
        Step.GOAL, Step.TIME -> selected[step] != null
        Step.DIAGNOSTIC -> diagnostic != null
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
                repeat(Step.TOTAL) { index ->
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
                0 -> CountryStep(copy, countryIndex) {
                    countryIndex = it
                    examIndex = -1
                    AppServices.analytics.event(
                        AnalyticsEvents.COUNTRY_SELECTED,
                        mapOf(AnalyticsParams.COUNTRY_CODE to ExamCatalog.countries[it].code)
                    )
                }
                1 -> ExamStep(copy, country, exams, examIndex) {
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
                Step.GOAL -> ChoiceStep(copy.text("onboarding_goal_title"), copy.text("onboarding_goal_hint"), goalChoices(copy), selected[current]) {
                    selected[current] = it
                    AppServices.analytics.event(AnalyticsEvents.GOAL_SELECTED, mapOf("goal_index" to it))
                }
                Step.EXAM_DATE -> ExamDateStep(exams[examIndex], copy, examDate) { examDate = it }
                Step.TIME -> ChoiceStep(copy.text("onboarding_time_title"), copy.text("onboarding_time_hint"), timeChoices(copy), selected[current]) { selected[current] = it }
                Step.DIAGNOSTIC -> DiagnosticStep(exams[examIndex], copy) { diagnostic = it }
                Step.ANALYSIS -> AnalysisStep(copy) { step = Step.DNA }
                Step.DNA -> StudyDNAStep(StudyDNA.from(diagnostic ?: DiagnosticResult(emptyList())), copy)
                else -> FirstWeekStep(exams[examIndex], copy, dailyMinutesFor(selected[Step.TIME] ?: 1))
            }
        }

        // The analysis step advances on its own once the animation finishes.
        Box(Modifier.graphicsLayer { alpha = if (step == Step.ANALYSIS) 0f else 1f }) {
            ExamPrimaryButton(
                text = if (step == Step.TOTAL - 1) copy.text("start_my_plan") else copy.text("continue"),
                enabled = canContinue() && step != Step.ANALYSIS
            ) {
                if (step == Step.TOTAL - 1) {
                    AppServices.analytics.event(
                        AnalyticsEvents.PLAN_GENERATED,
                        mapOf(
                            AnalyticsParams.COUNTRY_CODE to country.code,
                            AnalyticsParams.EXAM_ID to exams[examIndex].id,
                            AnalyticsParams.CONTENT_PACK_ID to exams[examIndex].syllabusPackId,
                            AnalyticsParams.LANGUAGE_CODE to ExamCatalog.languageCode()
                        )
                    )
                    StudySetupStore(onboardingContext.applicationContext).setExamDate(examDate)
                    AppServices.analytics.event("exam_date_set", mapOf("known" to (examDate != null)))
                    AppServices.analytics.userProperty("exam_id", exams[examIndex].id)
                    AppServices.analytics.userProperty("country_code", country.code)
                    onComplete(
                        StudySetup(
                            country = country,
                            exam = exams[examIndex],
                            languageCode = ExamCatalog.languageCode(),
                            goalKey = goalKeyFor(selected[Step.GOAL] ?: 2),
                            dailyMinutes = dailyMinutesFor(selected[Step.TIME] ?: 1),
                            diagnosticPercent = diagnostic?.percent ?: 50
                        )
                    )
                } else step++
            }
        }
        Spacer(Modifier.height(12.dp))
    }
}

@Composable
private fun CountryStep(copy: LocalizedCopy, selectedIndex: Int, onSelected: (Int) -> Unit) {
    Column {
        Spacer(Modifier.height(28.dp))
        Text(copy.text("onboarding_country_title"), fontSize = 30.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(copy.text("onboarding_country_hint"), color = ExamColors.TextSecondary, fontSize = 15.sp)
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
                        Text(item.localizedName(), fontSize = 15.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                        if (selectedIndex == index) Icon(Icons.Rounded.CheckCircle, null, tint = ExamColors.Primary)
                    }
                }
            }
        }
    }
}

@Composable
private fun ExamStep(copy: LocalizedCopy, country: CountryDefinition, exams: List<ExamDefinition>, selectedIndex: Int, onSelected: (Int) -> Unit) {
    Column {
        Spacer(Modifier.height(28.dp))
        Text(copy.text("onboarding_exam_title"), fontSize = 30.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(copy.text("onboarding_exam_hint", mapOf("country" to "${country.flag} ${country.localizedName()}")), color = ExamColors.TextSecondary, fontSize = 15.sp)
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
                    if (exam.international) copy.text("international_prefix", mapOf("title" to exam.title)) else exam.title,
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
private fun ExamDateStep(exam: ExamDefinition, copy: LocalizedCopy, examDate: LocalDate?, onChange: (LocalDate?) -> Unit) {
    val days = examDate?.let { ChronoUnit.DAYS.between(LocalDate.now(), it).toInt().coerceAtLeast(0) }
    val ring by animateFloatAsState(((days ?: 0) / 365f).coerceIn(0f, 1f), spring(), label = "days")
    Column(Modifier.verticalScroll(rememberScrollState())) {
        Spacer(Modifier.height(28.dp))
        Text(copy.text("exam_date_question", mapOf("exam" to exam.shortName)), fontSize = 30.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(20.dp))
        ExamDateField(
            title = copy.text("exam_date_label"),
            copy = copy,
            languageCode = ExamCatalog.languageCode(),
            date = examDate,
            onChange = onChange
        )
        Box(Modifier.fillMaxWidth().padding(top = 24.dp), contentAlignment = Alignment.Center) {
            Box(Modifier.size(162.dp), contentAlignment = Alignment.Center) {
                Box(Modifier.size(150.dp).background(ExamColors.SoftBlue, CircleShape))
                Canvas(Modifier.fillMaxSize()) {
                    drawArc(ExamColors.Primary, -90f, 360f * ring, false, style = Stroke(6.dp.toPx(), cap = StrokeCap.Round))
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(days?.toString() ?: "–", fontSize = 46.sp, fontWeight = FontWeight.Bold, color = ExamColors.TextPrimary)
                    Text(copy.text("days_left"), fontSize = 13.sp, fontWeight = FontWeight.Medium, color = ExamColors.TextSecondary)
                }
            }
        }
        Image(
            painterResource(R.drawable.illu_calendar), null,
            modifier = Modifier.fillMaxWidth().height(120.dp).padding(top = 12.dp),
            contentScale = ContentScale.Fit
        )
        Text(
            copy.text(if (days != null && days < 30) "exam_date_soon" else "exam_date_encourage"),
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = ExamColors.TextSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(top = 10.dp, bottom = 24.dp)
        )
    }
}

/** What a diagnostic question measures; feeds the Study DNA profile. */
enum class DiagnosticDimension { CONCEPTS, APPLICATION, STRATEGY }

data class DiagnosticAnswer(val dimension: DiagnosticDimension, val correct: Boolean, val responseMs: Int)

/** Per-question outcome of the onboarding diagnostic. */
data class DiagnosticResult(val answers: List<DiagnosticAnswer>) {
    val percent: Int get() = if (answers.isEmpty()) 50 else answers.count { it.correct } * 100 / answers.size
}

/**
 * The five-axis starting profile shown after the diagnostic. Each axis is scaled into
 * 40–95 so a 5-question test reads as a starting point, not a verdict (mirrors iOS).
 */
private class StudyDNA(val values: Map<Axis, Int>) {
    enum class Axis(val key: String, val archetypeKey: String) {
        CONCEPTS("dna_concepts", "dna_type_concepts"),
        APPLICATION("dna_application", "dna_type_application"),
        SPEED("dna_speed", "dna_type_speed"),
        ACCURACY("dna_accuracy", "dna_type_accuracy"),
        STRATEGY("dna_strategy", "dna_type_strategy")
    }

    val archetype: Axis get() = Axis.entries.maxBy { values[it] ?: 0 }
    val focus: Axis get() = Axis.entries.minBy { values[it] ?: 0 }

    companion object {
        fun from(result: DiagnosticResult): StudyDNA {
            fun scaled(fraction: Double) = (40 + 55 * fraction).roundToInt()
            fun fraction(dimension: DiagnosticDimension): Double {
                val items = result.answers.filter { it.dimension == dimension }
                return if (items.isEmpty()) 0.5 else items.count { it.correct }.toDouble() / items.size
            }
            val averageMs = if (result.answers.isEmpty()) 25_000 else result.answers.sumOf { it.responseMs } / result.answers.size
            val speed = ((40_000 - averageMs) / 32_000.0).coerceIn(0.0, 1.0)
            return StudyDNA(
                mapOf(
                    Axis.CONCEPTS to scaled(fraction(DiagnosticDimension.CONCEPTS)),
                    Axis.APPLICATION to scaled(fraction(DiagnosticDimension.APPLICATION)),
                    Axis.SPEED to scaled(speed),
                    Axis.ACCURACY to scaled(result.percent / 100.0),
                    Axis.STRATEGY to scaled(fraction(DiagnosticDimension.STRATEGY))
                )
            )
        }
    }
}

@Composable
private fun DiagnosticStep(exam: ExamDefinition, copy: LocalizedCopy, onCompleted: (DiagnosticResult) -> Unit) {
    val questions = remember(exam.id) { diagnosticQuestions(exam, copy) }
    var index by remember(exam.id) { mutableIntStateOf(0) }
    var selectedIndex by remember(exam.id) { mutableStateOf<Int?>(null) }
    val answers = remember(exam.id) { mutableStateListOf<DiagnosticAnswer>() }
    var shownAt by remember(exam.id) { mutableLongStateOf(System.currentTimeMillis()) }
    var finished by remember(exam.id) { mutableStateOf(false) }

    val question = questions[index]

    Column(Modifier.verticalScroll(rememberScrollState())) {
        Spacer(Modifier.height(28.dp))
        Text(copy.text("diagnostic_title"), fontSize = 30.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(copy.text("diagnostic_hint", mapOf("exam" to exam.shortName)), color = ExamColors.TextSecondary)
        Spacer(Modifier.height(18.dp))

        LinearProgressIndicator(
            progress = { (index + if (selectedIndex != null || finished) 1 else 0).toFloat() / questions.size.toFloat() },
            modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(50)),
            color = ExamColors.Primary,
            trackColor = ExamColors.Border
        )

        Spacer(Modifier.height(18.dp))
        Surface(color = ExamColors.Surface, shape = RoundedCornerShape(22.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
            Column(Modifier.padding(20.dp)) {
                Text(
                    if (finished) copy.text("diagnostic_complete").uppercase()
                    else copy.text("question_n_of", mapOf("n" to "${index + 1}", "total" to "${questions.size}")).uppercase(),
                    color = ExamColors.Primary,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.height(14.dp))

                if (finished) {
                    val score = DiagnosticResult(answers.toList()).percent
                    Text("$score%", fontSize = 42.sp, fontWeight = FontWeight.Bold)
                    Text(
                        copy.text(when { score >= 80 -> "diag_result_high"; score >= 55 -> "diag_result_mid"; else -> "diag_result_low" }),
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
                        val shake = remember(index, optionIndex) { Animatable(0f) }
                        LaunchedEffect(wrongChosen) {
                            if (wrongChosen) shake.animateTo(1f, tween(400)).also { shake.snapTo(0f) }
                        }
                        Surface(
                            onClick = {
                                if (selectedIndex == null) {
                                    selectedIndex = optionIndex
                                    answers += DiagnosticAnswer(
                                        question.dimension,
                                        optionIndex == question.correctIndex,
                                        (System.currentTimeMillis() - shownAt).toInt()
                                    )
                                }
                            },
                            modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp)
                                .graphicsLayer { translationX = 6.dp.toPx() * sin(shake.value * Math.PI.toFloat() * 4) },
                            color = when {
                                correct -> ExamColors.SoftMint
                                wrongChosen -> ExamColors.Coral.copy(alpha = .08f)
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
                                    onCompleted(DiagnosticResult(answers.toList()))
                                } else {
                                    index++
                                    selectedIndex = null
                                    shownAt = System.currentTimeMillis()
                                }
                            },
                            modifier = Modifier.fillMaxWidth().height(48.dp),
                            shape = RoundedCornerShape(15.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary)
                        ) {
                            Text(if (index == questions.lastIndex) copy.text("see_my_level") else copy.text("next_question"), fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

private data class DiagnosticQuestion(
    val prompt: String,
    val options: List<String>,
    val correctIndex: Int,
    val explanation: String,
    val dimension: DiagnosticDimension
)

private fun diagnosticQuestions(exam: ExamDefinition, copy: LocalizedCopy): List<DiagnosticQuestion> {
    val separator = DecimalFormatSymbols.getInstance(Locale.forLanguageTag(ExamCatalog.languageCode())).decimalSeparator
    fun q(n: Int, options: List<String>, correct: Int, dimension: DiagnosticDimension) =
        DiagnosticQuestion(copy.text("diag_q$n"), options, correct, copy.text("diag_q${n}_why"), dimension)
    val common = listOf(
        q(1, listOf("3", "5", "7", "9"), 1, DiagnosticDimension.APPLICATION),
        q(2, listOf("0.3", "0.5", "0.6", "1.5").map { it.replace('.', separator) }, 2, DiagnosticDimension.CONCEPTS),
        q(3, listOf("a", "b", "c", "d").map { copy.text("diag_q3_$it") }, 0, DiagnosticDimension.CONCEPTS),
        q(4, listOf("10%", "20%", "25%", "80%"), 2, DiagnosticDimension.APPLICATION),
        q(5, listOf("a", "b", "c", "d").map { copy.text("diag_q5_$it") }, 1, DiagnosticDimension.STRATEGY)
    )

    // Language exams are taken in English, so their items stay in English.
    return when (exam.category) {
        ExamCategory.LANGUAGE -> listOf(
            DiagnosticQuestion(
                "Choose the grammatically correct sentence.",
                listOf("She have finished.", "She has finished.", "She finishing.", "She finish yesterday."),
                1,
                "Present perfect uses has/have + past participle.",
                DiagnosticDimension.CONCEPTS
            ),
            DiagnosticQuestion(
                "The word 'concise' most nearly means…",
                listOf("brief and clear", "uncertain", "very old", "unrelated"),
                0,
                "Concise means expressing much in few words.",
                DiagnosticDimension.CONCEPTS
            ),
            common[2], common[4],
            DiagnosticQuestion(
                "Which transition signals contrast?",
                listOf("Therefore", "However", "For example", "Similarly"),
                1,
                "However introduces contrast.",
                DiagnosticDimension.APPLICATION
            )
        )
        else -> common
    }
}

/** "Analyzing your answers…": an orbiting orb and a checklist that ticks off, then advances. */
@Composable
private fun AnalysisStep(copy: LocalizedCopy, onFinished: () -> Unit) {
    val items = listOf("analysis_strengths", "analysis_gaps", "analysis_syllabus", "analysis_dna")
    var done by remember { mutableIntStateOf(0) }
    val transition = rememberInfiniteTransition(label = "analysis")
    val angle by transition.animateFloat(0f, 360f, infiniteRepeatable(tween(2400, easing = LinearEasing)), label = "orbit")
    val pulse by transition.animateFloat(0.94f, 1.06f, infiniteRepeatable(tween(1000), RepeatMode.Reverse), label = "pulse")

    LaunchedEffect(Unit) {
        for (index in 1..items.size) {
            delay(700)
            done = index
        }
        delay(600)
        onFinished()
    }

    Column(Modifier.fillMaxSize().padding(horizontal = 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.weight(1f))
        Text(copy.text("analysis_title"), fontSize = 26.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Box(Modifier.padding(top = 24.dp).size(230.dp), contentAlignment = Alignment.Center) {
            Box(Modifier.size(150.dp).scale(pulse).background(ExamColors.SoftPurple, CircleShape))
            Box(Modifier.size(200.dp).border(1.5.dp, ExamColors.Indigo.copy(alpha = 0.25f), CircleShape))
            listOf(ExamColors.Amber to 0f, ExamColors.Primary to 160f).forEach { (color, offset) ->
                Box(Modifier.size(200.dp).rotate(angle + offset), contentAlignment = Alignment.CenterEnd) {
                    Box(Modifier.offset(x = 6.dp).size(12.dp).background(color, CircleShape))
                }
            }
            Icon(Icons.Rounded.Psychology, null, tint = ExamColors.Indigo, modifier = Modifier.size(64.dp))
        }
        Column(Modifier.padding(top = 28.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            items.forEachIndexed { index, key ->
                val checked = index < done
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        if (checked) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked, null,
                        tint = if (checked) ExamColors.Mint else ExamColors.Border,
                        modifier = Modifier.size(22.dp)
                    )
                    Spacer(Modifier.width(10.dp))
                    Text(copy.text(key), fontSize = 15.sp, fontWeight = FontWeight.Medium, color = if (checked) ExamColors.TextPrimary else ExamColors.TextSecondary)
                }
            }
        }
        Spacer(Modifier.weight(1f))
    }
}

@Composable
private fun StudyDNAStep(dna: StudyDNA, copy: LocalizedCopy) {
    var appeared by remember { mutableStateOf(false) }
    val reveal by animateFloatAsState(if (appeared) 1f else 0f, spring(dampingRatio = 0.75f, stiffness = 60f), label = "dna")
    LaunchedEffect(Unit) { delay(150); appeared = true }

    Column(Modifier.verticalScroll(rememberScrollState()), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(copy.text("dna_title"), fontSize = 30.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 28.dp))
        Text(copy.text("dna_subtitle"), fontSize = 15.sp, color = ExamColors.TextSecondary, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 6.dp))
        RadarChart(
            labels = StudyDNA.Axis.entries.map { copy.text(it.key) },
            values = StudyDNA.Axis.entries.map { (dna.values[it] ?: 0) / 100f },
            reveal = reveal,
            modifier = Modifier.fillMaxWidth().height(300.dp).padding(top = 12.dp)
        )
        Surface(color = ExamColors.Surface, shape = RoundedCornerShape(20.dp), border = BorderStroke(1.dp, ExamColors.Border), modifier = Modifier.padding(top = 8.dp, bottom = 24.dp)) {
            Row(Modifier.fillMaxWidth().padding(16.dp)) {
                Box(Modifier.size(44.dp).background(ExamColors.Amber.copy(alpha = 0.14f), CircleShape), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Lightbulb, null, tint = ExamColors.Amber)
                }
                Spacer(Modifier.width(12.dp))
                Column {
                    Text(copy.text("dna_you_are", mapOf("type" to copy.text(dna.archetype.archetypeKey))), fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    Text(
                        copy.text("dna_next_focus", mapOf("axis" to copy.text(dna.focus.key).lowercase())),
                        fontSize = 13.sp,
                        color = ExamColors.TextSecondary
                    )
                }
            }
        }
    }
}

/** A five-axis radar ("spider") chart with labelled percentages (mirrors iOS RadarChart). */
@Composable
private fun RadarChart(labels: List<String>, values: List<Float>, reveal: Float, modifier: Modifier = Modifier) {
    val density = LocalDensity.current
    BoxWithConstraints(modifier) {
        val widthPx = with(density) { maxWidth.toPx() }
        val heightPx = with(density) { maxHeight.toPx() }
        val center = Offset(widthPx / 2f, heightPx / 2f + with(density) { 6.dp.toPx() })
        val radius = minOf(widthPx, heightPx) / 2f - with(density) { 46.dp.toPx() }
        val count = values.size
        fun point(index: Int, scale: Float): Offset {
            val angle = -Math.PI / 2 + index * 2 * Math.PI / count
            return Offset(center.x + (cos(angle) * radius * scale).toFloat(), center.y + (sin(angle) * radius * scale).toFloat())
        }
        fun polygon(scales: List<Float>) = Path().apply {
            scales.forEachIndexed { index, scale ->
                val p = point(index, scale)
                if (index == 0) moveTo(p.x, p.y) else lineTo(p.x, p.y)
            }
            close()
        }

        Canvas(Modifier.fillMaxSize()) {
            listOf(0.25f, 0.5f, 0.75f, 1f).forEach { ring ->
                drawPath(polygon(List(count) { ring }), ExamColors.Border, style = Stroke(1.dp.toPx()))
            }
            repeat(count) { drawLine(ExamColors.Border, center, point(it, 1f), 1.dp.toPx()) }
            val shape = polygon(values.map { it * reveal })
            drawPath(
                shape,
                Brush.sweepGradient(
                    listOf(ExamColors.Mint, ExamColors.Primary, ExamColors.Purple, ExamColors.Coral, ExamColors.Amber, ExamColors.Mint)
                        .map { it.copy(alpha = 0.35f) },
                    center
                )
            )
            drawPath(shape, ExamColors.Indigo.copy(alpha = 0.8f), style = Stroke(2.dp.toPx()))
            values.forEachIndexed { index, value ->
                val p = point(index, value * reveal)
                drawCircle(ExamColors.Surface, 4.5.dp.toPx(), p)
                drawCircle(ExamColors.Indigo, 4.5.dp.toPx(), p, style = Stroke(2.dp.toPx()))
            }
        }
        values.forEachIndexed { index, value ->
            val p = point(index, 1.28f)
            Column(
                Modifier.offset { IntOffset((p.x - with(density) { 50.dp.toPx() }).roundToInt(), (p.y - with(density) { 18.dp.toPx() }).roundToInt()) }
                    .width(100.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(labels[index], fontSize = 12.sp, fontWeight = FontWeight.Medium, color = ExamColors.TextSecondary, maxLines = 1)
                Text("${(value * 100).roundToInt()}%", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = ExamColors.TextPrimary)
            }
        }
    }
}

@Composable
private fun FirstWeekStep(exam: ExamDefinition, copy: LocalizedCopy, minutes: Int) {
    val locale = Locale.forLanguageTag(ExamCatalog.languageCode())
    fun day(dayOfWeek: DayOfWeek) = dayOfWeek.getDisplayName(java.time.format.TextStyle.SHORT, locale)
    fun detail(tasks: Int, mins: Int) = copy.text("tasks_minutes", mapOf("tasks" to "$tasks", "minutes" to "$mins"))

    Column(Modifier.verticalScroll(rememberScrollState())) {
        Image(
            painterResource(R.drawable.illu_calendar), null,
            modifier = Modifier.fillMaxWidth().height(110.dp).padding(top = 12.dp),
            contentScale = ContentScale.Fit
        )
        Text(copy.text("first_week_title"), fontSize = 28.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 6.dp))
        Text(
            copy.text("first_week_subtitle", mapOf("exam" to exam.shortName, "minutes" to "$minutes")),
            fontSize = 15.sp, color = ExamColors.TextSecondary, textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(top = 6.dp)
        )
        Row(Modifier.fillMaxWidth().padding(top = 18.dp)) {
            (1..4).forEach { week ->
                Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                    Text(
                        if (week == 1) copy.text("week_n", mapOf("n" to "1")) else "$week",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = if (week == 1) ExamColors.Primary else ExamColors.TextSecondary.copy(alpha = 0.6f),
                        modifier = Modifier
                            .background(if (week == 1) ExamColors.SoftBlue else Color.Transparent, RoundedCornerShape(50))
                            .padding(horizontal = 14.dp, vertical = 7.dp)
                    )
                }
            }
        }
        Column(Modifier.padding(top = 14.dp, bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            PlanRow(day(DayOfWeek.MONDAY), Icons.Rounded.MenuBook, copy.text("plan_core_title"), detail(3, minutes), ExamColors.Primary)
            PlanRow(day(DayOfWeek.TUESDAY), Icons.Rounded.TrackChanges, copy.text("plan_targeted_title"), detail(3, minutes), ExamColors.Amber)
            PlanRow(day(DayOfWeek.WEDNESDAY), Icons.Rounded.Autorenew, copy.text("plan_review_title"), detail(2, minutes), ExamColors.Mint)
            PlanRow(day(DayOfWeek.THURSDAY), Icons.Rounded.Timer, copy.text("plan_mock_title"), detail(1, maxOf(minutes, 20)), ExamColors.Purple)
            PlanRow(day(DayOfWeek.FRIDAY), Icons.Rounded.BarChart, copy.text("plan_analyze_title"), detail(2, minutes), ExamColors.Coral)
        }
    }
}

@Composable
private fun PlanRow(day: String, icon: ImageVector, title: String, detail: String, accent: Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(day, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = ExamColors.TextSecondary, modifier = Modifier.width(38.dp))
        Surface(Modifier.weight(1f), color = ExamColors.Surface, shape = RoundedCornerShape(16.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
            Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(38.dp).background(accent.copy(alpha = .12f), RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                    Icon(icon, null, tint = accent, modifier = Modifier.size(20.dp))
                }
                Spacer(Modifier.width(12.dp))
                Column {
                    Text(title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
                    Text(detail, fontSize = 12.sp, color = ExamColors.TextSecondary)
                }
            }
        }
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

private fun goalChoices(copy: LocalizedCopy) = listOf(
    Choice(copy.text("goal_top_title"), copy.text("goal_top_hint"), Icons.Rounded.EmojiEvents, ExamColors.Amber),
    Choice(copy.text("goal_target_title"), copy.text("goal_target_hint"), Icons.Rounded.TrendingUp, ExamColors.Primary),
    Choice(copy.text("goal_improve_title"), copy.text("goal_improve_hint"), Icons.Rounded.TrackChanges, ExamColors.Mint),
    Choice(copy.text("goal_pass_title"), copy.text("goal_pass_hint"), Icons.Rounded.CheckCircle, ExamColors.Purple),
    Choice(copy.text("goal_unsure_title"), copy.text("goal_unsure_hint"), Icons.Rounded.Explore, ExamColors.Indigo)
)

private fun timeChoices(copy: LocalizedCopy): List<Choice> {
    fun minutes(value: String) = copy.text("minutes_short", mapOf("count" to value))
    return listOf(
        Choice(minutes("10"), copy.text("time_quick"), Icons.Rounded.Bolt, ExamColors.Mint),
        Choice(minutes("20"), copy.text("time_recommended"), Icons.Rounded.Timer, ExamColors.Primary),
        Choice(minutes("30"), copy.text("time_serious"), Icons.Rounded.LocalFireDepartment, ExamColors.Amber),
        Choice(minutes("45+"), copy.text("time_intensive"), Icons.Rounded.RocketLaunch, ExamColors.Purple)
    )
}

/** The country name in the app language, falling back to the catalogue name. */
private fun CountryDefinition.localizedName(): String =
    Locale("", code).getDisplayCountry(Locale.forLanguageTag(ExamCatalog.languageCode()))
        .takeIf { it.isNotBlank() && it != code } ?: name

