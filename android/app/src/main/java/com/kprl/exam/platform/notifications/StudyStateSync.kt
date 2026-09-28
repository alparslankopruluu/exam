package com.kprl.exam.platform.notifications

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import com.kprl.exam.platform.persistence.LearningDatabase
import com.kprl.exam.platform.persistence.LearningRepository
import com.kprl.exam.platform.persistence.StudySetupStore
import kotlin.concurrent.thread

/** Refreshes the study state the reminder scheduler relies on. */
object StudyStateSync {
    fun sync(context: Context) {
        if (runCatching { FirebaseApp.getInstance() }.isFailure) return
        val app = context.applicationContext
        val setupStore = StudySetupStore(app)
        if (!setupStore.isNotificationPrompted()) return
        val setup = setupStore.load() ?: return

        FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
            thread(name = "study-state-sync") {
                val due = runCatching {
                    LearningRepository(LearningDatabase(app)).dueSkills(setup.exam.id).size
                }.getOrNull()
                PushTokenRegistrar.register(
                    context = app,
                    token = token,
                    examId = setup.exam.id,
                    examName = setup.exam.shortName,
                    dueReviews = due
                )
            }
        }
    }
}
