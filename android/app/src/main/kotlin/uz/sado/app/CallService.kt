package uz.sado.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Фоновая служба приложения. У неё три режима:
 *
 *  - «standby» — приложение на связи с АТС и ждёт звонков; в шторке тихое постоянное уведомление.
 *    Пока служба работает, Android не усыпляет приложение, поэтому входящие доходят и в фоне;
 *  - «ring» — входящий звонок: уведомление на весь экран (в том числе поверх блокировки) с мелодией;
 *  - «show» — идёт разговор: Android не отключает микрофон при сворачивании.
 *
 * Запускается из Dart (lib/platform/call_keeper.dart) через [SadoEngine].
 */
class CallService : Service() {
    companion object {
        const val MODE_STANDBY = "standby"
        const val MODE_RING = "ring"
        const val MODE_CALL = "show"

        private const val CHANNEL_LINK = "link"
        private const val CHANNEL_CALLS = "calls"
        // Каналы входящих со звуком зависят от выбранной мелодии и вибрации, их имена даёт [IncomingRing]
        // (например, «incoming_g3»). Тихие каналы от мелодии не зависят — имена у них постоянные.
        private const val CHANNEL_INCOMING_SILENT = "incoming_silent"
        private const val CHANNEL_INCOMING_OPEN_SILENT = "incoming_open_silent"
        private const val NOTIFICATION_ID = 1
        private const val ACTION_HANG_UP = "uz.sado.app.HANG_UP"
        private const val EXTRA_MODE = "mode"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_PRIMARY = "primary"
        private const val EXTRA_SECONDARY = "secondary"
        private const val EXTRA_SILENT = "silent"

        /**
         * Случайная метка этого запуска приложения. Служба кладёт её в намерения, которыми уведомление открывает
         * окно («Ответить», показ поверх блокировки), а окно без неё такие просьбы не выполняет. Иначе ответить
         * на звонок или вывести окно поверх блокировки могло бы любое чужое приложение: окно объявлено открытым
         * для запуска извне (оно стоит на рабочем столе).
         */
        val intentToken: String = java.util.UUID.randomUUID().toString()

        fun start(
            context: Context,
            mode: String,
            title: String,
            text: String,
            primary: String = "",
            secondary: String = "",
            silent: Boolean = false,
        ) {
            val intent = Intent(context, CallService::class.java)
                .putExtra(EXTRA_MODE, mode)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
                .putExtra(EXTRA_PRIMARY, primary)
                .putExtra(EXTRA_SECONDARY, secondary)
                .putExtra(EXTRA_SILENT, silent)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // Android не разрешил запуск службы из фона. Приложение продолжит работать без неё,
                // пока открыто его окно.
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, CallService::class.java))
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        // Если Android сам перезапустил службу после нехватки памяти — поднимаем и «мотор» с кодом Dart,
        // чтобы приложение снова вышло на связь без открытия окна.
        SadoEngine.get(applicationContext)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_HANG_UP) {
            SadoEngine.send("hangUp")
            return START_STICKY
        }

        // intent == null — служба перезапущена системой: показываем режим ожидания, текст обновит Dart.
        val mode = intent?.getStringExtra(EXTRA_MODE) ?: MODE_STANDBY
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "SADO"
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: ""
        val primary = intent?.getStringExtra(EXTRA_PRIMARY) ?: ""
        val secondary = intent?.getStringExtra(EXTRA_SECONDARY) ?: ""
        val silent = intent?.getBooleanExtra(EXTRA_SILENT, false) ?: false

        val notification = when (mode) {
            MODE_RING -> ringNotification(title, text, acceptLabel = primary, declineLabel = secondary, silent = silent)
            MODE_CALL -> callNotification(title, text, hangUpLabel = primary)
            else -> standbyNotification(title, text)
        }
        if (!enterForeground(notification, mode)) {
            stopSelf()
            return START_NOT_STICKY
        }
        // Процессор держим бодрым только во время разговора: в ожидании телефон должен спать,
        // его будят входящие данные от АТС.
        if (mode == MODE_CALL) holdCpu() else releaseCpu()
        return START_STICKY
    }

    /**
     * Переводит службу в «передний план». Тип «микрофон» система даёт, только если доступ к микрофону
     * уже разрешён, поэтому пробуем варианты по убыванию. Служба вызывается заново при каждой смене
     * состояния, так что после разрешения микрофона тип дополнится сам.
     */
    private fun enterForeground(notification: Notification, mode: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            startForeground(NOTIFICATION_ID, notification)
            return true
        }
        val mic = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        val call = ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
        // Режим ожидания — «особое назначение»: только такой тип Android 15+ разрешает запускать
        // при включении телефона (типы «звонок» и «микрофон» в этот момент запрещены).
        val special = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            call
        }
        val attempts = when (mode) {
            MODE_CALL -> intArrayOf(mic or call, call, mic)
            MODE_RING -> intArrayOf(call, special)
            else -> intArrayOf(special, call)
        }
        for (types in attempts) {
            try {
                startForeground(NOTIFICATION_ID, notification, types)
                return true
            } catch (e: SecurityException) {
                // Этот набор типов системе не подошёл — пробуем следующий.
            } catch (e: IllegalArgumentException) {
                // То же самое на некоторых версиях Android.
            } catch (e: IllegalStateException) {
                // Запуск из фона запрещён (Android 12+).
                return false
            }
        }
        return false
    }

    private fun channel(id: String, name: String, importance: Int, ringing: Boolean = false) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(id)
        if (existing != null) {
            // Канал уже есть: поправляем только название — язык телефона могли сменить.
            if (existing.name != name) {
                existing.name = name
                manager.createNotificationChannel(existing)
            }
            return
        }
        val channel = NotificationChannel(id, name, importance)
        channel.setShowBadge(false)
        if (ringing) {
            // Новый канал звонка — значит, поколение сменилось или это первый звонок: заодно убираем
            // устаревшие каналы, которые не удалось удалить раньше (и каналы старых версий приложения).
            IncomingRing.cleanUp(this)
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            // Мелодия, выбранная в настройках приложения; если её нет — системная мелодия звонка.
            channel.setSound(IncomingRing.soundUri(this), attributes)
            if (IncomingRing.vibrate(this)) {
                channel.enableVibration(true)
                channel.vibrationPattern = IncomingRing.vibrationPattern
            } else {
                // Ритм не задаём: его установка сама снова включает вибрацию канала.
                channel.enableVibration(false)
            }
            channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        } else {
            channel.setSound(null, null)
            channel.enableVibration(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun builder(channelId: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

    private val immutable = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT

    private fun openApp(requestCode: Int, configure: Intent.() -> Unit = {}): PendingIntent =
        PendingIntent.getActivity(
            this, requestCode,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra(MainActivity.EXTRA_TOKEN, intentToken)
                .apply(configure),
            immutable,
        )

    private fun hangUpIntent(): PendingIntent =
        PendingIntent.getService(this, 1, Intent(this, CallService::class.java).setAction(ACTION_HANG_UP), immutable)

    /** Тихое постоянное уведомление «на связи». */
    private fun standbyNotification(title: String, text: String): Notification {
        channel(CHANNEL_LINK, getString(R.string.channel_link), NotificationManager.IMPORTANCE_MIN)
        return builder(CHANNEL_LINK)
            .setSmallIcon(R.drawable.ic_call)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(openApp(0))
            .build()
    }

    /** Идёт разговор: уведомление с кнопкой «Завершить». */
    private fun callNotification(title: String, text: String, hangUpLabel: String): Notification {
        channel(CHANNEL_CALLS, getString(R.string.channel_calls), NotificationManager.IMPORTANCE_LOW)
        return builder(CHANNEL_CALLS)
            .setSmallIcon(R.drawable.ic_call)
            .setContentTitle(title)
            .setContentText(text)
            .setCategory(Notification.CATEGORY_CALL)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(openApp(0))
            .addAction(Notification.Action.Builder(null, hangUpLabel, hangUpIntent()).build())
            .build()
    }

    /** Входящий звонок: на весь экран, с мелодией, с кнопками «Ответить» и «Отклонить». */
    private fun ringNotification(
        title: String,
        text: String,
        acceptLabel: String,
        declineLabel: String,
        silent: Boolean,
    ): Notification {
        // Приложение уже на экране и само показывает входящий — всплывающая плашка поверх него не нужна:
        // она закрывала бы имя звонящего. Берём канал пониже важностью: мелодия играет, плашка не всплывает.
        val open = MainActivity.visible
        // Каналы со звуком — текущего поколения, то есть с выбранными мелодией и вибрацией.
        val incoming = IncomingRing.incomingChannel(this)
        val incomingOpen = IncomingRing.incomingOpenChannel(this)
        // «Без звука»: то же уведомление, но на канале без мелодии и вибрации.
        val channelId = when {
            open && silent -> CHANNEL_INCOMING_OPEN_SILENT
            open -> incomingOpen
            silent -> CHANNEL_INCOMING_SILENT
            else -> incoming
        }
        when (channelId) {
            CHANNEL_INCOMING_OPEN_SILENT ->
                channel(channelId, getString(R.string.channel_incoming_open_silent), NotificationManager.IMPORTANCE_LOW)
            incomingOpen ->
                channel(
                    channelId,
                    getString(R.string.channel_incoming_open),
                    NotificationManager.IMPORTANCE_DEFAULT,
                    ringing = true,
                )
            CHANNEL_INCOMING_SILENT ->
                channel(channelId, getString(R.string.channel_incoming_silent), NotificationManager.IMPORTANCE_HIGH)
            else ->
                channel(channelId, getString(R.string.channel_incoming), NotificationManager.IMPORTANCE_HIGH, ringing = true)
        }
        val fullScreen = openApp(2) { putExtra(MainActivity.EXTRA_RING, true) }
        val accept = openApp(3) { action = MainActivity.ACTION_ACCEPT }
        val decline = hangUpIntent()

        val b = builder(channelId)
            .setSmallIcon(R.drawable.ic_call)
            .setContentTitle(title)
            .setContentText(text)
            .setCategory(Notification.CATEGORY_CALL)
            .setOngoing(true)
            .setShowWhen(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(fullScreen)
        if (!open) b.setFullScreenIntent(fullScreen, true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Системный вид входящего звонка: зелёная и красная кнопки, как у обычного телефона.
            val caller = Person.Builder().setName(title).setImportant(true).build()
            b.setStyle(Notification.CallStyle.forIncomingCall(caller, decline, accept))
        } else {
            b.addAction(Notification.Action.Builder(null, declineLabel, decline).build())
            b.addAction(Notification.Action.Builder(null, acceptLabel, accept).build())
        }
        val notification = b.build()
        // Мелодия играет по кругу, пока уведомление не заменят (ответили, отклонили, звонящий положил трубку).
        if (!silent) notification.flags = notification.flags or Notification.FLAG_INSISTENT
        return notification
    }

    /** Не даёт процессору уснуть при погасшем экране, иначе звук разговора начнёт рваться. */
    private fun holdCpu() {
        if (wakeLock?.isHeld == true) return
        val power = getSystemService(PowerManager::class.java)
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "sado:call").apply {
            setReferenceCounted(false)
            // Страховка: если службу не переключат, блокировка сама снимется через четыре часа.
            acquire(4 * 60 * 60 * 1000L)
        }
    }

    private fun releaseCpu() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    override fun onDestroy() {
        releaseCpu()
        super.onDestroy()
    }
}
