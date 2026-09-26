package com.kprl.exam.ui.paywall

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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import com.kprl.exam.billing.GooglePlayBillingService
import com.kprl.exam.billing.StoreOfferPresentation
import com.kprl.exam.billing.StorePlanPresentation
import com.kprl.exam.data.StudySetup
import com.kprl.exam.ui.theme.ExamColors

@Composable
fun PremiumPaywallScreen(
    setup: StudySetup,
    placement: String,
    onClose: () -> Unit
) {
    val context = LocalContext.current
    val activity = remember(context) { context.findActivity() }
    val billing = remember { GooglePlayBillingService(context.applicationContext) }

    var offer by remember { mutableStateOf(StoreOfferPresentation()) }
    var annualSelected by remember { mutableStateOf(true) }
    var purchasing by remember { mutableStateOf(false) }
    var purchaseError by remember { mutableStateOf<String?>(null) }

    DisposableEffect(billing) {
        billing.start {
            billing.loadOffer { loaded -> offer = loaded }
        }
        onDispose { billing.close() }
    }

    val selectedPlan = if (annualSelected) offer.annual else offer.monthly

    Column(
        Modifier.fillMaxSize()
            .background(ExamColors.Background)
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Spacer(Modifier.weight(1f))
            IconButton(onClick = onClose) {
                Icon(Icons.Rounded.Close, contentDescription = "Close", tint = ExamColors.TextSecondary)
            }
        }

        Box(
            Modifier.fillMaxWidth()
                .background(
                    Brush.linearGradient(listOf(ExamColors.Primary, ExamColors.Indigo)),
                    RoundedCornerShape(28.dp)
                )
                .padding(22.dp)
        ) {
            Column {
                Surface(
                    color = Color.White.copy(alpha = .16f),
                    shape = RoundedCornerShape(50)
                ) {
                    Text(
                        setup.exam.shortName,
                        color = Color.White,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                    )
                }

                Spacer(Modifier.height(20.dp))
                Text(
                    when (placement) {
                        "voice_tutor" -> "Talk it through until it clicks."
                        "mock_analysis" -> "Turn every mock exam into a better next week."
                        "document_limit" -> "Turn all your material into study sessions."
                        else -> "Keep your full personalized plan."
                    },
                    color = Color.White,
                    fontSize = 28.sp,
                    lineHeight = 32.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    "Premium keeps your ${setup.exam.shortName} plan adaptive across practice, tutoring and review.",
                    color = Color.White.copy(alpha = .82f),
                    fontSize = 14.sp,
                    lineHeight = 20.sp
                )
            }
        }

        Spacer(Modifier.height(20.dp))
        Benefit(Icons.Rounded.AutoAwesome, "Advanced AI Tutor", "Ask follow-ups until you understand.")
        Benefit(Icons.Rounded.GraphicEq, "Voice Tutor", "Interactive speaking and spoken explanations.")
        Benefit(Icons.Rounded.FolderOpen, "Unlimited study materials", "Turn notes and documents into practice.")
        Benefit(Icons.Rounded.Insights, "Advanced progress", "See mastery and mistake patterns over time.")

        Spacer(Modifier.height(18.dp))
        PlanCard(offer.annual, annualSelected) { annualSelected = true }
        Spacer(Modifier.height(9.dp))
        PlanCard(offer.monthly, !annualSelected) { annualSelected = false }

        Spacer(Modifier.weight(1f))
        Button(
            onClick = {
                val host = activity
                if (host == null) {
                    purchaseError = "Purchase screen is unavailable."
                    return@Button
                }
                purchasing = true
                purchaseError = null
                billing.purchase(host, selectedPlan.productId) { success, message ->
                    purchasing = false
                    if (success) onClose()
                    else if (message != "cancelled") purchaseError = message ?: "Purchase failed."
                }
            },
            enabled = selectedPlan.localizedPrice != null && !purchasing,
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = ExamColors.Primary,
                disabledContainerColor = ExamColors.Border
            ),
            elevation = ButtonDefaults.buttonElevation(0.dp)
        ) {
            Text(
                when {
                    purchasing -> "Processing…"
                    selectedPlan.localizedPrice != null -> "Continue · " + selectedPlan.localizedPrice
                    else -> "Loading local price…"
                },
                fontWeight = FontWeight.Bold
            )
        }
        purchaseError?.let {
            Spacer(Modifier.height(7.dp))
            Text(it, color = ExamColors.Coral, fontSize = 11.sp)
        }
        Spacer(Modifier.height(8.dp))
        Text(
            "Price, trial eligibility and renewal terms come directly from Google Play for your account and region.",
            color = ExamColors.TextSecondary,
            fontSize = 10.sp,
            lineHeight = 14.sp,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(10.dp))
    }
}

@Composable
private fun Benefit(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, subtitle: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 7.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier.size(38.dp).background(ExamColors.SoftBlue, RoundedCornerShape(12.dp)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = ExamColors.Primary, modifier = Modifier.size(19.dp))
        }
        Spacer(Modifier.width(11.dp))
        Column {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            Text(subtitle, color = ExamColors.TextSecondary, fontSize = 11.sp)
        }
    }
}

@Composable
private fun PlanCard(plan: StorePlanPresentation, selected: Boolean, onClick: () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        color = ExamColors.Surface,
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(if (selected) 1.5.dp else 1.dp, if (selected) ExamColors.Primary else ExamColors.Border)
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(22.dp).background(
                    if (selected) ExamColors.Primary else ExamColors.Background,
                    RoundedCornerShape(50)
                ),
                contentAlignment = Alignment.Center
            ) {
                if (selected) Text("✓", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            }
            Spacer(Modifier.width(11.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(plan.title, fontWeight = FontWeight.Bold)
                    if (plan.recommended) {
                        Spacer(Modifier.width(7.dp))
                        Text(
                            "BEST VALUE",
                            color = ExamColors.Primary,
                            fontSize = 9.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.background(ExamColors.SoftBlue, RoundedCornerShape(50)).padding(horizontal = 7.dp, vertical = 4.dp)
                        )
                    }
                }
                plan.trialText?.let {
                    Text(it, color = ExamColors.TextSecondary, fontSize = 11.sp)
                }
            }
            Text(plan.localizedPrice ?: "—", color = ExamColors.TextPrimary, fontWeight = FontWeight.SemiBold)
        }
    }
}


private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
