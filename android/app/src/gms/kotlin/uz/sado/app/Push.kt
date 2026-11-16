package uz.sado.app

import android.content.Context
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Push-уведомления через Google (Firebase Cloud Messaging) — только в сборке «gms».
 *
 * Зачем: приложению не нужно постоянно держать связь с АТС. При звонке АТС шлёт телефону срочный push,
 * телефон будит приложение ([PushService]), оно подключается и принимает звонок обычным путём.
 * В самом push данных о звонке нет — только команда «проснись».
 */
object Push {
    /**
     * Сведения для АТС: «provider» (всегда fcm), «project» (проект Firebase, из которого можно слать)
     * и «token» (адрес этого телефона). null — push здесь не работает: на телефоне нет сервисов Google
     * или сборка сделана без настроек Firebase.
     */
    fun info(context: Context, done: (Map<String, String>?) -> Unit) {
        try {
            val project = context.getString(R.string.project_id)
            FirebaseMessaging.getInstance().token
                .addOnSuccessListener { token ->
                    done(if (token.isNullOrEmpty()) null else mapOf("provider" to "fcm", "project" to project, "token" to token))
                }
                .addOnFailureListener { done(null) }
        } catch (e: Exception) {
            // Firebase не настроен или сервисы Google недоступны.
            done(null)
        }
    }
}

/** Принимает push от Google. Система запускает эту службу сама, даже если приложение закрыто. */
class PushService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        if (message.data["type"] != "wake") return
        SadoEngine.pushWake(applicationContext)
    }

    override fun onNewToken(token: String) {
        // Google сменил адрес телефона — приложение должно сообщить АТС новый.
        SadoEngine.send("pushToken", token)
    }
}
