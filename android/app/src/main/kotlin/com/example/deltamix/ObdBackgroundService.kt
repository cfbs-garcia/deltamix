package com.example.deltamix

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Serviço em segundo plano + WakeLock para manter o monitoramento OBD-II,
 * gravação de Sprints/Diário e reconexão automática ativos mesmo com a tela
 * desligada ou enquanto o motorista utiliza outros apps (Waze, Maps, etc.).
 */
class ObdBackgroundService : Service() {

    companion object {
        const val CHANNEL_ID = "deltamix_obd_background"
        const val NOTIFICATION_ID = 7102
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE)
            ?: "Deltamix • Monitoramento OBD-II Ativo"
        val body = intent?.getStringExtra(EXTRA_BODY)
            ?: "Registrando telemetria e Sprint em segundo plano."

        acquireWakeLock()
        val notification = buildNotification(title, body)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
            // Caso o Android restrinja foreground service em algum estado específico,
            // mantém o WakeLock da CPU ativo e exibe a notificação normalmente.
            try {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(NOTIFICATION_ID, notification)
            } catch (_: Exception) {}
        }

        return START_STICKY
    }

    override fun onDestroy() {
        releaseWakeLock()
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NOTIFICATION_ID)
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun acquireWakeLock() {
        try {
            if (wakeLock == null) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "Deltamix::ObdTelemetryWakeLock"
                ).apply {
                    setReferenceCounted(false)
                }
            }
            if (wakeLock?.isHeld == false) {
                // Mantém a CPU acordada por até 6 horas contínuas (renovado a cada atualização)
                wakeLock?.acquire(6 * 60 * 60 * 1000L)
            }
        } catch (_: Exception) {}
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Monitoramento OBD-II em Segundo Plano",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description =
                    "Mantém a leitura da ECU, gravação da Sprint e reconexão automática com a tela desligada."
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(title: String, body: String): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, pendingFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
