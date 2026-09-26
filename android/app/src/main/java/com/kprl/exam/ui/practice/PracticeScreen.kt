package com.kprl.exam.ui.practice

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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.content.ContentPackRepository
import com.kprl.exam.data.StudySetup
import com.kprl.exam.ui.theme.ExamColors

@Composable
fun PracticeScreen(setup: StudySetup, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val pack = remember(setup.exam.syllabusPackId) {
        ContentPackRepository.load(context, setup.exam.syllabusPackId)
    }

    Column(
        modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 20.dp)
    ) {
        Spacer(Modifier.height(12.dp))
        Text("Practice", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text("Built around your ${setup.exam.shortName} content pack", color = ExamColors.TextSecondary, fontSize = 13.sp)

        Spacer(Modifier.height(22.dp))
        Column(
            Modifier.fillMaxWidth()
                .background(
                    Brush.linearGradient(listOf(ExamColors.Primary, ExamColors.Indigo)),
                    RoundedCornerShape(24.dp)
                )
                .padding(20.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.size(46.dp).background(Color.White.copy(alpha = .16f), RoundedCornerShape(14.dp)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Rounded.Bolt, null, tint = Color.White)
                }
                Spacer(Modifier.weight(1f))
                Text("5 MIN", color = Color.White.copy(alpha = .85f), fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(22.dp))
            Text("Quick Practice", color = Color.White, fontSize = 25.sp, fontWeight = FontWeight.Bold)
            Text("A short adaptive set from what matters most right now.", color = Color.White.copy(alpha = .82f), fontSize = 13.sp)
            Spacer(Modifier.height(18.dp))
            Surface(
                onClick = {},
                color = Color.White,
                contentColor = ExamColors.Primary,
                shape = RoundedCornerShape(16.dp)
            ) {
                Text("Start 5 questions", fontWeight = FontWeight.Bold, modifier = Modifier.fillMaxWidth().padding(16.dp), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
        }

        if (!pack?.units.isNullOrEmpty()) {
            Spacer(Modifier.height(22.dp))
            Text("Your exam", fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(9.dp))
            pack!!.units.take(4).forEach { unit ->
                val detail = buildString {
                    unit.questionCount?.let { append("$it questions") }
                    if (unit.questionCount != null && unit.durationMinutes != null) append(" · ")
                    unit.durationMinutes?.let { append("$it min") }
                    if (isEmpty()) append("Exam-specific practice")
                }
                PracticeRow(Icons.Rounded.MenuBook, unit.title, detail, ExamColors.Primary)
                Spacer(Modifier.height(8.dp))
            }
        }

        Spacer(Modifier.height(14.dp))
        PracticeRow(Icons.Rounded.Timer, "Mock Exam", "Use the official-style blueprint", ExamColors.Purple)
        Spacer(Modifier.height(9.dp))
        PracticeRow(Icons.Rounded.Refresh, "Mistakes", "Review patterns that cost you points", ExamColors.Coral)
        Spacer(Modifier.height(9.dp))
        PracticeRow(Icons.Rounded.Style, "Flashcards", "Spaced repetition due today", ExamColors.Mint)
        Spacer(Modifier.height(9.dp))
        PracticeRow(Icons.Rounded.AutoAwesome, "Create Practice", "Topic, note, PDF or pasted text", ExamColors.Amber)
    }
}

@Composable
private fun PracticeRow(icon: ImageVector, title: String, subtitle: String, accent: Color) {
    Surface(
        modifier = Modifier.fillMaxWidth().clickable {},
        color = ExamColors.Surface,
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(1.dp, ExamColors.Border)
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(44.dp).background(accent.copy(alpha = .11f), RoundedCornerShape(14.dp)),
                contentAlignment = Alignment.Center
            ) { Icon(icon, null, tint = accent) }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                Text(subtitle, color = ExamColors.TextSecondary, fontSize = 11.sp)
            }
            Icon(Icons.Rounded.ChevronRight, null, tint = ExamColors.TextSecondary)
        }
    }
}
