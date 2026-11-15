package uz.sado.app

import android.app.NotificationManager
import android.content.Context
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import java.io.FileNotFoundException

/**
 * Мелодия и вибрация входящих звонков.
 *
 * Хранятся здесь, в настройках самого Android-приложения, а не в Dart: звонить должна фоновая служба,
 * даже когда окно с кодом Dart не открыто.
 *
 * Мелодию и вибрацию на Android 8+ задаёт канал уведомлений, и после создания канала их уже не поменять.
 * Поэтому при каждой смене растёт «поколение» каналов: служба создаёт новые каналы (`incoming_g3`,
 * `incoming_open_g3`) с выбранным звуком, а каналы прошлого поколения удаляются. Тихие каналы от мелодии
 * не зависят и остаются прежними.
 */
object IncomingRing {
    private const val PREFS = "sado_ring"
    private const val KEY_URI = "uri"
    private const val KEY_VIBRATE = "vibrate"
    private const val KEY_GENERATION = "generation"
    private const val KEY_STALE = "staleChannels"

    private const val BASE_INCOMING = "incoming"
    private const val BASE_INCOMING_OPEN = "incoming_open"

    /** Ритм вибрации при звонке — тот же, что был до появления этой настройки. */
    val vibrationPattern = longArrayOf(0, 800, 600, 800, 600)

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun generation(context: Context): Int = prefs(context).getInt(KEY_GENERATION, 0)

    /** Канал входящих со звуком (окно закрыто) для текущего поколения. */
    fun incomingChannel(context: Context): String = "${BASE_INCOMING}_g${generation(context)}"

    /** Канал входящих со звуком, когда окно приложения на экране. */
    fun incomingOpenChannel(context: Context): String = "${BASE_INCOMING_OPEN}_g${generation(context)}"

    fun vibrate(context: Context): Boolean = prefs(context).getBoolean(KEY_VIBRATE, true)

    /** Выбранная мелодия, если её ещё можно открыть; null — системная мелодия звонка. */
    fun chosenUri(context: Context): Uri? {
        val uri = prefs(context).getString(KEY_URI, null)?.let { Uri.parse(it) } ?: return null
        return if (available(context, uri)) uri else null
    }

    /**
     * Звук для канала. Если выбранный файл удалили — молча берём системную мелодию: звонок без звука
     * хуже, чем звонок «не той» мелодией.
     */
    fun soundUri(context: Context): Uri =
        chosenUri(context) ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

    /** Состояние для экрана настроек в Dart: название мелодии (null — «как в телефоне») и вибрация. */
    fun state(context: Context): Map<String, Any?> = mapOf(
        "title" to title(context),
        "vibrate" to vibrate(context),
    )

    private fun title(context: Context): String? {
        val uri = chosenUri(context) ?: return null
        return try {
            RingtoneManager.getRingtone(context, uri)?.getTitle(context)
        } catch (e: Exception) {
            // Название узнать не удалось (нет доступа к файлу и т. п.) — показываем «как в телефоне».
            null
        }
    }

    /** Запоминает выбранную мелодию. [uri] null или системный адрес — «как в телефоне». */
    fun setRingtone(context: Context, uri: Uri?) {
        val value = if (uri == null || uri == Settings.System.DEFAULT_RINGTONE_URI) null else uri.toString()
        val store = prefs(context)
        if (store.getString(KEY_URI, null) == value) return // ничего не поменялось — каналы не трогаем
        val editor = store.edit()
        if (value == null) editor.remove(KEY_URI) else editor.putString(KEY_URI, value)
        editor.commit()
        nextGeneration(context)
    }

    fun setVibrate(context: Context, on: Boolean) {
        val store = prefs(context)
        if (store.getBoolean(KEY_VIBRATE, true) == on) return
        store.edit().putBoolean(KEY_VIBRATE, on).commit()
        nextGeneration(context)
    }

    /**
     * Новое поколение каналов. Новые каналы служба создаст сама при следующем входящем,
     * а каналы прошлого поколения убираем, чтобы в системных настройках не копились лишние.
     */
    private fun nextGeneration(context: Context) {
        val store = prefs(context)
        val old = generation(context)
        val stale = staleChannels(context) + setOf("${BASE_INCOMING}_g$old", "${BASE_INCOMING_OPEN}_g$old")
        // commit, а не apply: служба может прочитать поколение сразу же, при ближайшем входящем.
        store.edit().putInt(KEY_GENERATION, old + 1).putStringSet(KEY_STALE, stale).commit()
        cleanUp(context)
    }

    /**
     * Каналы, которые ещё нужно удалить. В первый раз сюда попадают и каналы из версий приложения
     * без этой настройки (`incoming`, `incoming_open`) — так они удаляются ровно один раз.
     */
    private fun staleChannels(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_STALE, null)?.toSet() ?: setOf(BASE_INCOMING, BASE_INCOMING_OPEN)

    /**
     * Удаляет устаревшие каналы. Android не даёт удалить канал, на котором сейчас висит уведомление
     * фоновой службы (идёт входящий), — такой канал остаётся в списке и удалится при следующем вызове.
     */
    fun cleanUp(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val stale = staleChannels(context)
        // Удалять нечего (в том числе каналы старых версий уже удалены) — лишний раз ничего не пишем.
        if (stale.isEmpty()) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val left = mutableSetOf<String>()
        for (id in stale) {
            try {
                manager.deleteNotificationChannel(id)
            } catch (e: Exception) {
                left.add(id)
            }
        }
        prefs(context).edit().putStringSet(KEY_STALE, left).apply()
    }

    /**
     * Можно ли ещё открыть мелодию. Если файла нет — нельзя. Если нет прав проверить (мелодия во внешней
     * памяти) — считаем, что можно: играет её система, у которой права есть.
     */
    private fun available(context: Context, uri: Uri): Boolean =
        try {
            val file = context.contentResolver.openAssetFileDescriptor(uri, "r")
            file?.close()
            file != null
        } catch (e: FileNotFoundException) {
            false
        } catch (e: SecurityException) {
            true
        } catch (e: Exception) {
            false
        }
}
