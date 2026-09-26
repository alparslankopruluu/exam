package com.kprl.exam.platform.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.kprl.exam.MainActivity
import com.kprl.exam.platform.AppServices
import java.net.HttpURLConnection
import java.net.URL

class ExamMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        AppServices.analytics.event("push_token_refreshed")
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val title = message.data["title"] ?: message.notification?.title ?: "exam"
        val body = message.data["body"] ?: message.notification?.body ?: ""
        val imageUrl = message.data["imageUrl"] ?: message.notification?.imageUrl?.toString()
        showNotification(title, body, imageUrl)
    }

    private fun showNotification(title: String, body: String, imageUrl: String?) {
        val manager = getSystemService(NotificationManager::class.java)
        val channelId = "study_updates"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    "Study updates",
                    NotificationManager.IMPORTANCE_DEFAULT
                )
            )
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            1001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(this, channelId)
        } else {
            android.app.Notification.Builder(this)
        }
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        downloadBitmap(imageUrl)?.let { bitmap ->
            builder.setStyle(
                android.app.Notification.BigPictureStyle()
                    .bigPicture(bitmap)
                    .setSummaryText(body)
            )
        }

        manager.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), builder.build())
    }

    private fun downloadBitmap(urlString: String?): Bitmap? {
        if (urlString.isNullOrBlank()) return null
        return runCatching {
            val connection = URL(urlString).openConnection() as HttpURLConnection
            connection.connectTimeout = 5_000
            connection.readTimeout = 8_000
            connection.doInput = true
            connection.connect()
            connection.inputStream.use(BitmapFactory::decodeStream)
        }.getOrNull()
    }
}
