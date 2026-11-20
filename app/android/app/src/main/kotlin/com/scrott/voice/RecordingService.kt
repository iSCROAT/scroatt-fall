package com.scrott.voice

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Servico em primeiro plano que mantem a gravacao ativa enquanto o app
 * esta em segundo plano.
 *
 * A notificacao publicada aqui e a mesma que o app Dart atualiza a cada
 * segundo com o tempo decorrido. Os botoes de acao rapida (pausar,
 * continuar, parar) sao entregues de volta ao Dart por [ACTION_CHANNEL].
 */
class RecordingService : Service() {

    companion object {
        const val CHANNEL_ID = "scrott_recording"
        const val NOTIFICATION_ID = 1001

        /** Canal usado pelo app Dart para publicar as acoes de acesso rapido. */
        const val ACTION_CHANNEL = "com.scrott.voice/recorder_actions"

        const val ACTION_PAUSE = "pause"
        const val ACTION_RESUME = "resume"
        const val ACTION_STOP = "stop"
        const val ACTION_RESTART = "restart"

        /** Identificador do motor Flutter registrado pelo app Dart. */
        const val ENGINE_ID = "scrott_engine"
    }

    private var channel: MethodChannel? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action

        // Acao vinda do botao da notificacao: repassa ao Dart e encerra.
        if (action != null) {
            dispatchToFlutter(action)
            stopSelf()
            return START_NOT_STICKY
        }

        // Demais inicios: atualiza a notificacao de primeiro plano.
        val elapsed = intent?.getStringExtra("elapsed") ?: "00:00"
        val paused = intent?.getBooleanExtra("paused", false) ?: false
        startForeground(NOTIFICATION_ID, buildNotification(elapsed, paused))
        return START_STICKY
    }

    override fun onDestroy() {
        stopForeground(true)
        super.onDestroy()
    }

    /** Cria o canal de notificacao usado pela gravacao (Android 8+). */
    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Recording",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows the ongoing recording with quick actions."
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    /** Monta a notificacao com os botoes de acao rapido. */
    private fun buildNotification(elapsed: String, paused: Boolean): Notification {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(elapsed)
            .setContentText(if (paused) "Paused" else "Recording")
            .setSmallIcon(if (paused) R.drawable.ic_pause else R.drawable.ic_mic)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(openAppIntent())

        if (paused) {
            builder.addAction(
                R.drawable.ic_mic,
                "Resume",
                actionIntent(ACTION_RESUME, 1),
            )
            builder.addAction(
                R.drawable.ic_refresh,
                "Restart",
                actionIntent(ACTION_RESTART, 2),
            )
        } else {
            builder.addAction(
                R.drawable.ic_pause,
                "Pause",
                actionIntent(ACTION_PAUSE, 1),
            )
        }
        builder.addAction(
            R.drawable.ic_stop,
            "Stop",
            actionIntent(ACTION_STOP, 3),
        )
        return builder.build()
    }

    /** Intent que reabre o app quando o corpo da notificacao e tocado. */
    private fun openAppIntent(): PendingIntent {
        val intent = Intent(this, FlutterActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Intent que entrega a acao escolhida ao lado Dart. */
    private fun actionIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, RecordingService::class.java).apply {
            action = action
        }
        return PendingIntent.getService(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Encaminha a acao para o motor Flutter, se ele estiver vivo. */
    private fun dispatchToFlutter(action: String) {
        val engine = FlutterEngineCache.getInstance().get(ENGINE_ID) ?: return
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, ACTION_CHANNEL)
        channel?.invokeMethod("recorderAction", action)
    }
}
