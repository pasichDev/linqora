package com.pasichDev.linqoraremote

import io.flutter.app.FlutterApplication
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.content.Context

class LinqoraApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "linqora_remote_channel",
                "Linqora Remote Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Linqora Remote running in background"
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}