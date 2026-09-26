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
                4 -> DiagnosticStep(selected[current]) { selected[current] = it }
                else -> PlanReadyStep(exams[examIndex])
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
                        languageCode = ExamCatalog.languageCode()
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
private fun DiagnosticStep(selectedIndex: Int?, onSelected: (Int) -> Unit) {
    Column {
        Spacer(Modifier.height(28.dp))
        Text("Let's find your starting point.", fontSize = 30.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text("This sample will be replaced by an exam-specific diagnostic blueprint.", color = ExamColors.TextSecondary)
        Spacer(Modifier.height(28.dp))
        Surface(color = ExamColors.Surface, shape = RoundedCornerShape(22.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
            Column(Modifier.padding(20.dp)) {
                Text("DIAGNOSTIC · SAMPLE", color = ExamColors.Primary, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(16.dp))
                Text("f(x) = 2x + 4", fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
                Text("If f(x) = 10, what is x?", fontSize = 16.sp)
                Spacer(Modifier.height(14.dp))
                listOf("2", "3", "4", "5").forEachIndexed { index, answer ->
                    val correct = selectedIndex != null && index == 1
                    val chosen = selectedIndex == index
                    Surface(
                        onClick = { onSelected(index) },
                        modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp),
                        color = if (correct) ExamColors.SoftMint else if (chosen) ExamColors.SoftBlue else ExamColors.Background,
                        shape = RoundedCornerShape(15.dp),
                        border = BorderStroke(1.dp, if (correct) ExamColors.Mint else if (chosen) ExamColors.Primary else ExamColors.Border)
                    ) {
                        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(('A'.code + index).toChar().toString(), color = ExamColors.TextSecondary, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.width(14.dp))
                            Text(answer, fontWeight = FontWeight.Medium)
                            Spacer(Modifier.weight(1f))
                            if (correct) Icon(Icons.Rounded.CheckCircle, null, tint = ExamColors.Mint)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PlanReadyStep(exam: ExamDefinition) {
    Column {
        Spacer(Modifier.height(28.dp))
        Text("Your ${exam.shortName} week is ready.", fontSize = 30.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text("The plan will use the ${exam.syllabusPackId} content pack and adapt as you improve.", color = ExamColors.TextSecondary)
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
