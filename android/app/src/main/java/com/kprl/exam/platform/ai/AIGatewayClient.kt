package com.kprl.exam.platform.ai

import com.google.firebase.FirebaseApp
import com.google.firebase.functions.FirebaseFunctions
import com.kprl.exam.data.StudySetup

sealed class GatewayResult<out T> {
    data class Success<T>(val value: T) : GatewayResult<T>()
    data class Error(val message: String, val cause: Throwable? = null) : GatewayResult<Nothing>()
}

data class MediaJob(val requestId: String, val creditCost: Int)
data class MediaJobStatus(val status: String, val data: Any?)

class AIGatewayClient {
    private fun available(): Boolean =
        runCatching { FirebaseApp.getInstance() }.isSuccess

    private fun call(
        name: String,
        payload: Map<String, Any?>,
        onResult: (GatewayResult<Map<*, *>>) -> Unit
    ) {
        if (!available()) {
            onResult(GatewayResult.Error("Firebase is not configured."))
            return
        }

        FirebaseFunctions.getInstance()
            .getHttpsCallable(name)
            .call(payload)
            .addOnSuccessListener { response ->
                val data = response.data as? Map<*, *>
                if (data == null) onResult(GatewayResult.Error("Invalid backend response."))
                else onResult(GatewayResult.Success(data))
            }
            .addOnFailureListener { error ->
                onResult(GatewayResult.Error(error.message ?: "Backend call failed.", error))
            }
    }

    fun askTutor(
        setup: StudySetup,
        message: String,
        onResult: (GatewayResult<String>) -> Unit
    ) {
        call(
            "aiTutor",
            mapOf(
                "examId" to setup.exam.id,
                "contentPackId" to setup.exam.syllabusPackId,
                "language" to setup.languageCode,
                "message" to message
            )
        ) { result ->
            when (result) {
                is GatewayResult.Success -> onResult(
                    GatewayResult.Success(result.value["text"] as? String ?: "")
                )
                is GatewayResult.Error -> onResult(result)
            }
        }
    }

    fun solveQuestion(
        setup: StudySetup,
        extractedText: String?,
        imageDataUrl: String?,
        onResult: (GatewayResult<String>) -> Unit
    ) {
        call(
            "solveQuestion",
            mapOf(
                "examId" to setup.exam.id,
                "contentPackId" to setup.exam.syllabusPackId,
                "language" to setup.languageCode,
                "extractedText" to extractedText,
                "imageDataUrl" to imageDataUrl
            )
        ) { result ->
            when (result) {
                is GatewayResult.Success -> onResult(
                    GatewayResult.Success(result.value["text"] as? String ?: "")
                )
                is GatewayResult.Error -> onResult(result)
            }
        }
    }

    fun generatePractice(
        setup: StudySetup,
        topic: String,
        count: Int = 5,
        onResult: (GatewayResult<Map<*, *>>) -> Unit
    ) {
        call(
            "generatePractice",
            mapOf(
                "examId" to setup.exam.id,
                "contentPackId" to setup.exam.syllabusPackId,
                "language" to setup.languageCode,
                "topic" to topic,
                "count" to count
            ),
            onResult
        )
    }

    fun indexMaterial(
        materialId: String,
        title: String,
        mimeType: String,
        storagePath: String?,
        extractedText: String?,
        onResult: (GatewayResult<Map<*, *>>) -> Unit
    ) {
        call(
            "indexMaterial",
            mapOf(
                "materialId" to materialId,
                "title" to title,
                "mimeType" to mimeType,
                "storagePath" to storagePath,
                "extractedText" to extractedText
            ),
            onResult
        )
    }

    fun askMaterial(
        materialId: String,
        question: String,
        language: String,
        onResult: (GatewayResult<String>) -> Unit
    ) {
        call(
            "askMaterial",
            mapOf(
                "materialId" to materialId,
                "question" to question,
                "language" to language
            )
        ) { result ->
            when (result) {
                is GatewayResult.Success -> onResult(
                    GatewayResult.Success(result.value["text"] as? String ?: "")
                )
                is GatewayResult.Error -> onResult(result)
            }
        }
    }

    fun generateMedia(
        kind: String,
        prompt: String,
        onResult: (GatewayResult<MediaJob>) -> Unit
    ) {
        call("mediaGenerate", mapOf("kind" to kind, "prompt" to prompt)) { result ->
            when (result) {
                is GatewayResult.Success -> {
                    val id = result.value["requestId"] as? String
                    val cost = (result.value["creditCost"] as? Number)?.toInt() ?: 0
                    if (id == null) onResult(GatewayResult.Error("Missing media request id."))
                    else onResult(GatewayResult.Success(MediaJob(id, cost)))
                }
                is GatewayResult.Error -> onResult(result)
            }
        }
    }

    fun mediaStatus(
        requestId: String,
        onResult: (GatewayResult<MediaJobStatus>) -> Unit
    ) {
        call("mediaStatus", mapOf("requestId" to requestId)) { result ->
            when (result) {
                is GatewayResult.Success -> onResult(
                    GatewayResult.Success(
                        MediaJobStatus(
                            status = result.value["status"] as? String ?: "unknown",
                            data = result.value["data"]
                        )
                    )
                )
                is GatewayResult.Error -> onResult(result)
            }
        }
    }

    fun transcribeAudio(
        storagePath: String,
        onResult: (GatewayResult<String>) -> Unit
    ) {
        call("transcribeAudio", mapOf("storagePath" to storagePath)) { result ->
            when (result) {
                is GatewayResult.Success -> onResult(
                    GatewayResult.Success(result.value["text"] as? String ?: "")
                )
                is GatewayResult.Error -> onResult(result)
            }
        }
    }

    fun synthesizeSpeech(
        text: String,
        onResult: (GatewayResult<String>) -> Unit
    ) {
        call("synthesizeSpeech", mapOf("text" to text)) { result ->
            when (result) {
                is GatewayResult.Success -> onResult(
                    GatewayResult.Success(result.value["storagePath"] as? String ?: "")
                )
                is GatewayResult.Error -> onResult(result)
            }
        }
    }
}
