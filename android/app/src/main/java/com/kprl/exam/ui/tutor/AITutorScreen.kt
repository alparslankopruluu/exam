package com.kprl.exam.ui.tutor

import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.ui.res.painterResource
import com.kprl.exam.R
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
import com.kprl.exam.analytics.AnalyticsEvents
import com.kprl.exam.analytics.AnalyticsParams
import com.kprl.exam.platform.AppServices
import com.kprl.exam.localization.LocalizedCopy
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
    onMediaLab: () -> Unit = {},
    onPaywall: (String) -> Unit = {}
) {
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    val gateway = remember { AIGatewayClient() }
    val scanner = remember { QuestionScanner() }

    var prompt by remember { mutableStateOf("") }
    var scanning by remember { mutableStateOf(false) }
    var answer by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        AppServices.analytics.event(
            AnalyticsEvents.AI_TUTOR_STARTED,
            mapOf(
                AnalyticsParams.EXAM_ID to setup.exam.id,
                AnalyticsParams.CONTENT_PACK_ID to setup.exam.syllabusPackId
            )
        )
    }

    fun solveBitmap(bitmap: Bitmap, source: String) {
        loading = true
        error = null
        answer = null
        AppServices.analytics.event(
            AnalyticsEvents.SCAN_STARTED,
            mapOf(
                AnalyticsParams.EXAM_ID to setup.exam.id,
                AnalyticsParams.SOURCE to source
            )
        )

        scanner.recognize(bitmap, setup.languageCode) { ocrResult ->
            val extracted = ocrResult.getOrNull().orEmpty()
            gateway.solveQuestion(
                setup = setup,
                extractedText = extracted.takeIf { it.isNotBlank() },
                imageDataUrl = bitmap.toDataUrl()
            ) { result ->
                loading = false
                when (result) {
                    is GatewayResult.Success -> {
                        answer = result.value
                        AppServices.analytics.event(
                            AnalyticsEvents.SCAN_COMPLETED,
                            mapOf(
                                AnalyticsParams.EXAM_ID to setup.exam.id,
                                AnalyticsParams.SOURCE to source
                            )
                        )
                    }
                    is GatewayResult.Error -> {
                        if (result.message.contains("Daily AI limit", ignoreCase = true)) onPaywall("ai_limit")
                        else error = result.message
                    }
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

        if (bitmap == null) error = copy.text("error_image_load")
        else solveBitmap(bitmap, "gallery")
    }

    val camera = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicturePreview()
    ) { bitmap ->
        if (bitmap != null) solveBitmap(bitmap, "camera")
    }

    fun sendPrompt() {
        val message = prompt.trim()
        if (message.isEmpty() || loading) return

        loading = true
        error = null
        answer = null
        AppServices.analytics.event(
            AnalyticsEvents.AI_MESSAGE_SENT,
            mapOf(
                AnalyticsParams.EXAM_ID to setup.exam.id,
                AnalyticsParams.SOURCE to "text"
            )
        )

        gateway.askTutor(setup, message) { result ->
            loading = false
            when (result) {
                is GatewayResult.Success -> {
                    answer = result.value
                    prompt = ""
                }
                is GatewayResult.Error -> {
                        if (result.message.contains("Daily AI limit", ignoreCase = true)) onPaywall("ai_limit")
                        else error = result.message
                    }
            }
        }
    }

    if (scanning) {
        ScanQuestionScreen(
            copy = copy,
            onClose = { scanning = false },
            onGallery = { scanning = false; photoPicker.launch("image/*") },
            onImage = { scanning = false; solveBitmap(it, "camera") }
        )
        return
    }

    Column(
        modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 20.dp)
    ) {
        Spacer(Modifier.height(8.dp))
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            TutorMascot(Modifier.size(104.dp))
            Text(copy.text("ai_tutor"), fontSize = 27.sp, fontWeight = FontWeight.Bold)
            Text(
                copy.text("tutor_context", mapOf("exam" to setup.exam.shortName)),
                color = ExamColors.TextSecondary,
                fontSize = 13.sp
            )
        }

        Spacer(Modifier.height(16.dp))
        Text(copy.text("what_help"), fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(12.dp))

        TutorAction(
            Icons.Rounded.DocumentScanner,
            copy.text("solve_question"),
            copy.text("solve_question_hint"),
            ExamColors.Primary
        ) { scanning = true }

        Spacer(Modifier.height(9.dp))
        TutorAction(
            Icons.Rounded.Lightbulb,
            copy.text("explain_concept"),
            copy.text("explain_concept_hint"),
            ExamColors.Amber
        ) {
            prompt = copy.text("explain_prefill") + " "
        }

        Spacer(Modifier.height(9.dp))
        TutorAction(
            Icons.Rounded.FolderOpen,
            copy.text("study_notes"),
            copy.text("study_notes_hint"),
            ExamColors.Mint,
            onStudyNotes
        )

        Spacer(Modifier.height(9.dp))
        TutorAction(
            Icons.Rounded.Image,
            copy.text("visual_explanation"),
            copy.text("visual_explanation_hint"),
            ExamColors.Primary,
            onMediaLab
        )

        Spacer(Modifier.height(9.dp))
        TutorAction(
            Icons.Rounded.GraphicEq,
            copy.text("talk_tutor"),
            copy.text("talk_tutor_hint"),
            ExamColors.Purple
        ) {
            AppServices.analytics.event(
                AnalyticsEvents.VOICE_TUTOR_STARTED,
                mapOf(AnalyticsParams.EXAM_ID to setup.exam.id)
            )
            onVoiceTutor()
        }

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
                            Text(copy.text("tutor_working"), color = ExamColors.TextSecondary)
                        }
                    }

                    answer?.let {
                        Text(copy.text("tutor_label"), fontWeight = FontWeight.Bold, color = ExamColors.Purple)
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
                    placeholder = { Text(copy.text("ask_anything"), color = ExamColors.TextSecondary) },
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

/** The tutor robot (design/illustrations/tutor_bot.svg) floating gently (mirrors iOS TutorMascot). */
@Composable
fun TutorMascot(modifier: Modifier = Modifier) {
    val float by rememberInfiniteTransition(label = "mascot").animateFloat(
        initialValue = -5f,
        targetValue = 5f,
        animationSpec = infiniteRepeatable(tween(1800), RepeatMode.Reverse),
        label = "float"
    )
    Image(
        painterResource(R.drawable.illu_tutor_bot), null,
        modifier = modifier.graphicsLayer { translationY = float.dp.toPx() }
    )
}
