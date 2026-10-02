package com.trashpotting.trashpotting_v3

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    // Canale usato dalle notifiche push (vedi default_notification_channel_id
    // in res/values/notifications.xml e functions/index.js). Senza, Android
    // le metterebbe in un generico "Varie".
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            getString(R.string.default_notification_channel_id),
            "Notifiche Trashpotting",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Zone ripulite, promemoria eventi e nuove segnalazioni vicine"
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }
}
