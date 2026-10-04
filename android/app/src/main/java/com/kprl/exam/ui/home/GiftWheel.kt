package com.kprl.exam.ui.home

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.CardGiftcard
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.billing.OfferService
import com.kprl.exam.billing.WheelResult
import com.kprl.exam.localization.LocalizedCopy
import com.kprl.exam.platform.AppServices
import com.kprl.exam.ui.theme.ExamColors
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

/** Wheel segments, clockwise from 12 o'clock; must match backend/functions/src/wheel.ts. */
private val wheelSegments = listOf("credits10", "annual40", "credits5", "credits25", "annual40", "credits5", "credits10", "annual40")

private val wheelColors = listOf(
    Color(0xFF3B6BF5), Color(0xFF8C5CF5), Color(0xFF2BCC8C), Color(0xFFF5A624),
    Color(0xFF5C5CF5), Color(0xFF21B8CF), Color(0xFF4F8CFF), Color(0xFFED70A1)
)

private val NightTop = Color(0xFF293361)
private val NightBottom = Color(0xFF12172E)
private val Rim = Color(0xFF1C2440)
private val BulbOn = Color(0xFFFFED9E)
private val SpinStart = Color(0xFFFFB840)
private val SpinEnd = Color(0xFFF57359)
private val SliceDeg = 360f / wheelSegments.size

/** Quartic ease-out, like the iOS landing curve. */
private val LandingEasing = CubicBezierEasing(0.25f, 1f, 0.5f, 1f)

private fun segmentUnderPointer(angle: Float): Int {
    val normalized = ((angle % 360f) + 360f) % 360f
    return (((360f - normalized) % 360f) / SliceDeg).toInt()
}

/** The wheel face: slices with prize labels, a glowing rim and blinking bulbs. */
@Composable
private fun WheelFace(copy: LocalizedCopy, modifier: Modifier = Modifier, bulbs: Boolean = true) {
    val measurer = rememberTextMeasurer()
    val creditsLabel = copy.text("credits_short")
    val blink = rememberInfiniteTransition(label = "bulbs")
    val phase by blink.animateFloat(
        0f, 2f,
        infiniteRepeatable(tween(900, easing = LinearEasing), RepeatMode.Restart),
        label = "phase"
    )
    Canvas(modifier.aspectRatio(1f)) {
        val size = this.size.minDimension
        val center = Offset(size / 2, size / 2)
        val radius = size / 2 - size * 0.06f
        drawCircle(Brush.sweepGradient(listOf(Color(0xFFBAC7FF), Color(0xFF7385F2), Color(0xFFBAC7FF)), center), size / 2, center)
        drawCircle(Rim, size / 2 - size * 0.045f, center)

        wheelSegments.forEachIndexed { index, prize ->
            val start = index * SliceDeg - 90f
            val color = wheelColors[index % wheelColors.size]
            drawArc(
                Brush.verticalGradient(listOf(color.copy(alpha = 0.85f), color)),
                start, SliceDeg, true,
                topLeft = Offset(center.x - radius, center.y - radius), size = Size(radius * 2, radius * 2)
            )
            drawArc(
                Rim, start, SliceDeg, true,
                topLeft = Offset(center.x - radius, center.y - radius), size = Size(radius * 2, radius * 2),
                style = Stroke(width = 2.dp.toPx())
            )
            val isOffer = prize == "annual40"
            val big = if (isOffer) "-40%" else "+" + prize.removePrefix("credits")
            val small = if (isOffer) "Premium" else creditsLabel
            rotate(index * SliceDeg + SliceDeg / 2, center) {
                val bigLayout = measurer.measure(big, TextStyle(color = Color.White, fontSize = (size * 0.07f).toSp(), fontWeight = FontWeight.Black))
                val smallLayout = measurer.measure(small, TextStyle(color = Color.White.copy(alpha = 0.9f), fontSize = (size * 0.033f).toSp(), fontWeight = FontWeight.Bold))
                val y = center.y - radius * 0.62f
                val total = bigLayout.size.height + smallLayout.size.height
                drawText(bigLayout, topLeft = Offset(center.x - bigLayout.size.width / 2, y - total / 2))
                drawText(smallLayout, topLeft = Offset(center.x - smallLayout.size.width / 2, y - total / 2 + bigLayout.size.height))
            }
        }

        if (bulbs) {
            val tick = phase.toInt()
            for (i in 0 until 24) {
                val lit = (i + tick) % 2 == 0
                val a = Math.toRadians((i * 15.0) - 90)
                val r = size / 2 - size * 0.024f
                val p = Offset(center.x + (cos(a) * r).toFloat(), center.y + (sin(a) * r).toFloat())
                if (lit) drawCircle(BulbOn.copy(alpha = 0.35f), size * 0.026f, p)
                drawCircle(if (lit) BulbOn else Color.White.copy(alpha = 0.35f), size * 0.013f, p)
            }
        }
        drawCircle(Color.Black.copy(alpha = 0.18f), size * 0.105f, center.copy(y = center.y + 3.dp.toPx()))
        drawCircle(Color.White, size * 0.1f, center)
    }
}

/** A one-shot confetti burst. */
@Composable
private fun ConfettiBurst(modifier: Modifier = Modifier) {
    data class Piece(val angle: Float, val speed: Float, val spin: Float, val color: Color, val size: Float)
    val pieces = remember {
        List(70) {
            Piece(Random.nextFloat() * 6.283f, 180f + Random.nextFloat() * 240f, Random.nextFloat() * 12f - 6f,
                wheelColors.random(), 6f + Random.nextFloat() * 5f)
        }
    }
    var t by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (t < 2.6f) {
            withFrameNanos { t = (it - start) / 1_000_000_000f }
        }
    }
    Canvas(modifier) {
        if (t >= 2.6f) return@Canvas
        val density = this.density
        val origin = Offset(size.width / 2, size.height * 0.4f)
        val alpha = (1f - t / 2.6f).coerceIn(0f, 1f)
        pieces.forEach { p ->
            val x = origin.x + cos(p.angle) * p.speed * t * density
            val y = origin.y + (sin(p.angle) * p.speed * t + 260f * t * t) * density
            translate(x, y) {
                rotate(Math.toDegrees((p.spin * t).toDouble()).toFloat(), Offset.Zero) {
                    val w = p.size * density
                    drawRect(p.color.copy(alpha = alpha), Offset(-w / 2, -w / 4), Size(w, w / 2))
                }
            }
        }
    }
}

/** Full-screen daily gift wheel. The server draws the prize; the wheel only animates to it. */
@Composable
fun GiftWheelScreen(
    copy: LocalizedCopy,
    onClose: () -> Unit,
    onClaimOffer: () -> Unit,
    onCreditsWon: () -> Unit
) {
    val context = LocalContext.current
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val angle = remember { Animatable(-SliceDeg / 2) }
    val pointerKick = remember { Animatable(0f) }
    var spinning by remember { mutableStateOf(false) }
    var result by remember { mutableStateOf<WheelResult?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var spunToday by remember { mutableStateOf(OfferService.spunToday(context)) }

    // Pointer kick plus a haptic tick each time a segment boundary passes the pointer.
    LaunchedEffect(Unit) {
        snapshotFlow { segmentUnderPointer(angle.value) }
            .distinctUntilChanged()
            .collect {
                if (!spinning) return@collect
                haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                launch {
                    pointerKick.snapTo(-16f)
                    pointerKick.animateTo(0f, spring(dampingRatio = 0.35f, stiffness = Spring.StiffnessHigh))
                }
            }
    }

    fun land(segment: Int, onDone: () -> Unit) {
        scope.launch {
            val target = 360f - (segment * SliceDeg + SliceDeg / 2) + (Random.nextFloat() - 0.5f) * SliceDeg * 0.6f
            val current = ((angle.value % 360f) + 360f) % 360f
            var delta = target - current
            while (delta < 0) delta += 360f
            angle.animateTo(angle.value + delta + 5 * 360f, tween(5200, easing = LandingEasing))
            onDone()
        }
    }

    fun spin() {
        if (spinning || spunToday) return
        spinning = true
        error = null
        // Wind up: accelerate, then keep spinning until the prize arrives.
        val windUp: Job = scope.launch {
            angle.animateTo(angle.value + 288f, tween(800, easing = CubicBezierEasing(0.5f, 0f, 1f, 1f)))
            while (true) angle.animateTo(angle.value + 720f, tween(1000, easing = LinearEasing))
        }
        OfferService.spinWheel(context) { outcome ->
            windUp.cancel()
            outcome.onSuccess { won ->
                land(won.segment) {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    result = won
                    spinning = false
                    spunToday = true
                    AppServices.analytics.event("wheel_spun", mapOf("prize" to won.prize))
                }
            }.onFailure { failure ->
                land(0) { spinning = false }
                if (OfferService.isAlreadySpun(failure)) spunToday = true else error = copy.text("wheel_error")
            }
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(NightTop, NightBottom)))
            .background(Brush.radialGradient(listOf(ExamColors.Indigo.copy(alpha = 0.45f), Color.Transparent), radius = 900f))
    ) {
        Column(
            Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(horizontal = 22.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                Box(
                    Modifier.size(40.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.12f))
                        .clickable(enabled = !spinning, onClick = onClose),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Rounded.Close, null, tint = Color.White.copy(alpha = 0.85f), modifier = Modifier.size(20.dp))
                }
            }
            Text(copy.text("gift_wheel_title"), color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Black, textAlign = TextAlign.Center)
            Text(
                copy.text("gift_wheel_subtitle"), color = Color.White.copy(alpha = 0.75f), fontSize = 15.sp,
                textAlign = TextAlign.Center, modifier = Modifier.padding(top = 6.dp, start = 12.dp, end = 12.dp)
            )
            Spacer(Modifier.weight(1f))
            Box(contentAlignment = Alignment.TopCenter) {
                Box(contentAlignment = Alignment.Center) {
                    WheelFace(copy, Modifier.widthIn(max = 420.dp).fillMaxWidth().rotate(angle.value))
                    Icon(Icons.Rounded.CardGiftcard, null, tint = ExamColors.Indigo, modifier = Modifier.size(34.dp))
                }
                Canvas(
                    Modifier.size(40.dp, 36.dp).offset(y = (-14).dp)
                        .graphicsLayer {
                            rotationZ = pointerKick.value
                            transformOrigin = TransformOrigin(0.5f, 0f)
                        }
                ) {
                    val path = Path().apply {
                        moveTo(0f, 0f); lineTo(size.width, 0f); lineTo(size.width / 2, size.height); close()
                    }
                    drawPath(path, Brush.verticalGradient(listOf(Color.White, Color(0xFFD9E0FF))))
                }
            }
            Spacer(Modifier.weight(1f))
            error?.let {
                Text(it, color = ExamColors.Coral, fontSize = 13.sp, textAlign = TextAlign.Center, modifier = Modifier.padding(bottom = 8.dp))
            }
            val dimmed = spinning || spunToday
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(58.dp)
                    .shadow(if (spunToday) 0.dp else 14.dp, RoundedCornerShape(20.dp), ambientColor = SpinEnd, spotColor = SpinEnd)
                    .clip(RoundedCornerShape(20.dp))
                    .background(Brush.horizontalGradient(listOf(SpinStart, SpinEnd)), alpha = if (dimmed) 0.45f else 1f)
                    .clickable(enabled = !dimmed) { spin() },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    copy.text(if (spunToday && result == null) "wheel_come_back" else "spin"),
                    color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Black
                )
            }
            Spacer(Modifier.height(16.dp))
        }

        result?.let { won ->
            ConfettiBurst(Modifier.fillMaxSize())
            WheelResultCard(copy, won, onClaimOffer, onCreditsWon, Modifier.align(Alignment.Center))
        }
    }
}

@Composable
private fun WheelResultCard(
    copy: LocalizedCopy,
    won: WheelResult,
    onClaimOffer: () -> Unit,
    onCreditsWon: () -> Unit,
    modifier: Modifier
) {
    val isOffer = won.credits == 0
    val pop = remember { Animatable(0.8f) }
    LaunchedEffect(Unit) { pop.animateTo(1f, spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessMediumLow)) }
    Column(
        modifier
            .padding(horizontal = 28.dp)
            .scale(pop.value)
            .shadow(30.dp, RoundedCornerShape(28.dp))
            .clip(RoundedCornerShape(28.dp))
            .background(ExamColors.Surface)
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text(if (isOffer) "🎉" else "⚡️", fontSize = 52.sp)
        Text(
            if (isOffer) copy.text("wheel_won_offer", mapOf("percent" to "40"))
            else copy.text("wheel_won_credits", mapOf("count" to won.credits.toString())),
            color = ExamColors.TextPrimary, fontSize = 24.sp, fontWeight = FontWeight.Black, textAlign = TextAlign.Center
        )
        Text(
            copy.text(if (isOffer) "wheel_offer_hint" else "wheel_credits_hint"),
            color = ExamColors.TextSecondary, fontSize = 14.sp, textAlign = TextAlign.Center
        )
        Box(
            Modifier.fillMaxWidth().height(54.dp).clip(RoundedCornerShape(18.dp)).background(ExamColors.Primary)
                .clickable { if (isOffer) onClaimOffer() else onCreditsWon() },
            contentAlignment = Alignment.Center
        ) {
            Text(copy.text(if (isOffer) "claim_offer" else "awesome"), color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
        }
    }
}

private fun hms(seconds: Long): String {
    val s = seconds.coerceAtLeast(0)
    return "%02d:%02d:%02d".format(s / 3600, (s % 3600) / 60, s % 60)
}

/** Ticks once a second and returns the current time in millis. */
@Composable
private fun rememberNow(): Long {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(1000)
            now = System.currentTimeMillis()
        }
    }
    return now
}

/** Home card inviting the daily spin, with a slowly turning mini wheel. */
@Composable
fun GiftWheelHomeCard(copy: LocalizedCopy, spunToday: Boolean, onClick: () -> Unit) {
    val turn = rememberInfiniteTransition(label = "miniWheel")
    val rotation by turn.animateFloat(0f, 360f, infiniteRepeatable(tween(15000, easing = LinearEasing)), label = "rot")
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(Brush.linearGradient(listOf(Color(0xFF3B4A7A), ExamColors.Indigo)))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        WheelFace(copy, Modifier.size(64.dp).rotate(if (spunToday) 0f else rotation), bulbs = false)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(copy.text("gift_wheel_title"), color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
            if (spunToday) {
                val now = rememberNow()
                val midnight = LocalDate.now().plusDays(1).atStartOfDay()
                val left = Duration.between(LocalDateTime.now(), midnight).seconds
                key(now) {
                    Text(copy.text("next_spin_in", mapOf("time" to hms(left))), color = Color.White.copy(alpha = 0.75f), fontSize = 12.sp)
                }
            } else {
                Text(copy.text("gift_wheel_card_hint"), color = Color.White.copy(alpha = 0.8f), fontSize = 12.sp, maxLines = 2)
            }
        }
        if (!spunToday) {
            Text(
                copy.text("spin"), color = NightTop, fontSize = 13.sp, fontWeight = FontWeight.Black,
                modifier = Modifier.clip(CircleShape).background(Color(0xFFFFD166)).padding(horizontal = 14.dp, vertical = 8.dp)
            )
        }
    }
}

/** Time-limited offer card with a live countdown (server-fixed expiry). */
@Composable
fun TimedOfferHomeCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    colors: List<Color>,
    expiresAtMillis: Long,
    onClick: () -> Unit
) {
    val now = rememberNow()
    val pulseTransition = rememberInfiniteTransition(label = "pulse")
    val pulse by pulseTransition.animateFloat(1f, 1.08f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "p")
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(Brush.linearGradient(colors))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            Modifier.size(48.dp).scale(pulse).clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = 0.18f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = Color.White, modifier = Modifier.size(24.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(title, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Black)
            Text(subtitle, color = Color.White.copy(alpha = 0.85f), fontSize = 12.sp, maxLines = 2)
        }
        Text(
            hms((expiresAtMillis - now) / 1000), color = colors.last(), fontSize = 13.sp, fontWeight = FontWeight.Black,
            modifier = Modifier.clip(CircleShape).background(Color.White).padding(horizontal = 10.dp, vertical = 6.dp)
        )
    }
}

/** Credit store banner for a running credit boost. */
@Composable
fun CreditBoostBanner(copy: LocalizedCopy, bonusPercent: Int, expiresAtMillis: Long) {
    val now = rememberNow()
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Brush.horizontalGradient(listOf(Color(0xFF21B89E), Color(0xFF3B6BF5))))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(Icons.Rounded.AutoAwesome, null, tint = Color.White, modifier = Modifier.size(20.dp))
        Column(Modifier.weight(1f)) {
            Text(copy.text("credit_boost_title", mapOf("percent" to bonusPercent.toString())), color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Black)
            Text(copy.text("credit_boost_subtitle"), color = Color.White.copy(alpha = 0.85f), fontSize = 11.sp)
        }
        Text(hms((expiresAtMillis - now) / 1000), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Black)
    }
}

val OfferBoltIcon: ImageVector get() = Icons.Rounded.Bolt
val OfferGiftIcon: ImageVector get() = Icons.Rounded.CardGiftcard
val OfferSparkIcon: ImageVector get() = Icons.Rounded.AutoAwesome
