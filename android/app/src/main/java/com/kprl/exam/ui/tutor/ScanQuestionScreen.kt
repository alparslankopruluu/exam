package com.kprl.exam.ui.tutor

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Matrix
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.view.LifecycleCameraController
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.kprl.exam.localization.LocalizedCopy
import com.kprl.exam.ui.theme.ExamColors

/** "Scan a question": live camera with a framing guide, a Scan/Gallery switch and a shutter (mirrors iOS). */
@Composable
fun ScanQuestionScreen(copy: LocalizedCopy, onClose: () -> Unit, onGallery: () -> Unit, onImage: (Bitmap) -> Unit) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var authorized by remember {
        mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED)
    }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { authorized = it }
    LaunchedEffect(Unit) { if (!authorized) permission.launch(Manifest.permission.CAMERA) }

    val controller = remember {
        LifecycleCameraController(context).apply {
            cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
            setEnabledUseCases(LifecycleCameraController.IMAGE_CAPTURE)
        }
    }
    LaunchedEffect(authorized) { if (authorized) controller.bindToLifecycle(lifecycleOwner) }

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        if (authorized) {
            AndroidView(
                factory = { PreviewView(it).apply { this.controller = controller; scaleType = PreviewView.ScaleType.FILL_CENTER } },
                modifier = Modifier.fillMaxSize()
            )
        }
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.size(38.dp).background(Color.White.copy(alpha = 0.18f), CircleShape).clickable(onClick = onClose),
                    contentAlignment = Alignment.Center
                ) { Icon(Icons.Rounded.Close, null, tint = Color.White) }
                Spacer(Modifier.width(12.dp))
                Text(copy.text("scan_title"), color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.weight(1f))
            ScanFrame(Modifier.align(Alignment.CenterHorizontally).size(290.dp, 220.dp))
            Text(
                copy.text(if (authorized) "scan_hint" else "scan_camera_denied"),
                color = Color.White.copy(alpha = 0.85f),
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 32.dp, vertical = 18.dp)
            )
            Spacer(Modifier.weight(1f))
            Column(
                Modifier.fillMaxWidth().background(Color.Black.copy(alpha = 0.55f)).navigationBarsPadding().padding(vertical = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(22.dp)
            ) {
                Row(Modifier.background(Color.White.copy(alpha = 0.14f), CircleShape).padding(4.dp)) {
                    ModeChip(copy.text("scan_mode"), selected = true) {}
                    ModeChip(copy.text("gallery"), selected = false, onClick = onGallery)
                }
                Box(
                    Modifier.size(76.dp).border(4.dp, Color.White.copy(alpha = if (authorized) 1f else 0.4f), CircleShape).padding(8.dp)
                        .background(Color.White.copy(alpha = if (authorized) 1f else 0.4f), CircleShape)
                        .clickable(enabled = authorized) {
                            controller.takePicture(
                                ContextCompat.getMainExecutor(context),
                                object : ImageCapture.OnImageCapturedCallback() {
                                    override fun onCaptureSuccess(image: ImageProxy) {
                                        val rotation = image.imageInfo.rotationDegrees
                                        val bitmap = image.toBitmap()
                                        image.close()
                                        onImage(
                                            if (rotation == 0) bitmap
                                            else Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, Matrix().apply { postRotate(rotation.toFloat()) }, true)
                                        )
                                    }

                                    override fun onError(exception: ImageCaptureException) = Unit
                                }
                            )
                        }
                )
            }
        }
    }
}

@Composable
private fun ModeChip(title: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        Modifier.size(104.dp, 36.dp).background(if (selected) Color.White else Color.Transparent, CircleShape).clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = if (selected) ExamColors.TextPrimary else Color.White)
    }
}

/** Four rounded corner brackets marking where the question should sit. */
@Composable
private fun ScanFrame(modifier: Modifier) {
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        val arm = 34.dp.toPx()
        val r = 18.dp.toPx()
        val path = Path().apply {
            moveTo(0f, arm); lineTo(0f, r); quadraticTo(0f, 0f, r, 0f); lineTo(arm, 0f)
            moveTo(w - arm, 0f); lineTo(w - r, 0f); quadraticTo(w, 0f, w, r); lineTo(w, arm)
            moveTo(w, h - arm); lineTo(w, h - r); quadraticTo(w, h, w - r, h); lineTo(w - arm, h)
            moveTo(arm, h); lineTo(r, h); quadraticTo(0f, h, 0f, h - r); lineTo(0f, h - arm)
        }
        drawPath(path, Color.White, style = Stroke(5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}
