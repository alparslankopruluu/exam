package com.kprl.exam.ui.tutor

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.data.StudySetup
import com.kprl.exam.platform.ai.AIGatewayClient
import com.kprl.exam.platform.ai.GatewayResult
import com.kprl.exam.platform.scan.QuestionScanner
import com.kprl.exam.ui.theme.ExamColors
import java.io.ByteArrayOutputStream

@Composable
fun AITutorScreen(
    setup: StudySetup,
    modifier: Modifier = Modifier,
    onVoiceTutor: () -> Unit = {},
    onStudyNotes: () -> Unit = {},
    onMediaLab: () -> Unit = {}
) {
    val context = LocalContext.current
    val gateway = remember { AIGatewayClient() }
    val scanner = remember { QuestionScanner() }

    var prompt by remember { mutableStateOf("") }
    var answer by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    fun solveBitmap(bitmap: Bitmap) {
        loading = true
        error = null
        answer = null

        scanner.recognize(bitmap, setup.languageCode) { ocrResult ->
            val extracted = ocrResult.getOrNull().orEmpty()
            gateway.solveQuestion(
                setup = setup,
                extractedText = extracted.takeIf { it.isNotBlank() },
                imageDataUrl = bitmap.toDataUrl()
            ) { result ->
                loading = false
                when (result) {
                    is GatewayResult.Success -> answer = result.value
                    is GatewayResult.Error -> error = result.message
                }
            }
        }
    }

    val photoPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        val bitmap = runCatching {
            context.contentResolver.openInputStream(uri)?.use(BitmapFactory::decodeStream)
        }.getOrNull()

        if (bitmap == null) error = "Could not read the selected image."
        else solveBitmap(bitmap)
    }

    val camera = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicturePreview()
    ) { bitmap ->
        if (bitmap != null) solveBitmap(bitmap)
    }

    fun sendPrompt() {
        val message = prompt.trim()
        if (message.isEmpty() || loading) return

        loading = true
        error = null
        answer = null

        gateway.askTutor(setup, message) { result ->
            loading = false
            when (result) {
                is GatewayResult.Success -> {
                    answer = result.value
                    prompt = ""
                }
                is GatewayResult.Error -> error = result.message
            }
        }
    }

    Column(
        modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 20.dp)
    ) {
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(48.dp).background(ExamColors.SoftPurple, RoundedCornerShape(16.dp)),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Rounded.AutoAwesome, null, tint = ExamColors.Purple)
            }
            Spacer(Modifier.width(12.dp))
            Column {
                Text("AI Tutor", fontSize = 27.sp, fontWeight = FontWeight.Bold)
                Text(
                    "Context-aware for ${setup.exam.shortName}",
                    color = ExamColors.TextSecondary,
                    fontSize = 12.sp
                )
            }
        }

        Spacer(Modifier.height(24.dp))
        Text("What do you need help with?", fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(12.dp))

        TutorAction(
            Icons.Rounded.DocumentScanner,
            "Solve a question",
            "Upload a photo · OCR + vision",
            ExamColors.Primary
        ) { photoPicker.launch("image/*") }

        Spacer(Modifier.height(9.dp))
        TutorAction(
            Icons.Rounded.Lightbulb,
            "Explain a concept",
            "Simple, visual or from zero",
            ExamColors.Amber
        ) {
            prompt = "Explain this concept simply: "
        }

        Spacer(Modifier.height(9.dp))
        TutorAction(
            Icons.Rounded.FolderOpen,
            "Study my notes",
            "Ask questions from indexed Library materials",
            ExamColors.Mint,
            onStudyNotes
        )

        Spacer(Modifier.height(9.dp))
        TutorAction(
            Icons.Rounded.Image,
            "Visual explanation",
            "Generate a study image or video with credits",
            ExamColors.Primary,
            onMediaLab
        )

        Spacer(Modifier.height(9.dp))
        TutorAction(
            Icons.Rounded.GraphicEq,
            "Talk to tutor",
            "Interactive voice · Premium",
            ExamColors.Purple,
            onVoiceTutor
        )

        if (loading || answer != null || error != null) {
            Spacer(Modifier.height(16.dp))
            Surface(
                color = ExamColors.Surface,
                shape = RoundedCornerShape(18.dp),
                border = BorderStroke(1.dp, ExamColors.Border),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(Modifier.padding(15.dp)) {
                    if (loading) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(20.dp),
                                strokeWidth = 2.dp,
                                color = ExamColors.Primary
                            )
                            Spacer(Modifier.width(10.dp))
                            Text("Tutor is working…", color = ExamColors.TextSecondary)
                        }
                    }

                    answer?.let {
                        Text("Tutor", fontWeight = FontWeight.Bold, color = ExamColors.Purple)
                        Spacer(Modifier.height(7.dp))
                        Text(it, fontSize = 13.sp, lineHeight = 19.sp)
                    }

                    error?.let {
                        Text(it, color = ExamColors.Coral, fontSize = 12.sp)
                    }
                }
            }
        }

        Spacer(Modifier.weight(1f))
        Surface(
            color = ExamColors.Surface,
            shape = RoundedCornerShape(20.dp),
            border = BorderStroke(1.dp, ExamColors.Border),
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = { camera.launch(null) }) {
                    Icon(Icons.Rounded.CameraAlt, "Camera", tint = ExamColors.TextSecondary)
                }

                TextField(
                    value = prompt,
                    onValueChange = { prompt = it },
                    placeholder = { Text("Ask anything…", color = ExamColors.TextSecondary) },
                    modifier = Modifier.weight(1f),
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent
                    ),
                    maxLines = 3
                )

                IconButton(onClick = onVoiceTutor) {
                    Icon(Icons.Rounded.Mic, "Voice", tint = ExamColors.Purple)
                }

                IconButton(
                    onClick = ::sendPrompt,
                    enabled = prompt.isNotBlank() && !loading
                ) {
                    Box(
                        Modifier.size(42.dp).background(
                            if (prompt.isNotBlank()) ExamColors.Primary else ExamColors.Border,
                            RoundedCornerShape(14.dp)
                        ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Rounded.ArrowUpward, "Send", tint = Color.White)
                    }
                }
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
            ) {
                Icon(icon, null, tint = accent)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                Text(subtitle, color = ExamColors.TextSecondary, fontSize = 11.sp)
            }
            Icon(Icons.Rounded.ChevronRight, null, tint = ExamColors.TextSecondary)
        }
    }
}

private fun Bitmap.toDataUrl(): String {
    val stream = ByteArrayOutputStream()
    compress(Bitmap.CompressFormat.JPEG, 88, stream)
    val encoded = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    return "data:image/jpeg;base64,$encoded"
}
