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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.data.StudySetup
import com.kprl.exam.ui.components.ExamStatPill
import com.kprl.exam.ui.library.LibraryScreen
import com.kprl.exam.ui.practice.PracticeScreen
import com.kprl.exam.ui.theme.ExamColors
import com.kprl.exam.ui.tutor.AITutorScreen

private data class NavItem(val label: String, val icon: ImageVector)

@Composable
fun TodayScreen(setup: StudySetup) {
    var selectedTab by remember { mutableIntStateOf(0) }
    val nav = listOf(
        NavItem("Today", Icons.Rounded.Home),
        NavItem("Practice", Icons.Rounded.EditNote),
        NavItem("AI Tutor", Icons.Rounded.AutoAwesome),
        NavItem("Library", Icons.Rounded.FolderOpen)
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
            0 -> TodayContent(setup, Modifier.padding(padding))
            1 -> PracticeScreen(setup, Modifier.padding(padding))
            2 -> AITutorScreen(setup, Modifier.padding(padding))
            else -> LibraryScreen(Modifier.padding(padding))
        }
    }
}

@Composable
private fun TodayContent(setup: StudySetup, modifier: Modifier) {
    Column(modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 20.dp)) {
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("Good evening", color = ExamColors.TextSecondary, fontSize = 13.sp)
                Text("Ready for a small win? 👋", fontWeight = FontWeight.Bold, fontSize = 22.sp)
            }
            Box(Modifier.size(42.dp).background(ExamColors.SoftBlue, RoundedCornerShape(16.dp)), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Person, null, tint = ExamColors.Primary)
            }
        }

        Spacer(Modifier.height(20.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            ExamStatPill("7", "day streak", Icons.Rounded.LocalFireDepartment, ExamColors.Amber, Modifier.weight(1f))
            ExamStatPill(setup.exam.shortName, "active exam", Icons.Rounded.School, ExamColors.Mint, Modifier.weight(1f))
            ExamStatPill("61", "mastery", Icons.Rounded.Insights, ExamColors.Purple, Modifier.weight(1f))
        }

        Spacer(Modifier.height(24.dp))
        Text("TODAY'S ${setup.exam.shortName.uppercase()} PLAN", color = ExamColors.TextSecondary, fontSize = 11.sp, fontWeight = FontWeight.Bold)
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
            Text("Core practice", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
            Text(setup.exam.title, color = Color.White.copy(alpha = .82f), fontSize = 14.sp)
            Spacer(Modifier.height(18.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.Schedule, null, tint = Color.White.copy(alpha = .9f), modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text("14 min", color = Color.White.copy(alpha = .9f), fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(18.dp))
            Button(
                onClick = {},
                colors = ButtonDefaults.buttonColors(containerColor = Color.White, contentColor = ExamColors.Primary),
                elevation = ButtonDefaults.buttonElevation(0.dp),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth().height(52.dp)
            ) { Text("Continue", fontWeight = FontWeight.Bold) }
        }

        Spacer(Modifier.height(24.dp))
        Text("Next up", fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(10.dp))
        NextRow(Icons.Rounded.FactCheck, "Exam-style questions", "5 questions", ExamColors.Purple)
        Spacer(Modifier.height(8.dp))
        NextRow(Icons.Rounded.Refresh, "Review mistakes", "3 mistakes", ExamColors.Coral)
        Spacer(Modifier.height(18.dp))
        NextRow(Icons.Rounded.AutoAwesome, "Ask your tutor", "Explain, scan or practice anything", ExamColors.Purple)
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
