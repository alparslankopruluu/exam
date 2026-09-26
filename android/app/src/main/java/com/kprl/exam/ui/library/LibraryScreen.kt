package com.kprl.exam.ui.library

import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.platform.ai.GatewayResult
import com.kprl.exam.platform.library.LibraryUploadService
import com.kprl.exam.ui.theme.ExamColors

@Composable
fun LibraryScreen(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val uploader = remember { LibraryUploadService(context.applicationContext) }

    var loading by remember { mutableStateOf(false) }
    var latestTitle by remember { mutableStateOf<String?>(null) }
    var latestSummary by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    val picker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult

        runCatching {
            context.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        }

        loading = true
        error = null

        uploader.uploadAndIndex(uri) { result ->
            loading = false
            when (result) {
                is GatewayResult.Success -> {
                    latestTitle = result.value.title
                    latestSummary = result.value.summary
                }
                is GatewayResult.Error -> error = result.message
            }
        }
    }

    Column(
        modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 20.dp)
    ) {
        Spacer(Modifier.height(12.dp))
        Text("Library", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text(
            "Turn your own material into something you can study.",
            color = ExamColors.TextSecondary,
            fontSize = 13.sp
        )

        Spacer(Modifier.height(20.dp))
        Button(
            onClick = {
                picker.launch(
                    arrayOf(
                        "application/pdf",
                        "image/*",
                        "audio/*",
                        "video/*",
                        "text/plain"
                    )
                )
            },
            enabled = !loading,
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary),
            elevation = ButtonDefaults.buttonElevation(0.dp)
        ) {
            if (loading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    color = androidx.compose.ui.graphics.Color.White,
                    strokeWidth = 2.dp
                )
            } else {
                Icon(Icons.Rounded.Add, null)
            }
            Spacer(Modifier.width(8.dp))
            Text(if (loading) "Uploading & indexing…" else "Add material", fontWeight = FontWeight.SemiBold)
        }

        error?.let {
            Spacer(Modifier.height(10.dp))
            Text(it, color = ExamColors.Coral, fontSize = 12.sp)
        }

        if (latestTitle != null) {
            Spacer(Modifier.height(18.dp))
            Surface(
                color = ExamColors.Surface,
                shape = RoundedCornerShape(18.dp),
                border = BorderStroke(1.dp, ExamColors.Border),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(Modifier.padding(15.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.CheckCircle, null, tint = ExamColors.Mint)
                        Spacer(Modifier.width(8.dp))
                        Text(latestTitle.orEmpty(), fontWeight = FontWeight.SemiBold)
                    }
                    latestSummary?.takeIf { it.isNotBlank() }?.let { summary ->
                        Spacer(Modifier.height(8.dp))
                        Text(
                            summary,
                            color = ExamColors.TextSecondary,
                            fontSize = 12.sp,
                            lineHeight = 18.sp,
                            maxLines = 5
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Indexed · ready for summary, quiz, flashcards and Q&A",
                        color = ExamColors.Mint,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }

        Spacer(Modifier.height(24.dp))
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
                    Icon(
                        Icons.Rounded.FolderOpen,
                        null,
                        tint = ExamColors.Primary,
                        modifier = Modifier.size(30.dp)
                    )
                }
                Spacer(Modifier.height(16.dp))
                Text("Your study material lives here", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Spacer(Modifier.height(6.dp))
                Text(
                    "PDFs, photos, pasted text, audio and video become searchable study context, summaries and practice sets.",
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
    Surface(
        color = ExamColors.Background,
        shape = RoundedCornerShape(50),
        border = BorderStroke(1.dp, ExamColors.Border)
    ) {
        Text(
            text,
            color = ExamColors.TextSecondary,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 7.dp)
        )
    }
}
