package com.kprl.exam.platform.voice

import android.content.Context
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.storage.FirebaseStorage
import com.google.firebase.storage.StorageMetadata
import com.kprl.exam.data.StudySetup
import com.kprl.exam.platform.ai.AIGatewayClient
import com.kprl.exam.platform.ai.GatewayResult
import java.io.File
import java.util.UUID

data class VoiceTutorResult(
    val transcript: String,
    val answer: String,
    val audioUrl: String?
)

class VoiceTutorService(
    private val context: Context,
    private val gateway: AIGatewayClient = AIGatewayClient()
) {
    private var recorder: MediaRecorder? = null
    private var currentFile: File? = null

    @Suppress("DEPRECATION")
    fun startRecording(): Result<Unit> = runCatching {
        check(recorder == null) { "Already recording." }

        val file = File(context.cacheDir, "voice_${UUID.randomUUID()}.m4a")
        val mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            MediaRecorder()
        }

        mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC)
        mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        mediaRecorder.setAudioEncodingBitRate(96_000)
        mediaRecorder.setAudioSamplingRate(44_100)
        mediaRecorder.setOutputFile(file.absolutePath)
        mediaRecorder.prepare()
        mediaRecorder.start()

        currentFile = file
        recorder = mediaRecorder
    }

    fun stopAndProcess(
        setup: StudySetup,
        onResult: (GatewayResult<VoiceTutorResult>) -> Unit
    ) {
        val file = currentFile
        val activeRecorder = recorder

        recorder = null
        currentFile = null

        if (file == null || activeRecorder == null) {
            onResult(GatewayResult.Error("No active recording."))
            return
        }

        runCatching { activeRecorder.stop() }
        activeRecorder.release()

        if (!file.exists() || file.length() == 0L) {
            file.delete()
            onResult(GatewayResult.Error("Recording is empty."))
            return
        }

        if (runCatching { FirebaseApp.getInstance() }.isFailure) {
            file.delete()
            onResult(GatewayResult.Error("Firebase is not configured."))
            return
        }

        val uid = FirebaseAuth.getInstance().currentUser?.uid
        if (uid == null) {
            file.delete()
            onResult(GatewayResult.Error("User session is not ready."))
            return
        }

        val path = "users/$uid/voice/${UUID.randomUUID()}.m4a"
        val metadata = StorageMetadata.Builder()
            .setContentType("audio/mp4")
            .build()

        FirebaseStorage.getInstance()
            .reference
            .child(path)
            .putFile(Uri.fromFile(file), metadata)
            .addOnSuccessListener {
                file.delete()
                gateway.transcribeAudio(path) { transcriptResult ->
                    when (transcriptResult) {
                        is GatewayResult.Error -> onResult(transcriptResult)
                        is GatewayResult.Success -> {
                            val transcript = transcriptResult.value
                            gateway.askTutor(setup, transcript) { tutorResult ->
                                when (tutorResult) {
                                    is GatewayResult.Error -> onResult(tutorResult)
                                    is GatewayResult.Success -> {
                                        val answer = tutorResult.value
                                        gateway.synthesizeSpeech(answer) { ttsResult ->
                                            when (ttsResult) {
                                                is GatewayResult.Error -> onResult(
                                                    GatewayResult.Success(
                                                        VoiceTutorResult(transcript, answer, null)
                                                    )
                                                )
                                                is GatewayResult.Success -> {
                                                    FirebaseStorage.getInstance()
                                                        .reference
                                                        .child(ttsResult.value)
                                                        .downloadUrl
                                                        .addOnSuccessListener { url ->
                                                            onResult(
                                                                GatewayResult.Success(
                                                                    VoiceTutorResult(
                                                                        transcript,
                                                                        answer,
                                                                        url.toString()
                                                                    )
                                                                )
                                                            )
                                                        }
                                                        .addOnFailureListener {
                                                            onResult(
                                                                GatewayResult.Success(
                                                                    VoiceTutorResult(
                                                                        transcript,
                                                                        answer,
                                                                        null
                                                                    )
                                                                )
                                                            )
                                                        }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .addOnFailureListener { error ->
                file.delete()
                onResult(GatewayResult.Error("Voice upload failed.", error))
            }
    }

    fun cancelRecording() {
        val active = recorder
        recorder = null
        currentFile?.delete()
        currentFile = null
        runCatching { active?.stop() }
        active?.release()
    }
}
