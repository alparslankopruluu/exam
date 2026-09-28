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
import com.kprl.exam.billing.OfferPresentation
import com.kprl.exam.billing.OfferService
import kotlinx.coroutines.delay
import com.kprl.exam.analytics.AnalyticsEvents
import com.kprl.exam.analytics.AnalyticsParams
import com.kprl.exam.platform.AppServices
import com.kprl.exam.billing.StoreOfferPresentation
import com.kprl.exam.billing.StorePlanPresentation
import com.kprl.exam.data.StudySetup
import com.kprl.exam.localization.LocalizedCopy
import com.kprl.exam.ui.theme.ExamColors

@Composable
fun PremiumPaywallScreen(
    setup: StudySetup,
    placement: String,
    onClose: () -> Unit
) {
    val context = LocalContext.current
    val activity = remember(context) { context.findActivity() }
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    val billing = remember { GooglePlayBillingService(context.applicationContext) }

    var offer by remember { mutableStateOf(StoreOfferPresentation()) }
    var special by remember { mutableStateOf<OfferPresentation?>(null) }
    var selection by remember { mutableStateOf(PlanChoice.ANNUAL) }
    var purchasing by remember { mutableStateOf(false) }
    var purchaseError by remember { mutableStateOf<String?>(null) }

    DisposableEffect(billing) {
        billing.start {
            billing.loadOffer { loaded ->
                offer = loaded
                OfferService.fetch { active ->
                    val presented = active?.let(billing::present) ?: return@fetch
                    special = presented
                    selection = PlanChoice.SPECIAL
                    AppServices.analytics.event(
                        "offer_viewed",
                        mapOf(AnalyticsParams.PLACEMENT to placement, "offer_kind" to presented.offer.kind)
                    )
                }
            }
        }
        onDispose { billing.close() }
    }

    val selectedProductId = when (selection) {
        PlanChoice.SPECIAL -> special?.offer?.productId ?: offer.annual.productId
        PlanChoice.ANNUAL -> offer.annual.productId
        PlanChoice.MONTHLY -> offer.monthly.productId
    }
    val selectedPrice = when (selection) {
        PlanChoice.SPECIAL -> special?.localizedPrice
        PlanChoice.ANNUAL -> offer.annual.localizedPrice
        PlanChoice.MONTHLY -> offer.monthly.localizedPrice
    }

    LaunchedEffect(placement) {
        AppServices.analytics.event(
            AnalyticsEvents.PAYWALL_VIEWED,
            mapOf(
                AnalyticsParams.PLACEMENT to placement,
                AnalyticsParams.EXAM_ID to setup.exam.id,
                AnalyticsParams.CONTENT_PACK_ID to setup.exam.syllabusPackId
            )
        )
    }

    Column(
        Modifier.fillMaxSize()
            .background(ExamColors.Background)
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Spacer(Modifier.weight(1f))
            IconButton(onClick = {
                AppServices.analytics.event(
                    AnalyticsEvents.PAYWALL_CLOSED,
                    mapOf(AnalyticsParams.PLACEMENT to placement)
                )
                onClose()
            }) {
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
                        "voice_tutor" -> copy.text("paywall_voice_title")
                        "mock_analysis" -> copy.text("paywall_mock_title")
                        "document_limit" -> copy.text("paywall_documents_title")
                        "ai_limit" -> copy.text("paywall_ai_title")
                        else -> copy.text("paywall_title")
                    },
                    color = Color.White,
                    fontSize = 28.sp,
                    lineHeight = 32.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    copy.text("paywall_subtitle"),
                    color = Color.White.copy(alpha = .82f),
                    fontSize = 14.sp,
                    lineHeight = 20.sp
                )
            }
        }

        Spacer(Modifier.height(20.dp))
        Benefit(Icons.Rounded.AutoAwesome, copy.text("advanced_ai_tutor"), copy.text("advanced_ai_tutor_hint"))
        Benefit(Icons.Rounded.GraphicEq, copy.text("voice_tutor"), copy.text("voice_tutor_hint"))
        Benefit(Icons.Rounded.FolderOpen, copy.text("unlimited_materials"), copy.text("unlimited_materials_hint"))
        Benefit(Icons.Rounded.Bolt, copy.text("quick_practice"), copy.text("quick_practice_hint"))

        Spacer(Modifier.height(18.dp))
        special?.let { presented ->
            SpecialOfferCard(presented, copy, selection == PlanChoice.SPECIAL) { selection = PlanChoice.SPECIAL }
            Spacer(Modifier.height(9.dp))
        }
        PlanCard(offer.annual, copy.text("annual"), copy.text("best_value"), copy.text("paywall_trial_available"), selection == PlanChoice.ANNUAL) {
            selection = PlanChoice.ANNUAL
            AppServices.analytics.event(
                AnalyticsEvents.PLAN_SELECTED,
                mapOf(AnalyticsParams.PRODUCT_ID to offer.annual.productId)
            )
        }
        Spacer(Modifier.height(9.dp))
        PlanCard(offer.monthly, copy.text("monthly"), copy.text("best_value"), copy.text("paywall_trial_available"), selection == PlanChoice.MONTHLY) {
            selection = PlanChoice.MONTHLY
            AppServices.analytics.event(
                AnalyticsEvents.PLAN_SELECTED,
                mapOf(AnalyticsParams.PRODUCT_ID to offer.monthly.productId)
            )
        }

        Spacer(Modifier.weight(1f))
        Button(
            onClick = {
                val host = activity
                if (host == null) {
                    purchaseError = copy.text("purchase_not_completed")
                    return@Button
                }
                purchasing = true
                purchaseError = null
                val offerTag = if (selection == PlanChoice.SPECIAL) special?.offer?.googleOfferTag else null
                billing.purchase(host, selectedProductId, offerTag) { success, message ->
                    purchasing = false
                    if (success) {
                        AppServices.analytics.event(
                            AnalyticsEvents.PURCHASE_COMPLETED,
                            mapOf(
                                AnalyticsParams.PLACEMENT to placement,
                                AnalyticsParams.PRODUCT_ID to selectedProductId
                            )
                        )
                        onClose()
                    } else if (message != "cancelled") {
                        purchaseError = message ?: copy.text("purchase_not_completed")
                        AppServices.analytics.event(
                            AnalyticsEvents.PURCHASE_FAILED,
                            mapOf(
                                AnalyticsParams.PLACEMENT to placement,
                                AnalyticsParams.PRODUCT_ID to selectedProductId
                            )
                        )
                    }
                }
            },
            enabled = selectedPrice != null && !purchasing,
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
                    purchasing -> copy.text("processing")
                    selectedPrice != null -> copy.text(
                        "continue_price",
                        mapOf("price" to selectedPrice)
                    )
                    else -> copy.text("loading_price")
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
            copy.text("price_terms"),
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
private fun PlanCard(
    plan: StorePlanPresentation,
    displayTitle: String,
    recommendedLabel: String,
    trialLabel: String,
    selected: Boolean,
    onClick: () -> Unit
) {
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
                    Text(displayTitle, fontWeight = FontWeight.Bold)
                    if (plan.recommended) {
                        Spacer(Modifier.width(7.dp))
                        Text(
                            recommendedLabel,
                            color = ExamColors.Primary,
                            fontSize = 9.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.background(ExamColors.SoftBlue, RoundedCornerShape(50)).padding(horizontal = 7.dp, vertical = 4.dp)
                        )
                    }
                }
                if (plan.hasTrial) {
                    Text(trialLabel, color = ExamColors.TextSecondary, fontSize = 11.sp)
                }
            }
            Text(plan.localizedPrice ?: "—", color = ExamColors.TextPrimary, fontWeight = FontWeight.SemiBold)
        }
    }
}

private enum class PlanChoice { SPECIAL, ANNUAL, MONTHLY }

@Composable
private fun SpecialOfferCard(
    presented: OfferPresentation,
    copy: LocalizedCopy,
    selected: Boolean,
    onClick: () -> Unit
) {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(presented.offer.expiresAtMillis) {
        while (now < presented.offer.expiresAtMillis) {
            delay(1_000)
            now = System.currentTimeMillis()
        }
    }

    Surface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        color = ExamColors.Surface,
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(if (selected) 1.5.dp else 1.dp, if (selected) ExamColors.Coral else ExamColors.Border)
    ) {
        Column(Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    copy.text("offer_badge", mapOf("percent" to presented.offer.discountPercent.toString())),
                    color = Color.White,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.background(ExamColors.Coral, RoundedCornerShape(50)).padding(horizontal = 9.dp, vertical = 5.dp)
                )
                Spacer(Modifier.weight(1f))
                Text(countdown(presented.offer.expiresAtMillis - now), color = ExamColors.Coral, fontWeight = FontWeight.Bold, fontSize = 13.sp)
            }
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.size(22.dp).background(if (selected) ExamColors.Primary else ExamColors.Background, RoundedCornerShape(50)),
                    contentAlignment = Alignment.Center
                ) {
                    if (selected) Text("✓", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                }
                Spacer(Modifier.width(11.dp))
                Column(Modifier.weight(1f)) {
                    Text(copy.text("offer_title_${presented.offer.kind}"), fontWeight = FontWeight.Bold)
                    Text(copy.text("offer_first_year"), color = ExamColors.TextSecondary, fontSize = 11.sp)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text(presented.localizedPrice, fontWeight = FontWeight.Bold)
                    Text(
                        presented.regularPrice,
                        color = ExamColors.TextSecondary,
                        fontSize = 11.sp,
                        textDecoration = androidx.compose.ui.text.style.TextDecoration.LineThrough
                    )
                }
            }
        }
    }
}

private fun countdown(remainingMillis: Long): String {
    val seconds = (remainingMillis / 1000).coerceAtLeast(0)
    val days = seconds / 86_400
    val clock = "%02d:%02d:%02d".format((seconds % 86_400) / 3600, (seconds % 3600) / 60, seconds % 60)
    return if (days > 0) "${days}d $clock" else clock
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
