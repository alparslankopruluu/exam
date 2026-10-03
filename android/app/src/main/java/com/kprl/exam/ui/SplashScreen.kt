package com.kprl.exam.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.R
import com.kprl.exam.localization.LocalizedCopy
import com.kprl.exam.ui.theme.ExamColors

/** Brand splash: mark, wordmark, tagline and the student illustration (mirrors iOS SplashView). */
@Composable
fun SplashScreen(languageCode: String, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val copy = remember(languageCode) { LocalizedCopy.load(context, languageCode) }
    var appeared by remember { mutableStateOf(false) }
    val reveal by animateFloatAsState(if (appeared) 1f else 0f, spring(dampingRatio = 0.8f, stiffness = 120f), label = "splash")
    LaunchedEffect(Unit) { appeared = true }

    Column(
        Modifier.fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFFEDEFFF), ExamColors.Background)))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onDismiss)
            .statusBarsPadding().navigationBarsPadding().padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.weight(0.6f))
        Image(
            painterResource(R.drawable.illu_app_mark), null,
            modifier = Modifier.size(72.dp).shadow(14.dp, RoundedCornerShape(17.dp)).clip(RoundedCornerShape(17.dp))
        )
        Text(
            "Examly",
            fontSize = 46.sp,
            fontWeight = FontWeight.Bold,
            color = Color(0xFF1C2440),
            modifier = Modifier.padding(top = 14.dp)
        )
        Text(
            copy.text("splash_tagline"),
            fontSize = 17.sp,
            fontWeight = FontWeight.Medium,
            color = ExamColors.TextSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 6.dp)
        )
        Spacer(Modifier.weight(0.4f))
        Image(
            painterResource(R.drawable.illu_hero_student), null,
            contentScale = ContentScale.Fit,
            modifier = Modifier.heightIn(max = 380.dp).graphicsLayer {
                alpha = reveal
                translationY = (1f - reveal) * 24.dp.toPx()
            }
        )
        Text(
            copy.text("splash_footer"),
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = ExamColors.TextSecondary,
            modifier = Modifier.padding(vertical = 18.dp)
        )
    }
}
