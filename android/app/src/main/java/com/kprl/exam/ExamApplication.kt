package com.kprl.exam

import android.app.Application
import com.kprl.exam.platform.AppServices

class ExamApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AppServices.initialize(this)
    }
}
