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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.ui.components.ExamPrimaryButton
import com.kprl.exam.ui.components.ExamSelectionCard
import com.kprl.exam.ui.theme.ExamColors

private data class Choice(val title: String, val subtitle: String, val icon: ImageVector, val accent: Color)

@Composable
fun OnboardingScreen(onComplete: () -> Unit) {
    var step by remember { mutableIntStateOf(0) }
    val selected = remember { mutableStateMapOf<Int, Int>() }
    val total = 5

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
                0 -> ChoiceStep("What are you preparing for?", "Choose your exam to get a study plan built around your real goal.", examChoices(), selected[current]) { selected[current] = it }
                1 -> ChoiceStep("What's your goal?", "We'll tune pace, difficulty and your weekly plan.", goalChoices(), selected[current]) { selected[current] = it }
                2 -> ChoiceStep("How much time can you study daily?", "Choose something realistic. Consistency wins.", timeChoices(), selected[current]) { selected[current] = it }
                3 -> DiagnosticStep(selected[current]) { selected[current] = it }
                else -> PlanReadyStep()
            }
        }

        ExamPrimaryButton(
            text = if (step == total - 1) "Start my plan" else "Continue",
            enabled = step == total - 1 || selected[step] != null
        ) {
            if (step == total - 1) onComplete() else step++
        }
        Spacer(Modifier.height(12.dp))
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
                ExamSelectionCard(choice.title, choice.subtitle, choice.icon, choice.accent, selectedIndex == index) {
                    onSelected(index)
                }
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
        Text("A quick sample helps us start at the right difficulty.", color = ExamColors.TextSecondary)
        Spacer(Modifier.height(28.dp))
        Surface(color = ExamColors.Surface, shape = RoundedCornerShape(22.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
            Column(Modifier.padding(20.dp)) {
                Text("DIAGNOSTIC · 1 / 5", color = ExamColors.Primary, fontSize = 12.sp, fontWeight = FontWeight.Bold)
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
                if (selectedIndex != null) {
                    Spacer(Modifier.height(10.dp))
                    Text(
                        if (selectedIndex == 1) "Nice. You isolated x correctly." else "Almost. Subtract 4 first, then divide by 2.",
                        color = ExamColors.TextSecondary, fontSize = 13.sp
                    )
                }
            }
        }
    }
}

@Composable
private fun PlanReadyStep() {
    Column {
        Spacer(Modifier.height(28.dp))
        Text("Your first week is ready.", fontSize = 30.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text("A focused plan that adapts as you improve.", color = ExamColors.TextSecondary)
        Spacer(Modifier.height(24.dp))
        Surface(color = ExamColors.Surface, shape = RoundedCornerShape(24.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
            Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                PlanRow("MON", "Functions", "Learn + Practice", "12 min", ExamColors.Primary)
                PlanRow("TUE", "Geometry", "Key concepts", "17 min", ExamColors.Mint)
                PlanRow("WED", "Review", "Mistake session", "14 min", ExamColors.Amber)
                PlanRow("THU", "Mini mock", "Mixed questions", "20 min", ExamColors.Purple)
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

private fun examChoices() = listOf(
    Choice("University entrance", "YKS · DGS · ALES · SAT", Icons.Rounded.School, ExamColors.Primary),
    Choice("Language exam", "IELTS · TOEFL · Cambridge", Icons.Rounded.Language, ExamColors.Mint),
    Choice("School exams", "Middle school · High school", Icons.Rounded.MenuBook, ExamColors.Amber),
    Choice("Professional exams", "KPSS · certification", Icons.Rounded.Work, ExamColors.Purple),
    Choice("Something else", "Build a custom plan", Icons.Rounded.AutoAwesome, ExamColors.Indigo)
)
private fun goalChoices() = listOf(
    Choice("Top 1K", "Aim for the highest score", Icons.Rounded.EmojiEvents, ExamColors.Amber),
    Choice("Top 10K", "Strong university options", Icons.Rounded.TrendingUp, ExamColors.Primary),
    Choice("Top 50K", "Build a reliable score", Icons.Rounded.TrackChanges, ExamColors.Mint),
    Choice("Pass comfortably", "Study with less stress", Icons.Rounded.CheckCircle, ExamColors.Purple),
    Choice("I don't know yet", "We'll help you decide", Icons.Rounded.Explore, ExamColors.Indigo)
)
private fun timeChoices() = listOf(
    Choice("10 min", "Quick habit", Icons.Rounded.Bolt, ExamColors.Mint),
    Choice("20 min", "Recommended", Icons.Rounded.Timer, ExamColors.Primary),
    Choice("30 min", "Serious progress", Icons.Rounded.LocalFireDepartment, ExamColors.Amber),
    Choice("45+ min", "Intensive", Icons.Rounded.RocketLaunch, ExamColors.Purple)
)
