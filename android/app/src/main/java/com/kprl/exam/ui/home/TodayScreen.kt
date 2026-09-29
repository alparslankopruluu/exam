package com.kprl.exam.ui.home

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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.content.ContentPackRepository
import com.kprl.exam.data.StudySetup
import com.kprl.exam.domain.DailyPlanEngine
import com.kprl.exam.platform.AppServices
import com.kprl.exam.platform.entitlements.EntitlementService
import com.kprl.exam.debug.ScreenshotMode
import com.kprl.exam.platform.notifications.DeepLinkRouter
import com.kprl.exam.platform.persistence.StudySetupStore
import com.kprl.exam.widget.WidgetSnapshotWriter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import com.kprl.exam.platform.entitlements.EntitlementSnapshot
import com.kprl.exam.platform.persistence.LearningDatabase
import com.kprl.exam.platform.persistence.LearningRepository
import com.kprl.exam.platform.persistence.PlanTask
import com.kprl.exam.platform.persistence.UserProgressStore
import com.kprl.exam.domain.StudyQuestion
import com.kprl.exam.localization.LocalizedCopy
import com.kprl.exam.ui.components.ExamStatPill
import com.kprl.exam.ui.library.LibraryScreen
import com.kprl.exam.ui.paywall.PremiumPaywallScreen
import com.kprl.exam.ui.practice.PracticeScreen
import com.kprl.exam.ui.question.QuestionSessionScreen
import com.kprl.exam.ui.theme.ExamColors
import com.kprl.exam.ui.tools.*
import com.kprl.exam.ui.tutor.AITutorScreen
import com.kprl.exam.ui.voice.VoiceTutorScreen
import java.time.LocalDate
import java.time.LocalTime
import kotlinx.coroutines.delay

private data class NavItem(val label: String, val icon: ImageVector)

private enum class ToolRoute {
    MOCK,
    MISTAKES,
    FLASHCARDS,
    CREATE_PRACTICE,
    FOCUS,
    PROGRESS,
    CREDITS,
    PROFILE,
    MEDIA
}

@Composable
fun TodayScreen(
    setup: StudySetup,
    onSetupChanged: (StudySetup) -> Unit = {},
    onRestartOnboarding: () -> Unit = {}
) {
    var selectedTab by remember { mutableIntStateOf(0) }
    var premiumPlacement by remember { mutableStateOf<String?>(null) }
    var voiceTutorOpen by remember { mutableStateOf(false) }
    var toolRoute by remember { mutableStateOf<ToolRoute?>(null) }
    var sessionOpen by remember { mutableStateOf(false) }
    var sessionQuestions by remember { mutableStateOf<List<StudyQuestion>?>(null) }
    var sessionType by remember { mutableStateOf("quick_practice") }
    var sessionTimeLimit by remember { mutableStateOf<Int?>(null) }
    var dashboardRefresh by remember { mutableIntStateOf(0) }
    var entitlement by remember { mutableStateOf(EntitlementSnapshot()) }

    val context = LocalContext.current
    val entitlementService = remember { EntitlementService() }
    val repository = remember { LearningRepository(LearningDatabase(context.applicationContext)) }
    val copy = remember(setup.languageCode) { LocalizedCopy.load(context, setup.languageCode) }

    fun openSession(
        type: String = "quick_practice",
        questions: List<StudyQuestion>? = null,
        timeLimitSeconds: Int? = null
    ) {
        sessionType = type
        sessionQuestions = questions
        sessionTimeLimit = timeLimitSeconds
        sessionOpen = true
    }

    LaunchedEffect(premiumPlacement, dashboardRefresh) {
        if (premiumPlacement == null) {
            entitlementService.fetch { entitlement = it }
        }
    }

    LaunchedEffect(Unit) {
        when (ScreenshotMode.screen) {
            "practice" -> selectedTab = 1
            "tutor" -> selectedTab = 2
            "library" -> selectedTab = 3
            "session" -> openSession("quick_practice")
        }
    }

    val pendingRoute by DeepLinkRouter.pending.collectAsState()
    LaunchedEffect(pendingRoute) {
        when (pendingRoute?.let { DeepLinkRouter.consume() }) {
            "paywall" -> if (!entitlement.premium) {
                toolRoute = null
                premiumPlacement = "push_offer"
            }
            "review" -> {
                premiumPlacement = null
                toolRoute = ToolRoute.MISTAKES
            }
            "today" -> {
                premiumPlacement = null
                toolRoute = null
                selectedTab = 0
            }
        }
    }

    when {
        premiumPlacement != null -> {
            PremiumPaywallScreen(
                setup = setup,
                placement = premiumPlacement!!,
                onClose = {
                    premiumPlacement = null
                    dashboardRefresh++
                }
            )
            return
        }

        sessionOpen -> {
            QuestionSessionScreen(
                setup = setup,
                onClose = {
                    sessionOpen = false
                    sessionQuestions = null
                    sessionTimeLimit = null
                    dashboardRefresh++
                },
                questionsOverride = sessionQuestions,
                sessionType = sessionType,
                onSessionCompleted = {
                    if (sessionType == "quick_practice" || sessionType == "daily_plan") {
                        val dayKey = LocalDate.now().toString()
                        repository.plan(dayKey).firstOrNull { !it.completed }?.let {
                            repository.markPlanCompleted(it.id)
                        }
                    }
                    dashboardRefresh++
                },
                onPaywall = { placement ->
                    sessionOpen = false
                    sessionTimeLimit = null
                    premiumPlacement = placement
                },
                timeLimitSeconds = sessionTimeLimit
            )
            return
        }

        voiceTutorOpen -> {
            VoiceTutorScreen(
                setup = setup,
                onClose = {
                    voiceTutorOpen = false
                    dashboardRefresh++
                }
            )
            return
        }

        toolRoute != null -> {
            when (toolRoute!!) {
                ToolRoute.MOCK -> MockExamScreen(
                    setup = setup,
                    onClose = { toolRoute = null },
                    onStart = {
                        toolRoute = null
                        openSession("mock_exam", it, it.size * 90)
                    },
                    onPaywall = {
                        toolRoute = null
                        premiumPlacement = it
                    }
                )

                ToolRoute.MISTAKES -> MistakesScreen(
                    setup = setup,
                    onClose = { toolRoute = null },
                    onPractice = {
                        toolRoute = null
                        openSession("mistake_review")
                    }
                )

                ToolRoute.FLASHCARDS -> FlashcardsScreen(
                    setup = setup,
                    onClose = {
                        toolRoute = null
                        dashboardRefresh++
                    }
                )

                ToolRoute.CREATE_PRACTICE -> CreatePracticeScreen(
                    setup = setup,
                    onClose = { toolRoute = null },
                    onStart = {
                        toolRoute = null
                        openSession("generated_practice", it)
                    },
                    onPaywall = {
                        toolRoute = null
                        premiumPlacement = it
                    }
                )

                ToolRoute.FOCUS -> FocusScreen(
                    setup = setup,
                    onClose = { toolRoute = null }
                )

                ToolRoute.PROGRESS -> ProgressScreen(
                    setup = setup,
                    onClose = { toolRoute = null }
                )

                ToolRoute.CREDITS -> CreditStoreScreen(
                    setup = setup,
                    onClose = {
                        toolRoute = null
                        dashboardRefresh++
                    }
                )

                ToolRoute.MEDIA -> MediaLabScreen(
                    setup = setup,
                    onClose = { toolRoute = null },
                    onNeedCredits = { toolRoute = ToolRoute.CREDITS }
                )

                ToolRoute.PROFILE -> ProfileSettingsScreen(
                    setup = setup,
                    onClose = { toolRoute = null },
                    onSetupChanged = {
                        onSetupChanged(it)
                        toolRoute = null
                    },
                    onProgress = { toolRoute = ToolRoute.PROGRESS },
                    onCredits = { toolRoute = ToolRoute.CREDITS },
                    onRestartOnboarding = onRestartOnboarding
                )
            }
            return
        }
    }

    val nav = listOf(
        NavItem(copy.text("today"), Icons.Rounded.Home),
        NavItem(copy.text("practice"), Icons.Rounded.EditNote),
        NavItem(copy.text("ai_tutor"), Icons.Rounded.AutoAwesome),
        NavItem(copy.text("library"), Icons.Rounded.FolderOpen)
    )

    Scaffold(
        containerColor = ExamColors.Background,
        bottomBar = {
            Surface(color = ExamColors.Surface, shadowElevation = 8.dp) {
                Row(
                    Modifier.fillMaxWidth()
                        .navigationBarsPadding()
                        .padding(horizontal = 8.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceAround
                ) {
                    nav.forEachIndexed { index, item ->
                        Column(
                            Modifier
                                .clip(RoundedCornerShape(14.dp))
                                .clickable { selectedTab = index }
                                .padding(horizontal = 12.dp, vertical = 6.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(
                                item.icon,
                                item.label,
                                tint = if (selectedTab == index) ExamColors.Primary else ExamColors.TextSecondary,
                                modifier = Modifier.size(22.dp)
                            )
                            Text(
                                item.label,
                                fontSize = 10.sp,
                                fontWeight = if (selectedTab == index) FontWeight.Bold else FontWeight.Medium,
                                color = if (selectedTab == index) ExamColors.Primary else ExamColors.TextSecondary
                            )
                        }
                    }
                }
            }
        }
    ) { padding ->
        when (selectedTab) {
            0 -> TodayContent(
                setup = setup,
                copy = copy,
                refreshKey = dashboardRefresh,
                modifier = Modifier.padding(padding),
                onContinue = { openSession("daily_plan") },
                onProfile = { toolRoute = ToolRoute.PROFILE },
                onMistakes = { toolRoute = ToolRoute.MISTAKES },
                onTutor = { selectedTab = 2 },
                onProgress = { toolRoute = ToolRoute.PROGRESS },
                onFocus = { toolRoute = ToolRoute.FOCUS },
                onOffer = { premiumPlacement = "winback" }
            )

            1 -> PracticeScreen(
                setup = setup,
                modifier = Modifier.padding(padding),
                onQuickPractice = { openSession() },
                onMockExam = { toolRoute = ToolRoute.MOCK },
                onMistakes = { toolRoute = ToolRoute.MISTAKES },
                onFlashcards = { toolRoute = ToolRoute.FLASHCARDS },
                onCreatePractice = { toolRoute = ToolRoute.CREATE_PRACTICE },
                onFocus = { toolRoute = ToolRoute.FOCUS }
            )

            2 -> AITutorScreen(
                setup = setup,
                modifier = Modifier.padding(padding),
                onVoiceTutor = {
                    if (entitlement.premium && AppServices.flags.snapshot.voiceTutorEnabled) {
                        voiceTutorOpen = true
                    } else {
                        premiumPlacement = "voice_tutor"
                    }
                },
                onStudyNotes = { selectedTab = 3 },
                onMediaLab = { toolRoute = ToolRoute.MEDIA },
                onPaywall = { premiumPlacement = it }
            )

            else -> LibraryScreen(
                setup = setup,
                modifier = Modifier.padding(padding),
                onStartPractice = { questions ->
                    openSession("material_practice", questions)
                },
                onPaywall = { premiumPlacement = it }
            )
        }
    }
}

@Composable
private fun TodayContent(
    setup: StudySetup,
    copy: LocalizedCopy,
    refreshKey: Int,
    modifier: Modifier,
    onContinue: () -> Unit,
    onProfile: () -> Unit,
    onMistakes: () -> Unit,
    onTutor: () -> Unit,
    onProgress: () -> Unit,
    onFocus: () -> Unit,
    onOffer: () -> Unit
) {
    val context = LocalContext.current
    val repository = remember { LearningRepository(LearningDatabase(context.applicationContext)) }
    val progressStore = remember { UserProgressStore(context.applicationContext) }
    val contentPack = remember(setup.exam.syllabusPackId) {
        ContentPackRepository.load(context, setup.exam.syllabusPackId)
    }

    val dayKey = remember { LocalDate.now().toString() }
    val dashboard = remember(setup.exam.id, refreshKey) {
        val progress = repository.progressSummary(setup.exam.id)
        val user = progressStore.snapshot()

        var plan = repository.plan(dayKey)
        if (plan.isEmpty()) {
            val adaptive = DailyPlanEngine().build(
                weakSkills = repository.weakSkills(setup.exam.id),
                dueSkills = repository.dueSkills(setup.exam.id),
                errorDNA = repository.errorDNA(setup.exam.id),
                dailyMinutes = setup.dailyMinutes
            ).toMutableList()

            if (progress.sessions == 0 && !contentPack?.units.isNullOrEmpty()) {
                adaptive.clear()
                var remaining = setup.dailyMinutes
                contentPack!!.units.take(3).forEachIndexed { index, unit ->
                    val minutes = minOf(
                        unit.durationMinutes?.coerceIn(6, 15) ?: 8,
                        remaining.coerceAtLeast(6)
                    )
                    adaptive += PlanTask(
                        id = "seed_" + dayKey + "_" + index,
                        type = if (index == 0) "foundation" else "practice",
                        skillId = setup.exam.id + ":" + unit.id,
                        title = unit.title,
                        estimatedMinutes = minutes,
                        priority = 1.0 - index * 0.1
                    )
                    remaining -= minutes
                    if (remaining <= 5) return@forEachIndexed
                }
            }

            repository.savePlan(dayKey, adaptive)
            plan = repository.plan(dayKey)
        }

        Triple(progress, user, plan)
    }

    val progress = dashboard.first
    val user = dashboard.second
    val plan = dashboard.third

    LaunchedEffect(dashboard) {
        val due = withContext(Dispatchers.IO) { repository.dueSkills(setup.exam.id).size }
        WidgetSnapshotWriter.write(context.applicationContext, setup, plan, due, user.streak)
    }
    val activeTask = plan.firstOrNull { !it.completed }
    val mastery = if (progress.masteryPercent == 0) setup.diagnosticPercent else progress.masteryPercent
    val completedTasks = plan.count { it.completed }
    val greetingKey = when (LocalTime.now().hour) {
        in 5..11 -> "good_morning"
        in 12..17 -> "good_afternoon"
        else -> "good_evening"
    }
    val totalMinutes = plan.filterNot { it.completed }.sumOf { it.estimatedMinutes }.coerceAtLeast(5)

    Column(
        modifier.fillMaxSize()
            .statusBarsPadding()
            .padding(horizontal = 20.dp)
    ) {
        Spacer(Modifier.height(10.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(copy.text(greetingKey), color = ExamColors.TextSecondary, fontSize = 13.sp)
                Text(copy.text("ready_small_win"), fontWeight = FontWeight.Bold, fontSize = 22.sp)
            }

            Box(
                Modifier.size(42.dp)
                    .background(ExamColors.SoftBlue, RoundedCornerShape(16.dp))
                    .clickable(onClick = onProfile),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Rounded.Person, null, tint = ExamColors.Primary)
            }
        }

        Spacer(Modifier.height(20.dp))
        // Pills stretch to the tallest one so the row stays even.
        Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            ExamStatPill(
                user.streak.toString(),
                copy.text("day_streak"),
                Icons.Rounded.LocalFireDepartment,
                ExamColors.Amber,
                Modifier.weight(1f).fillMaxHeight()
            )
            val daysToExam = remember(setup.exam.id) {
                StudySetupStore(context.applicationContext).daysToExam()
            }
            if (daysToExam != null) {
                ExamStatPill(
                    daysToExam.toString(),
                    copy.text("days_to_exam", mapOf("exam" to setup.exam.shortName)),
                    Icons.Rounded.CalendarMonth,
                    ExamColors.Mint,
                    Modifier.weight(1f).fillMaxHeight()
                )
            } else {
                ExamStatPill(
                    setup.exam.shortName,
                    copy.text("active_exam"),
                    Icons.Rounded.School,
                    ExamColors.Mint,
                    Modifier.weight(1f).fillMaxHeight()
                )
            }
            ExamStatPill(
                mastery.toString(),
                copy.text("mastery"),
                Icons.Rounded.Insights,
                ExamColors.Purple,
                Modifier.weight(1f).fillMaxHeight()
            )
        }

        val expiry = AppServices.flags.snapshot.limitedOfferExpiryEpochSeconds
        if (expiry > System.currentTimeMillis() / 1000L) {
            Spacer(Modifier.height(14.dp))
            LimitedOfferBanner(
                expiryEpochSeconds = expiry,
                title = copy.text("personal_offer"),
                subtitle = copy.text("offer_server_timed"),
                onClick = onOffer
            )
        }

        Spacer(Modifier.height(22.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                copy.text("todays_plan", mapOf("exam" to setup.exam.shortName)).uppercase(),
                color = ExamColors.TextSecondary,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f)
            )
            TextButton(onClick = onProgress) {
                Text(
                    copy.text(
                        "plan_done_count",
                        mapOf(
                            "done" to completedTasks.toString(),
                            "total" to plan.size.coerceAtLeast(1).toString()
                        )
                    ),
                    fontSize = 11.sp
                )
            }
        }
        Spacer(Modifier.height(8.dp))

        Column(
            Modifier.fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(Brush.linearGradient(listOf(ExamColors.Primary, ExamColors.Indigo)))
                .padding(20.dp)
        ) {
            Row {
                Box(
                    Modifier.size(42.dp)
                        .background(Color.White.copy(alpha = .16f), RoundedCornerShape(12.dp)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Rounded.AutoStories, null, tint = Color.White)
                }
                Spacer(Modifier.weight(1f))
                Text(
                    "${user.xp} XP",
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 11.sp,
                    modifier = Modifier
                        .background(Color.White.copy(alpha = .16f), RoundedCornerShape(50))
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                )
            }

            Spacer(Modifier.height(22.dp))
            Text(
                activeTask?.title ?: copy.text("daily_plan_complete"),
                color = Color.White,
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                if (activeTask == null) copy.text("tomorrow_adaptive_plan")
                else copy.text("personalized_plan_hint"),
                color = Color.White.copy(alpha = .82f),
                fontSize = 13.sp
            )

            Spacer(Modifier.height(16.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.Schedule, null, tint = Color.White.copy(alpha = .9f), modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(
                    if (activeTask == null) copy.text("completed")
                    else copy.text(
                        "minutes_remaining",
                        mapOf(
                            "task" to activeTask.estimatedMinutes.toString(),
                            "remaining" to totalMinutes.toString()
                        )
                    ),
                    color = Color.White.copy(alpha = .9f),
                    fontWeight = FontWeight.SemiBold
                )
            }

            Spacer(Modifier.height(18.dp))
            Button(
                onClick = if (activeTask == null) onFocus else onContinue,
                colors = ButtonDefaults.buttonColors(containerColor = Color.White, contentColor = ExamColors.Primary),
                elevation = ButtonDefaults.buttonElevation(0.dp),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth().height(52.dp)
            ) {
                Text(
                    if (activeTask == null) copy.text("start_focus_session") else copy.text("continue"),
                    fontWeight = FontWeight.Bold
                )
            }
        }

        Spacer(Modifier.height(22.dp))
        Text(copy.text("next_up"), fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(9.dp))

        plan.filterNot { it.completed }.drop(1).take(2).forEach { task ->
            NextRow(
                icon = when (task.type) {
                    "review", "mistake_review" -> Icons.Rounded.Refresh
                    "mixed_set" -> Icons.Rounded.FactCheck
                    else -> Icons.Rounded.MenuBook
                },
                title = task.title,
                subtitle = copy.text("minutes_short", mapOf("count" to task.estimatedMinutes.toString())),
                accent = when (task.type) {
                    "mistake_review" -> ExamColors.Coral
                    "mixed_set" -> ExamColors.Purple
                    else -> ExamColors.Primary
                },
                onClick = onContinue
            )
            Spacer(Modifier.height(8.dp))
        }

        if (repository.mistakes(setup.exam.id, 1).isNotEmpty()) {
            NextRow(
                Icons.Rounded.Refresh,
                copy.text("review_mistakes"),
                copy.text("error_dna_attention"),
                ExamColors.Coral,
                onMistakes
            )
            Spacer(Modifier.height(8.dp))
        }

        NextRow(
            Icons.Rounded.AutoAwesome,
            copy.text("ask_tutor"),
            copy.text("explain_scan_practice"),
            ExamColors.Purple,
            onTutor
        )
    }
}

@Composable
private fun LimitedOfferBanner(
    expiryEpochSeconds: Long,
    title: String,
    subtitle: String,
    onClick: () -> Unit
) {
    var now by remember { mutableLongStateOf(System.currentTimeMillis() / 1000L) }

    LaunchedEffect(expiryEpochSeconds) {
        while (now < expiryEpochSeconds) {
            delay(1_000)
            now = System.currentTimeMillis() / 1000L
        }
    }

    val remaining = (expiryEpochSeconds - now).coerceAtLeast(0)
    if (remaining <= 0) return

    val hours = remaining / 3600
    val minutes = (remaining % 3600) / 60
    val seconds = remaining % 60

    Surface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        color = ExamColors.SoftPurple,
        shape = RoundedCornerShape(17.dp),
        border = BorderStroke(1.dp, ExamColors.Purple.copy(alpha = .25f))
    ) {
        Row(Modifier.padding(13.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.Bolt, null, tint = ExamColors.Purple)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                Text(subtitle, color = ExamColors.TextSecondary, fontSize = 10.sp)
            }
            Text(
                "%02d:%02d:%02d".format(hours, minutes, seconds),
                color = ExamColors.Purple,
                fontWeight = FontWeight.Bold,
                fontSize = 12.sp
            )
        }
    }
}

@Composable
private fun NextRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    accent: Color,
    onClick: () -> Unit = {}
) {
    Surface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        shape = RoundedCornerShape(17.dp),
        color = ExamColors.Surface,
        border = BorderStroke(1.dp, ExamColors.Border)
    ) {
        Row(
            Modifier.fillMaxWidth().padding(13.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                Modifier.size(40.dp)
                    .background(accent.copy(alpha = .10f), RoundedCornerShape(13.dp)),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, null, tint = accent, modifier = Modifier.size(20.dp))
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.SemiBold)
                Text(subtitle, color = ExamColors.TextSecondary, fontSize = 11.sp)
            }
            Icon(Icons.Rounded.ChevronRight, null, tint = ExamColors.TextSecondary)
        }
    }
}
