package com.kprl.exam

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.kprl.exam.platform.notifications.DeepLinkRouter
import com.kprl.exam.platform.notifications.StudyStateSync
import com.kprl.exam.ui.ExamApp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        DeepLinkRouter.handle(intent)
        setContent { ExamApp() }
    }

    override fun onResume() {
        super.onResume()
        StudyStateSync.sync(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        DeepLinkRouter.handle(intent)
    }
}
