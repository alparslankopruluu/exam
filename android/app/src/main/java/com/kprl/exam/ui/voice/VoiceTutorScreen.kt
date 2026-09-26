package com.kprl.exam.ui.voice

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaPlayer
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
import androidx.core.content.ContextCompat
import com.kprl.exam.data.StudySetup
import com.kprl.exam.platform.ai.GatewayResult
import com.kprl.exam.platform.voice.VoiceTutorResult
import com.kprl.exam.platform.voice.VoiceTutorService
import com.kprl.exam.ui.theme.ExamColors

@Composable
fun VoiceTutorScreen(
    setup: StudySetup,
    onClose: () -> Unit
) {
    val context = LocalContext.current
    val service = remember { VoiceTutorService(context.applicationContext) }

    var recording by remember { mutableStateOf(false) }
    var processing by remember { mutableStateOf(false) }
    var result by remember { mutableStateOf<VoiceTutorResult?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    fun beginRecording() {
        error = null
        result = null
        service.startRecording()
            .onSuccess { recording = true }
            .onFailure { error = it.message ?: "Could not start recording." }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) beginRecording()
        else error = "Microphone permission is required for Voice Tutor."
    }

    fun requestStart() {
        if (
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            beginRecording()
        } else {
            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    fun stop() {
        recording = false
        processing = true
        error = null

        service.stopAndProcess(setup) { response ->
            processing = false
            when (response) {
                is GatewayResult.Success -> result = response.value
                is GatewayResult.Error -> error = response.message
            }
        }
    }

    DisposableEffect(Unit) {
        onDispose { service.cancelRecording() }
    }

    Column(
        Modifier.fillMaxSize()
            .background(ExamColors.Background)
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onClose) {
                Icon(Icons.Rounded.Close, "Close")
            }
            Spacer(Modifier.weight(1f))
            Surface(
                color = ExamColors.SoftPurple,
                shape = RoundedCornerShape(50)
            ) {
                Text(
                    setup.exam.shortName + " · PREMIUM",
                    color = ExamColors.Purple,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                )
            }
        }

        Spacer(Modifier.height(24.dp))
        Text("Voice Tutor", fontSize = 30.sp, fontWeight = FontWeight.Bold)
        Text(
            "Ask naturally. Your speech is transcribed, answered in ${setup.exam.shortName} context, then spoken back.",
            color = ExamColors.TextSecondary,
            fontSize = 14.sp,
            lineHeight = 20.sp
        )

        Spacer(Modifier.height(28.dp))
        Box(
            Modifier.fillMaxWidth()
                .height(190.dp)
                .background(ExamColors.Surface, RoundedCornerShape(28.dp)),
            contentAlignment = Alignment.Center
        ) {
            when {
                processing -> {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        CircularProgressIndicator(color = ExamColors.Purple)
                        Spacer(Modifier.height(12.dp))
                        Text("Understanding & preparing your answer…")
                    }
                }
                recording -> {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            Icons.Rounded.GraphicEq,
                            null,
                            tint = ExamColors.Coral,
                            modifier = Modifier.size(56.dp)
                        )
                        Spacer(Modifier.height(12.dp))
                        Text("Listening…", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                    }
                }
                else -> {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            Icons.Rounded.Mic,
                            null,
                            tint = ExamColors.Purple,
                            modifier = Modifier.size(54.dp)
                        )
                        Spacer(Modifier.height(12.dp))
                        Text("Tap to ask your tutor", fontWeight = FontWeight.Bold, fontSize = 19.sp)
                    }
                }
            }
        }

        error?.let {
            Spacer(Modifier.height(12.dp))
            Text(it, color = ExamColors.Coral, fontSize = 12.sp)
        }

        result?.let { voice ->
            Spacer(Modifier.height(18.dp))
            Surface(
                color = ExamColors.Surface,
                shape = RoundedCornerShape(20.dp),
                border = BorderStroke(1.dp, ExamColors.Border)
            ) {
                Column(Modifier.padding(16.dp)) {
                    Text("You", color = ExamColors.TextSecondary, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    Text(voice.transcript, fontSize = 13.sp, lineHeight = 19.sp)
                    Spacer(Modifier.height(12.dp))
                    Text("Tutor", color = ExamColors.Purple, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    Text(voice.answer, fontSize = 13.sp, lineHeight = 19.sp)
                    voice.audioUrl?.let { audioUrl ->
                        Spacer(Modifier.height(12.dp))
                        AssistChip(
                            onClick = {
                                MediaPlayer().apply {
                                    setDataSource(audioUrl)
                                    setOnPreparedListener { it.start() }
                                    setOnCompletionListener { it.release() }
                                    prepareAsync()
                                }
                            },
                            label = { Text("Play spoken answer") },
                            leadingIcon = { Icon(Icons.Rounded.VolumeUp, null) }
                        )
                    }
                }
            }
        }

        Spacer(Modifier.weight(1f))
        Button(
            onClick = { if (recording) stop() else requestStart() },
            enabled = !processing,
            modifier = Modifier.fillMaxWidth().height(58.dp),
            shape = RoundedCornerShape(19.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = if (recording) ExamColors.Coral else ExamColors.Primary
            ),
            elevation = ButtonDefaults.buttonElevation(0.dp)
        ) {
            Icon(if (recording) Icons.Rounded.Stop else Icons.Rounded.Mic, null)
            Spacer(Modifier.width(8.dp))
            Text(if (recording) "Stop & ask" else "Start speaking", fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(12.dp))
    }
}
