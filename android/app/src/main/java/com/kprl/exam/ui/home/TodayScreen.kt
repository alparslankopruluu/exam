package com.kprl.exam.ui.home

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.data.StudySetup
import com.kprl.exam.localization.LocalizedCopy
import com.kprl.exam.ui.components.ExamStatPill
import com.kprl.exam.ui.library.LibraryScreen
import com.kprl.exam.ui.paywall.PremiumPaywallScreen
import com.kprl.exam.ui.practice.PracticeScreen
import com.kprl.exam.ui.question.QuestionSessionScreen
import com.kprl.exam.ui.theme.ExamColors
import com.kprl.exam.ui.tutor.AITutorScreen

private data class NavItem(val label: String, val icon: ImageVector)

@Composable
fun TodayScreen(setup: StudySetup) {
    var selectedTab by remember { mutableIntStateOf(0) }
    var premiumPlacement by remember { mutableStateOf<String?>(null) }
    var quickPracticeOpen by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }

    when {
        premiumPlacement != null -> {
            PremiumPaywallScreen(
                setup = setup,
                placement = premiumPlacement!!,
                onClose = { premiumPlacement = null }
            )
            return
        }
        quickPracticeOpen -> {
            QuestionSessionScreen(
                setup = setup,
                onClose = { quickPracticeOpen = false }
            )
            return
        }
    }

    val nav = listOf(
        NavItem(copy.text("today"), Icons.Rounded.Home),
        NavItem(copy.text("practice"), Icons.Rounded.EditNote),
        NavItem(copy.text("ai_tutor"), Icons.Rounded.AutoAwesome),
        NavItem(copy.text("library"), Icons.Rounded.FolderOpen)
    )

    Scaffold(
        containerColor = ExamColors.Background,
        bottomBar = {
            Surface(color = ExamColors.Surface, shadowElevation = 8.dp) {
                Row(
                    Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 8.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceAround
                ) {
                    nav.forEachIndexed { index, item ->
                        Column(
                            Modifier.clip(RoundedCornerShape(14.dp)).clickable { selectedTab = index }.padding(horizontal = 12.dp, vertical = 6.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(item.icon, item.label, tint = if (selectedTab == index) ExamColors.Primary else ExamColors.TextSecondary, modifier = Modifier.size(22.dp))
                            Text(item.label, fontSize = 10.sp, fontWeight = if (selectedTab == index) FontWeight.Bold else FontWeight.Medium, color = if (selectedTab == index) ExamColors.Primary else ExamColors.TextSecondary)
                        }
                    }
                }
            }
        }
    ) { padding ->
        when (selectedTab) {
            0 -> TodayContent(setup, copy, Modifier.padding(padding))
            1 -> PracticeScreen(
                setup = setup,
                modifier = Modifier.padding(padding),
                onQuickPractice = { quickPracticeOpen = true }
            )
            2 -> AITutorScreen(
                setup = setup,
                modifier = Modifier.padding(padding),
                onVoiceTutor = { premiumPlacement = "voice_tutor" }
            )
            else -> LibraryScreen(Modifier.padding(padding))
        }
    }
}

@Composable
private fun TodayContent(setup: StudySetup, copy: LocalizedCopy, modifier: Modifier) {
    Column(modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 20.dp)) {
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(copy.text("good_evening"), color = ExamColors.TextSecondary, fontSize = 13.sp)
                Text(copy.text("ready_small_win"), fontWeight = FontWeight.Bold, fontSize = 22.sp)
            }
            Box(Modifier.size(42.dp).background(ExamColors.SoftBlue, RoundedCornerShape(16.dp)), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Person, null, tint = ExamColors.Primary)
            }
        }

        Spacer(Modifier.height(20.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            ExamStatPill("7", copy.text("day_streak"), Icons.Rounded.LocalFireDepartment, ExamColors.Amber, Modifier.weight(1f))
            ExamStatPill(setup.exam.shortName, copy.text("active_exam"), Icons.Rounded.School, ExamColors.Mint, Modifier.weight(1f))
            ExamStatPill("61", copy.text("mastery"), Icons.Rounded.Insights, ExamColors.Purple, Modifier.weight(1f))
        }

        Spacer(Modifier.height(24.dp))
        Text(copy.text("todays_plan", mapOf("exam" to setup.exam.shortName)).uppercase(), color = ExamColors.TextSecondary, fontSize = 11.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(9.dp))

        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp))
                .background(Brush.linearGradient(listOf(ExamColors.Primary, ExamColors.Indigo))).padding(20.dp)
        ) {
            Row {
                Box(Modifier.size(42.dp).background(Color.White.copy(alpha = .16f), RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.AutoStories, null, tint = Color.White)
                }
                Spacer(Modifier.weight(1f))
                Text("+80 XP", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 11.sp, modifier = Modifier.background(Color.White.copy(alpha = .16f), RoundedCornerShape(50)).padding(horizontal = 10.dp, vertical = 6.dp))
            }
            Spacer(Modifier.height(24.dp))
            Text(copy.text("core_practice"), color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
            Text(setup.exam.title, color = Color.White.copy(alpha = .82f), fontSize = 14.sp)
            Spacer(Modifier.height(18.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.Schedule, null, tint = Color.White.copy(alpha = .9f), modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text("14 min", color = Color.White.copy(alpha = .9f), fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(18.dp))
            Button(
                onClick = { },
                colors = ButtonDefaults.buttonColors(containerColor = Color.White, contentColor = ExamColors.Primary),
                elevation = ButtonDefaults.buttonElevation(0.dp),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth().height(52.dp)
            ) { Text(copy.text("continue"), fontWeight = FontWeight.Bold) }
        }

        Spacer(Modifier.height(24.dp))
        Text(copy.text("next_up"), fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(10.dp))
        NextRow(Icons.Rounded.FactCheck, copy.text("exam_style_questions"), copy.text("questions_count", mapOf("count" to "5")), ExamColors.Purple)
        Spacer(Modifier.height(8.dp))
        NextRow(Icons.Rounded.Refresh, copy.text("review_mistakes"), copy.text("mistakes_count", mapOf("count" to "3")), ExamColors.Coral)
        Spacer(Modifier.height(18.dp))
        NextRow(Icons.Rounded.AutoAwesome, copy.text("ask_tutor"), copy.text("explain_scan_practice"), ExamColors.Purple)
    }
}

@Composable
private fun NextRow(icon: ImageVector, title: String, subtitle: String, accent: Color) {
    Surface(shape = RoundedCornerShape(17.dp), color = ExamColors.Surface, border = BorderStroke(1.dp, ExamColors.Border)) {
        Row(Modifier.fillMaxWidth().padding(13.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(40.dp).background(accent.copy(alpha = .10f), RoundedCornerShape(13.dp)), contentAlignment = Alignment.Center) {
                Icon(icon, null, tint = accent, modifier = Modifier.size(20.dp))
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.SemiBold)
                Text(subtitle, color = ExamColors.TextSecondary, fontSize = 11.sp)
            }
            Icon(Icons.Rounded.ChevronRight, null, tint = ExamColors.TextSecondary)
        }
    }
}
