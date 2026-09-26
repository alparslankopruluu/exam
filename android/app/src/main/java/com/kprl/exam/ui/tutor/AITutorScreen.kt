package com.kprl.exam.ui.tutor

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.data.StudySetup
import com.kprl.exam.ui.theme.ExamColors

@Composable
fun AITutorScreen(
    setup: StudySetup,
    modifier: Modifier = Modifier,
    onVoiceTutor: () -> Unit = {}
) {
    Column(
        modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 20.dp)
    ) {
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(48.dp).background(ExamColors.SoftPurple, RoundedCornerShape(16.dp)),
                contentAlignment = Alignment.Center
            ) { Icon(Icons.Rounded.AutoAwesome, null, tint = ExamColors.Purple) }
            Spacer(Modifier.width(12.dp))
            Column {
                Text("AI Tutor", fontSize = 27.sp, fontWeight = FontWeight.Bold)
                Text("Context-aware for ${setup.exam.shortName}", color = ExamColors.TextSecondary, fontSize = 12.sp)
            }
        }

        Spacer(Modifier.height(24.dp))
        Text("What do you need help with?", fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(12.dp))

        TutorAction(Icons.Rounded.DocumentScanner, "Solve a question", "Take a photo or upload", ExamColors.Primary)
        Spacer(Modifier.height(9.dp))
        TutorAction(Icons.Rounded.Lightbulb, "Explain a concept", "Simple, visual or from zero", ExamColors.Amber)
        Spacer(Modifier.height(9.dp))
        TutorAction(Icons.Rounded.FolderOpen, "Study my notes", "Ask questions about your materials", ExamColors.Mint)
        Spacer(Modifier.height(9.dp))
        TutorAction(Icons.Rounded.GraphicEq, "Talk to tutor", "Interactive voice · Premium", ExamColors.Purple, onVoiceTutor)

        Spacer(Modifier.weight(1f))
        Surface(
            color = ExamColors.Surface,
            shape = RoundedCornerShape(20.dp),
            border = BorderStroke(1.dp, ExamColors.Border),
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = {}) { Icon(Icons.Rounded.CameraAlt, "Camera", tint = ExamColors.TextSecondary) }
                Text("Ask anything…", color = ExamColors.TextSecondary, fontSize = 14.sp, modifier = Modifier.weight(1f))
                IconButton(onClick = {}) { Icon(Icons.Rounded.Mic, "Voice", tint = ExamColors.Purple) }
                Box(
                    Modifier.size(42.dp).background(ExamColors.Primary, RoundedCornerShape(14.dp)),
                    contentAlignment = Alignment.Center
                ) { Icon(Icons.Rounded.ArrowUpward, "Send", tint = Color.White) }
            }
        }
        Spacer(Modifier.height(14.dp))
    }
}

@Composable
private fun TutorAction(
    icon: ImageVector,
    title: String,
    subtitle: String,
    accent: Color,
    onClick: () -> Unit = {}
) {
    Surface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
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
