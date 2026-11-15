package uz.sado.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Уведомление о пропущенных звонках. Обычное уведомление, отдельное от службы ([CallService], id 1):
 * его можно смахнуть, оно не держит процесс и не мешает уведомлению «на связи».
 */
object MissedCalls {
    private const val CHANNEL = "missed"
    private const val ID = 2

    fun show(context: Context, title: String, text: String) {
        // Пока окно на экране, человек и так видит историю; Dart узнаёт об этом и начинает счёт заново.
        if (MainActivity.visible) {
            SadoEngine.send("missedSeen")
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (manager.getNotificationChannel(CHANNEL) == null) {
                // Звук по умолчанию: пропущенный — не звонок, мелодия вызова тут не нужна.
                manager.createNotificationChannel(
                    NotificationChannel(CHANNEL, "SADO: пропущенные звонки", NotificationManager.IMPORTANCE_DEFAULT),
                )
            }
        }
        // Обычный запуск окна, без метки службы: отвечать на звонок или показываться поверх блокировки оно не будет.
        val open = PendingIntent.getActivity(
            context, 2,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_call)
            .setContentTitle(title)
            .setContentText(text)
            .setCategory(Notification.CATEGORY_MISSED_CALL)
            .setContentIntent(open)
            .setAutoCancel(true)
            .setShowWhen(true)
            .build()
        // Без разрешения на уведомления система просто промолчит.
        manager.notify(ID, notification)
    }

    fun clear(context: Context) {
        context.getSystemService(NotificationManager::class.java).cancel(ID)
        // Счёт в Dart тоже начинаем заново (если мотор уже запущен).
        SadoEngine.send("missedSeen")
    }
}
