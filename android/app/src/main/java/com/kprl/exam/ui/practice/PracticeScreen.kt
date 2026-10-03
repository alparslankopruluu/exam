package com.kprl.exam.ui.practice

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
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.content.ContentPackRepository
import com.kprl.exam.data.StudySetup
import com.kprl.exam.localization.LocalizedCopy
import com.kprl.exam.ui.theme.ExamColors
import com.kprl.exam.content.ContentUnit
import com.kprl.exam.debug.ScreenshotMode
import com.kprl.exam.platform.persistence.LearningDatabase
import com.kprl.exam.platform.persistence.LearningRepository
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.withStyle
import androidx.compose.foundation.verticalScroll

@Composable
fun PracticeScreen(
    setup: StudySetup,
    modifier: Modifier = Modifier,
    onQuickPractice: () -> Unit = {},
    onMockExam: () -> Unit = {},
    onMistakes: () -> Unit = {},
    onFlashcards: () -> Unit = {},
    onCreatePractice: () -> Unit = {},
    onFocus: () -> Unit = {},
    onLibrary: () -> Unit = {}
) {
    val context = LocalContext.current
    var lessonUnit by remember { mutableStateOf<ContentUnit?>(null) }
    lessonUnit?.let { unit ->
        LessonScreen(
            setup, unit,
            onClose = { lessonUnit = null },
            onPractice = { lessonUnit = null; onQuickPractice() },
            onLibrary = { lessonUnit = null; onLibrary() }
        )
        return
    }
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    val pack = remember(setup.exam.syllabusPackId) {
        ContentPackRepository.load(context, setup.exam.syllabusPackId)
    }

    Column(
        modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 20.dp)
    ) {
        Spacer(Modifier.height(12.dp))
        Text(copy.text("practice"), fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text(copy.text("practice_pack_hint", mapOf("exam" to setup.exam.shortName)), color = ExamColors.TextSecondary, fontSize = 13.sp)

        Spacer(Modifier.height(22.dp))
        Column(
            Modifier.fillMaxWidth()
                .background(
                    Brush.linearGradient(listOf(ExamColors.Primary, ExamColors.Indigo)),
                    RoundedCornerShape(24.dp)
                )
                .padding(20.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.size(46.dp).background(Color.White.copy(alpha = .16f), RoundedCornerShape(14.dp)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Rounded.Bolt, null, tint = Color.White)
                }
                Spacer(Modifier.weight(1f))
                Text(copy.text("minutes_short", mapOf("count" to "5")).uppercase(), color = Color.White.copy(alpha = .85f), fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(22.dp))
            Text(copy.text("quick_practice"), color = Color.White, fontSize = 25.sp, fontWeight = FontWeight.Bold)
            Text(copy.text("quick_practice_hint"), color = Color.White.copy(alpha = .82f), fontSize = 13.sp)
            Spacer(Modifier.height(18.dp))
            Surface(
                onClick = onQuickPractice,
                color = Color.White,
                contentColor = ExamColors.Primary,
                shape = RoundedCornerShape(16.dp)
            ) {
                Text(copy.text("start_questions", mapOf("count" to "5")), fontWeight = FontWeight.Bold, modifier = Modifier.fillMaxWidth().padding(16.dp), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
        }

        if (!pack?.units.isNullOrEmpty()) {
            val mastery = remember(setup.exam.id) {
                val titles = pack!!.units.map { it.title }
                if (ScreenshotMode.screen != null) titles.indices.map { listOf(86, 64, 38, null, null, null)[it % 6] }
                else LearningRepository(LearningDatabase(context.applicationContext)).sectionMastery(setup.exam.id, titles)
            }
            Spacer(Modifier.height(22.dp))
            Text(copy.text("learning_path"), fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            MasteryLegend(copy)
            Spacer(Modifier.height(6.dp))
            MasteryPath(pack!!.units, mastery, copy) { lessonUnit = it }
        }

        Spacer(Modifier.height(14.dp))
        PracticeRow(Icons.Rounded.Timer, copy.text("mock_exam"), copy.text("mock_exam_hint"), ExamColors.Purple, onMockExam)
        Spacer(Modifier.height(9.dp))
        PracticeRow(Icons.Rounded.Refresh, copy.text("mistakes"), copy.text("mistakes_hint"), ExamColors.Coral, onMistakes)
        Spacer(Modifier.height(9.dp))
        PracticeRow(Icons.Rounded.Style, copy.text("flashcards"), copy.text("flashcards_hint"), ExamColors.Mint, onFlashcards)
        Spacer(Modifier.height(9.dp))
        PracticeRow(Icons.Rounded.AutoAwesome, copy.text("create_practice"), copy.text("create_practice_hint"), ExamColors.Amber, onCreatePractice)
        Spacer(Modifier.height(9.dp))
        PracticeRow(Icons.Rounded.CenterFocusStrong, copy.text("focus"), copy.text("focus_hint"), ExamColors.Primary, onFocus)
    }
}

@Composable
private fun PracticeRow(icon: ImageVector, title: String, subtitle: String, accent: Color, onClick: () -> Unit = {}) {
    Surface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        color = ExamColors.Surface,
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(1.dp, ExamColors.Border)
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(44.dp).background(accent.copy(alpha = .11f), RoundedCornerShape(14.dp)),
                contentAlignment = Alignment.Center
            ) { Icon(icon, null, tint = accent) }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                Text(subtitle, color = ExamColors.TextSecondary, fontSize = 11.sp)
            }
            Icon(Icons.Rounded.ChevronRight, null, tint = ExamColors.TextSecondary)
        }
    }
}

/** Where a pack section stands on the learning path (mirrors iOS MasteryStatus). */
private enum class MasteryStatus(val key: String, val color: Color) {
    MASTERED("status_mastered", ExamColors.Mint),
    LEARNING("status_learning", ExamColors.Amber),
    REVIEW("status_review", ExamColors.Coral),
    NOT_STARTED("status_not_started", ExamColors.Border);

    companion object {
        fun of(percent: Int?) = when {
            percent == null -> NOT_STARTED
            percent >= 80 -> MASTERED
            percent < 50 -> REVIEW
            else -> LEARNING
        }
    }
}

@Composable
private fun MasteryLegend(copy: LocalizedCopy) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        MasteryStatus.entries.forEach { status ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(9.dp).background(status.color, CircleShape))
                Spacer(Modifier.width(5.dp))
                Text(copy.text(status.key), fontSize = 11.sp, fontWeight = FontWeight.Medium, color = ExamColors.TextSecondary, maxLines = 1)
            }
        }
    }
}

/** Pack sections as a zig-zag path of nodes joined by a dashed trail (mirrors iOS MasteryPath). */
@Composable
private fun MasteryPath(units: List<ContentUnit>, mastery: List<Int?>, copy: LocalizedCopy, onSelect: (ContentUnit) -> Unit) {
    val rowHeight = 104.dp
    BoxWithConstraints(Modifier.fillMaxWidth().height(rowHeight * units.size)) {
        Canvas(Modifier.fillMaxSize()) {
            val node = 31.dp.toPx()
            val row = rowHeight.toPx()
            val points = units.indices.map { Offset(if (it % 2 == 0) node else size.width - node, row * it + row / 2) }
            if (points.size > 1) {
                val path = Path().apply {
                    moveTo(points[0].x, points[0].y)
                    points.zipWithNext().forEach { (a, b) ->
                        val midY = (a.y + b.y) / 2
                        cubicTo(a.x, midY, b.x, midY, b.x, b.y)
                    }
                }
                drawPath(
                    path, ExamColors.Border,
                    style = Stroke(4.dp.toPx(), cap = StrokeCap.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 10.dp.toPx())))
                )
            }
        }
        units.forEachIndexed { index, unit ->
            val percent = mastery.getOrNull(index)
            val status = MasteryStatus.of(percent)
            val left = index % 2 == 0
            Row(
                Modifier.fillMaxWidth().height(rowHeight).offset(y = rowHeight * index).clickable { onSelect(unit) },
                horizontalArrangement = if (left) Arrangement.Start else Arrangement.End,
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (!left) {
                    MasteryLabel(unit, percent, status, copy, TextAlign.End, Modifier.weight(1f, fill = false))
                    Spacer(Modifier.width(12.dp))
                }
                Box(
                    Modifier.size(62.dp)
                        .background(if (status == MasteryStatus.NOT_STARTED) ExamColors.Surface else status.color.copy(alpha = 0.16f), CircleShape)
                        .border(3.dp, status.color, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        when (status) {
                            MasteryStatus.MASTERED -> Icons.Rounded.Check
                            MasteryStatus.NOT_STARTED -> Icons.Rounded.LockOpen
                            else -> Icons.Rounded.MenuBook
                        },
                        null,
                        tint = if (status == MasteryStatus.NOT_STARTED) ExamColors.TextSecondary else status.color,
                        modifier = Modifier.size(24.dp)
                    )
                }
                if (left) {
                    Spacer(Modifier.width(12.dp))
                    MasteryLabel(unit, percent, status, copy, TextAlign.Start, Modifier.weight(1f, fill = false))
                }
            }
        }
    }
}

@Composable
private fun MasteryLabel(unit: ContentUnit, percent: Int?, status: MasteryStatus, copy: LocalizedCopy, align: TextAlign, modifier: Modifier) {
    Column(modifier, horizontalAlignment = if (align == TextAlign.End) Alignment.End else Alignment.Start) {
        Text(unit.title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = ExamColors.TextPrimary, textAlign = align, maxLines = 2)
        Text(
            percent?.let { "${copy.text(status.key)} · $it%" } ?: copy.text(status.key),
            fontSize = 12.sp, fontWeight = FontWeight.Medium,
            color = if (status == MasteryStatus.NOT_STARTED) ExamColors.TextSecondary else status.color
        )
    }
}

/**
 * A topic page from the learning path (mirrors iOS LessonView): Learn (an AI explainer,
 * cached per topic), Practice and Notes tabs.
 */
@Composable
private fun LessonScreen(setup: StudySetup, unit: ContentUnit, onClose: () -> Unit, onPractice: () -> Unit, onLibrary: () -> Unit) {
    val context = LocalContext.current
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }
    val prefs = remember { context.getSharedPreferences("lessons", android.content.Context.MODE_PRIVATE) }
    val cacheKey = "lesson.${setup.exam.id}.${setup.languageCode}.${unit.id}"
    var tab by remember { mutableIntStateOf(0) }
    var lesson by remember { mutableStateOf(prefs.getString(cacheKey, null)) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(unit.id) {
        if (lesson != null) return@LaunchedEffect
        com.kprl.exam.platform.ai.AIGatewayClient().askTutor(
            setup,
            "Teach the topic \"${unit.title}\" for the ${setup.exam.shortName} exam as a short lesson: " +
                "a two-sentence overview, then 4 key points as a bulleted list, then one worked example. Use **bold** for key terms."
        ) { result ->
            when (result) {
                is com.kprl.exam.platform.ai.GatewayResult.Success -> {
                    lesson = result.value
                    prefs.edit().putString(cacheKey, result.value).apply()
                }
                is com.kprl.exam.platform.ai.GatewayResult.Error -> error = result.message
            }
        }
    }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background).statusBarsPadding().navigationBarsPadding()
            .padding(horizontal = 20.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onClose) { Icon(Icons.Rounded.ArrowBack, null) }
            Text(unit.title, fontSize = 22.sp, fontWeight = FontWeight.Bold, maxLines = 1)
        }
        Row(
            Modifier.padding(top = 8.dp).fillMaxWidth().background(ExamColors.Border.copy(alpha = 0.6f), RoundedCornerShape(50)).padding(4.dp)
        ) {
            listOf("tab_learn", "practice", "tab_notes").forEachIndexed { index, key ->
                Box(
                    Modifier.weight(1f).height(36.dp)
                        .background(if (tab == index) ExamColors.Surface else Color.Transparent, RoundedCornerShape(50))
                        .clickable { tab = index },
                    contentAlignment = Alignment.Center
                ) {
                    Text(copy.text(key), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = if (tab == index) ExamColors.Primary else ExamColors.TextSecondary)
                }
            }
        }
        Column(
            Modifier.weight(1f).verticalScroll(androidx.compose.foundation.rememberScrollState()).padding(top = 16.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            when (tab) {
                0 -> {
                    androidx.compose.foundation.Image(
                        androidx.compose.ui.res.painterResource(com.kprl.exam.R.drawable.illu_hero_student), null,
                        modifier = Modifier.fillMaxWidth().height(166.dp).background(ExamColors.SoftBlue, RoundedCornerShape(22.dp)).padding(vertical = 8.dp)
                    )
                    when {
                        lesson != null -> Surface(color = ExamColors.Surface, shape = RoundedCornerShape(20.dp), border = BorderStroke(1.dp, ExamColors.Border)) {
                            Text(markdownBold(lesson!!), fontSize = 15.sp, lineHeight = 22.sp, color = ExamColors.TextPrimary, modifier = Modifier.padding(16.dp))
                        }
                        error != null -> Text(error!!, fontSize = 13.sp, color = ExamColors.Coral)
                        else -> Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(16.dp)) {
                            CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                            Spacer(Modifier.width(10.dp))
                            Text(copy.text("lesson_loading"), fontSize = 14.sp, color = ExamColors.TextSecondary)
                        }
                    }
                    LessonButton(copy.text("start_questions", mapOf("count" to "5")), onPractice)
                }
                1 -> LessonAction(com.kprl.exam.R.drawable.illu_focus_scene, copy.text("lesson_practice_hint", mapOf("topic" to unit.title)), copy.text("start_questions", mapOf("count" to "5")), onPractice)
                else -> LessonAction(com.kprl.exam.R.drawable.illu_calendar, copy.text("lesson_notes_hint"), copy.text("open_library"), onLibrary)
            }
        }
    }
}

@Composable
private fun LessonAction(image: Int, text: String, button: String, onClick: () -> Unit) {
    androidx.compose.foundation.Image(
        androidx.compose.ui.res.painterResource(image), null,
        contentScale = androidx.compose.ui.layout.ContentScale.Crop,
        modifier = Modifier.fillMaxWidth().height(170.dp).clip(RoundedCornerShape(22.dp))
    )
    Text(text, fontSize = 15.sp, color = ExamColors.TextSecondary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
    LessonButton(button, onClick)
}

@Composable
private fun LessonButton(text: String, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().height(56.dp),
        shape = RoundedCornerShape(18.dp),
        colors = ButtonDefaults.buttonColors(containerColor = ExamColors.Primary),
        elevation = ButtonDefaults.buttonElevation(0.dp)
    ) { Text(text, fontWeight = FontWeight.Bold, fontSize = 16.sp) }
}

/** Renders **bold** spans from the tutor's markdown. */
private fun markdownBold(text: String) = androidx.compose.ui.text.buildAnnotatedString {
    text.split("**").forEachIndexed { index, part ->
        if (index % 2 == 1) withStyle(androidx.compose.ui.text.SpanStyle(fontWeight = FontWeight.Bold)) { append(part) } else append(part)
    }
}

