package com.kprl.exam.ui.library

import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.kprl.exam.data.StudySetup
import com.kprl.exam.domain.StudyQuestion
import com.kprl.exam.platform.ai.AIGatewayClient
import com.kprl.exam.platform.ai.GatewayResult
import com.kprl.exam.platform.library.LibraryUploadService
import com.kprl.exam.ui.theme.ExamColors

private data class CloudMaterial(
    val id: String,
    val title: String,
    val mimeType: String,
    val summary: String
)

@Composable
fun LibraryScreen(
    setup: StudySetup,
    modifier: Modifier = Modifier,
    onStartPractice: (List<StudyQuestion>) -> Unit = {},
    onPaywall: (String) -> Unit = {}
) {
    val context = LocalContext.current
    val uploader = remember { LibraryUploadService(context.applicationContext) }
    val ai = remember { AIGatewayClient() }

    var loading by remember { mutableStateOf(false) }
    var listLoading by remember { mutableStateOf(false) }
    var materials by remember { mutableStateOf<List<CloudMaterial>>(emptyList()) }
    var selected by remember { mutableStateOf<CloudMaterial?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var refreshKey by remember { mutableIntStateOf(0) }

    fun loadMaterials() {
        if (runCatching { FirebaseApp.getInstance() }.isFailure) return
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        listLoading = true
        FirebaseFirestore.getInstance()
            .collection("users")
            .document(uid)
            .collection("materials")
            .get()
            .addOnSuccessListener { snapshot ->
                materials = snapshot.documents.map { doc ->
                    CloudMaterial(
                        id = doc.id,
                        title = doc.getString("title") ?: "Study material",
                        mimeType = doc.getString("mimeType") ?: "application/octet-stream",
                        summary = doc.getString("summary") ?: ""
                    )
                }.sortedBy { it.title.lowercase() }
                listLoading = false
            }
            .addOnFailureListener {
                error = it.message ?: "Could not load materials."
                listLoading = false
            }
    }

    LaunchedEffect(refreshKey) { loadMaterials() }

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
                    refreshKey++
                }
                is GatewayResult.Error -> {
                    when {
                        result.message.contains("material limit", ignoreCase = true) -> onPaywall("document_limit")
                        result.message.contains("Daily AI limit", ignoreCase = true) -> onPaywall("ai_limit")
                        else -> error = result.message
                    }
                }
            }
        }
    }

    selected?.let { material ->
        MaterialChatScreen(
            setup = setup,
            material = material,
            ai = ai,
            onBack = { selected = null },
            onQuiz = { count ->
                loading = true
                error = null
                ai.generateMaterialPractice(
                    materialId = material.id,
                    language = setup.languageCode,
                    count = count
                ) { result ->
                    loading = false
                    when (result) {
                        is GatewayResult.Success -> {
                            val questions = parseMaterialQuestions(result.value)
                            if (questions.isEmpty()) {
                                error = "Could not create a valid quiz from this material."
                            } else {
                                onStartPractice(questions)
                            }
                        }
                        is GatewayResult.Error -> {
                            if (result.message.contains("Daily AI limit", ignoreCase = true)) onPaywall("ai_limit")
                            else error = result.message
                        }
                    }
                }
            },
            globalLoading = loading,
            globalError = error
        )
        return
    }

    Column(
        modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 20.dp)
    ) {
        Spacer(Modifier.height(12.dp))
        Text("Library", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text(
            "Your PDFs, photos, audio, video and notes become searchable study context.",
            color = ExamColors.TextSecondary,
            fontSize = 13.sp
        )

        Spacer(Modifier.height(18.dp))
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
            modifier = Modifier.fillMaxWidth().height(54.dp),
            shape = RoundedCornerShape(17.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary)
        ) {
            if (loading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                    color = androidx.compose.ui.graphics.Color.White
                )
            } else {
                Icon(Icons.Rounded.Add, null)
            }
            Spacer(Modifier.width(8.dp))
            Text(if (loading) "Uploading & indexing…" else "Add material", fontWeight = FontWeight.Bold)
        }

        error?.let {
            Spacer(Modifier.height(8.dp))
            Text(it, color = ExamColors.Coral, fontSize = 12.sp)
        }

        Spacer(Modifier.height(18.dp))

        when {
            listLoading -> {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            }
            materials.isEmpty() -> {
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
                        Icon(
                            Icons.Rounded.FolderOpen,
                            null,
                            tint = ExamColors.Primary,
                            modifier = Modifier.size(34.dp)
                        )
                        Spacer(Modifier.height(12.dp))
                        Text("No indexed materials yet", fontWeight = FontWeight.Bold)
                        Text(
                            "Upload a file and exam will summarize it, answer from it and build quizzes from it.",
                            color = ExamColors.TextSecondary,
                            fontSize = 12.sp,
                            lineHeight = 18.sp
                        )
                    }
                }
            }
            else -> {
                Text("Your materials", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                LazyColumn(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(9.dp)
                ) {
                    items(materials, key = { it.id }) { material ->
                        Surface(
                            modifier = Modifier.fillMaxWidth().clickable { selected = material },
                            color = ExamColors.Surface,
                            shape = RoundedCornerShape(18.dp),
                            border = BorderStroke(1.dp, ExamColors.Border)
                        ) {
                            Row(
                                Modifier.padding(14.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    when {
                                        material.mimeType.startsWith("audio") -> Icons.Rounded.GraphicEq
                                        material.mimeType.startsWith("video") -> Icons.Rounded.Movie
                                        material.mimeType.startsWith("image") -> Icons.Rounded.Image
                                        else -> Icons.Rounded.Description
                                    },
                                    null,
                                    tint = ExamColors.Primary
                                )
                                Spacer(Modifier.width(12.dp))
                                Column(Modifier.weight(1f)) {
                                    Text(material.title, fontWeight = FontWeight.SemiBold)
                                    Text(
                                        material.summary.ifBlank { "Indexed and ready for Q&A" },
                                        color = ExamColors.TextSecondary,
                                        fontSize = 11.sp,
                                        maxLines = 2
                                    )
                                }
                                Icon(Icons.Rounded.ChevronRight, null, tint = ExamColors.TextSecondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MaterialChatScreen(
    setup: StudySetup,
    material: CloudMaterial,
    ai: AIGatewayClient,
    onBack: () -> Unit,
    onQuiz: (Int) -> Unit,
    globalLoading: Boolean,
    globalError: String?,
    onPaywall: (String) -> Unit
) {
    var question by remember(material.id) { mutableStateOf("") }
    var answer by remember(material.id) { mutableStateOf<String?>(null) }
    var asking by remember(material.id) { mutableStateOf(false) }

    Column(
        Modifier.fillMaxSize()
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) { Icon(Icons.Rounded.ArrowBack, "Back") }
            Column(Modifier.weight(1f)) {
                Text(material.title, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text("Answers are grounded in this material", color = ExamColors.Mint, fontSize = 11.sp)
            }
        }

        if (material.summary.isNotBlank()) {
            Spacer(Modifier.height(10.dp))
            Surface(
                color = ExamColors.Surface,
                shape = RoundedCornerShape(18.dp),
                border = BorderStroke(1.dp, ExamColors.Border)
            ) {
                Column(Modifier.padding(14.dp)) {
                    Text("Summary", fontWeight = FontWeight.Bold)
                    Text(
                        material.summary,
                        color = ExamColors.TextSecondary,
                        fontSize = 12.sp,
                        lineHeight = 18.sp,
                        maxLines = 8
                    )
                }
            }
        }

        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = { onQuiz(5) },
                enabled = !globalLoading,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary)
            ) {
                Icon(Icons.Rounded.Quiz, null)
                Spacer(Modifier.width(6.dp))
                Text("Quiz me")
            }
            OutlinedButton(
                onClick = { onQuiz(10) },
                enabled = !globalLoading,
                modifier = Modifier.weight(1f)
            ) {
                Text("10 questions")
            }
        }

        globalError?.let {
            Spacer(Modifier.height(8.dp))
            Text(it, color = ExamColors.Coral, fontSize = 12.sp)
        }

        answer?.let {
            Spacer(Modifier.height(14.dp))
            Surface(
                color = ExamColors.Surface,
                shape = RoundedCornerShape(18.dp),
                border = BorderStroke(1.dp, ExamColors.Border)
            ) {
                Column(Modifier.padding(14.dp)) {
                    Text("AI Tutor", color = ExamColors.Purple, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                    Spacer(Modifier.height(5.dp))
                    Text(it, fontSize = 13.sp, lineHeight = 19.sp)
                }
            }
        }

        Spacer(Modifier.weight(1f))

        OutlinedTextField(
            value = question,
            onValueChange = { question = it },
            modifier = Modifier.fillMaxWidth(),
            placeholder = { Text("Ask this material…") },
            maxLines = 4,
            trailingIcon = {
                IconButton(
                    onClick = {
                        val value = question.trim()
                        if (value.isEmpty() || asking) return@IconButton
                        asking = true
                        ai.askMaterial(material.id, value, setup.languageCode) { result ->
                            asking = false
                            answer = when (result) {
                                is GatewayResult.Success -> result.value
                                is GatewayResult.Error -> {
                                    if (result.message.contains("Daily AI limit", ignoreCase = true)) {
                                        onPaywall("ai_limit")
                                        ""
                                    } else result.message
                                }
                            }
                        }
                    },
                    enabled = question.isNotBlank() && !asking
                ) {
                    if (asking) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                    else Icon(Icons.Rounded.ArrowUpward, "Send")
                }
            },
            shape = RoundedCornerShape(18.dp)
        )
        Spacer(Modifier.height(12.dp))
    }
}

private fun parseMaterialQuestions(payload: Map<*, *>): List<StudyQuestion> {
    val rows = payload["questions"] as? List<*> ?: return emptyList()
    return rows.mapNotNull { raw ->
        val item = raw as? Map<*, *> ?: return@mapNotNull null
        val prompt = item["prompt"] as? String ?: return@mapNotNull null
        val options = (item["options"] as? List<*>)?.mapNotNull { it as? String }.orEmpty()
        val correct = (item["correctIndex"] as? Number)?.toInt() ?: return@mapNotNull null
        if (options.size < 2 || correct !in options.indices) return@mapNotNull null
        StudyQuestion(
            id = item["id"] as? String ?: "material_${prompt.hashCode()}",
            topic = item["topic"] as? String ?: "Material",
            prompt = prompt,
            options = options,
            correctIndex = correct,
            explanation = item["explanation"] as? String ?: "Based on your study material."
        )
    }
}
