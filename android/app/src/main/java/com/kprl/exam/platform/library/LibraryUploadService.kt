package com.kprl.exam.platform.library

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.storage.FirebaseStorage
import com.google.firebase.storage.StorageMetadata
import com.kprl.exam.platform.ai.AIGatewayClient
import com.kprl.exam.platform.ai.GatewayResult
import java.util.UUID

data class UploadedMaterial(
    val id: String,
    val title: String,
    val mimeType: String,
    val storagePath: String,
    val summary: String?
)

class LibraryUploadService(
    private val context: Context,
    private val ai: AIGatewayClient = AIGatewayClient()
) {
    fun uploadAndIndex(
        uri: Uri,
        onResult: (GatewayResult<UploadedMaterial>) -> Unit
    ) {
        if (runCatching { FirebaseApp.getInstance() }.isFailure) {
            onResult(GatewayResult.Error("Firebase is not configured."))
            return
        }

        val uid = FirebaseAuth.getInstance().currentUser?.uid
        if (uid == null) {
            onResult(GatewayResult.Error("User session is not ready."))
            return
        }

        val materialId = UUID.randomUUID().toString()
        val title = displayName(uri) ?: "Study material"
        val mimeType = context.contentResolver.getType(uri) ?: "application/octet-stream"
        val safeName = title.replace(Regex("[^A-Za-z0-9._-]"), "_").take(120)
        val path = "users/$uid/materials/$materialId/$safeName"

        val metadata = StorageMetadata.Builder()
            .setContentType(mimeType)
            .build()

        FirebaseStorage.getInstance()
            .reference
            .child(path)
            .putFile(uri, metadata)
            .addOnSuccessListener {
                ai.indexMaterial(
                    materialId = materialId,
                    title = title,
                    mimeType = mimeType,
                    storagePath = path,
                    extractedText = null
                ) { result ->
                    when (result) {
                        is GatewayResult.Success -> onResult(
                            GatewayResult.Success(
                                UploadedMaterial(
                                    id = materialId,
                                    title = title,
                                    mimeType = mimeType,
                                    storagePath = path,
                                    summary = result.value["summary"] as? String
                                )
                            )
                        )
                        is GatewayResult.Error -> onResult(result)
                    }
                }
            }
            .addOnFailureListener { error ->
                onResult(GatewayResult.Error("Upload failed.", error))
            }
    }

    private fun displayName(uri: Uri): String? =
        context.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null
        )?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0) null else cursor.getString(index)
        }
}
