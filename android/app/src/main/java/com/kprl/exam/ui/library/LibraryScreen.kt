package com.kprl.exam.ui.library

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.ui.theme.ExamColors

@Composable
fun LibraryScreen(modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 20.dp)
    ) {
        Spacer(Modifier.height(12.dp))
        Text("Library", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text("Turn your own material into something you can study.", color = ExamColors.TextSecondary, fontSize = 13.sp)

        Spacer(Modifier.height(20.dp))
        Button(
            onClick = {},
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary),
            elevation = ButtonDefaults.buttonElevation(0.dp)
        ) {
            Icon(Icons.Rounded.Add, null)
            Spacer(Modifier.width(8.dp))
            Text("Add material", fontWeight = FontWeight.SemiBold)
        }

        Spacer(Modifier.height(32.dp))
        Surface(
            color = ExamColors.Surface,
            shape = RoundedCornerShape(24.dp),
            border = BorderStroke(1.dp, ExamColors.Border),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                Modifier.padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Box(
                    Modifier.size(68.dp).background(ExamColors.SoftBlue, RoundedCornerShape(22.dp)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Rounded.FolderOpen, null, tint = ExamColors.Primary, modifier = Modifier.size(30.dp))
                }
                Spacer(Modifier.height(16.dp))
                Text("Your study material lives here", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Spacer(Modifier.height(6.dp))
                Text(
                    "PDFs, photos, pasted text, audio and video can become summaries, flashcards and practice sets.",
                    color = ExamColors.TextSecondary,
                    fontSize = 13.sp,
                    lineHeight = 19.sp
                )
                Spacer(Modifier.height(18.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FormatChip("PDF")
                    FormatChip("Photo")
                    FormatChip("Audio")
                    FormatChip("Video")
                }
            }
        }
    }
}

@Composable
private fun FormatChip(text: String) {
    Surface(color = ExamColors.Background, shape = RoundedCornerShape(50), border = BorderStroke(1.dp, ExamColors.Border)) {
        Text(text, color = ExamColors.TextSecondary, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(horizontal = 10.dp, vertical = 7.dp))
    }
}
