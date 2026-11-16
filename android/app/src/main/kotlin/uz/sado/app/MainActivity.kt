package uz.sado.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import java.lang.ref.WeakReference

/**
 * Окно приложения. Сам «мотор» Flutter ему не принадлежит (см. [SadoEngine]): окно только
 * подключается к нему и отключается, поэтому связь с АТС не рвётся, когда окно закрыто.
 */
class MainActivity : FlutterActivity() {
    companion object {
        /** Окно открыто кнопкой «Ответить» в уведомлении. */
        const val ACTION_ACCEPT = "uz.sado.app.ACCEPT"

        /** Окно открыто входящим звонком — показать поверх экрана блокировки. */
        const val EXTRA_RING = "ring"

        /** Метка «это намерение создала наша служба» (см. [CallService.intentToken]). */
        const val EXTRA_TOKEN = "token"

        private const val REQUEST_NOTIFICATIONS = 7

        /** Длиннее номер из ссылки не берём: это уже не номер, а мусор. */
        private const val MAX_DIAL_LENGTH = 64

        /** Длиннее ссылку настройки не передаём вовсе (обрезанная была бы испорченной). Та же граница в Dart. */
        private const val MAX_SETUP_LENGTH = 1000

        /** Окно приложения сейчас на экране. Тогда входящий показывает само приложение, без всплывающего уведомления. */
        @Volatile
        var visible = false
    }

    override fun onStart() {
        super.onStart()
        visible = true
        // Человек увидел приложение — пропущенные «прочитаны».
        MissedCalls.clear(this)
    }

    override fun onStop() {
        visible = false
        super.onStop()
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine = SadoEngine.get(context)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        SadoEngine.activity = WeakReference(this)
        // Окно, восстановленное системой, получает своё старое намерение ещё раз — его выполнять нельзя:
        // иначе «ответить» и показ поверх блокировки сработали бы повторно, уже без звонка.
        if (savedInstanceState == null) handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        // Ссылки tel: и sip: приходят от чужих приложений и без метки, поэтому разбираются отдельно,
        // до проверки метки. Проверка ниже для «ответить» и показа поверх блокировки остаётся прежней.
        handleDialLink(intent)
        // Ссылка настройки sado://login (обычно из QR-кода) — тоже без метки и тоже до проверки.
        handleSetupLink(intent)
        // Отвечать на звонок и показывать окно поверх блокировки просит только наше же уведомление.
        // Намерение без метки (от другого приложения или от рабочего стола) просто открывает окно.
        if (intent.getStringExtra(EXTRA_TOKEN) != CallService.intentToken) return
        // То же, если окно открыли из списка недавних приложений: система подставляет прежнее намерение.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val accept = intent.action == ACTION_ACCEPT
        if (accept || intent.getBooleanExtra(EXTRA_RING, false)) setOverLockScreen(true)
        if (accept) SadoEngine.send("accept")
    }

    /**
     * Ссылка tel: или sip: — передаём номер на экран набора. Сам звонок не начинаем: иначе веб-страница
     * могла бы заставить телефон набирать номер. Поверх экрана блокировки окно здесь не показываем никогда.
     */
    private fun handleDialLink(intent: Intent) {
        if (intent.action != Intent.ACTION_DIAL && intent.action != Intent.ACTION_VIEW) return
        // Из списка недавних система подставляет прежнее намерение — номер второй раз не подставляем.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val uri = intent.data ?: return
        val scheme = uri.scheme?.lowercase()
        if (scheme != "tel" && scheme != "sip") return
        var number = uri.schemeSpecificPart ?: return
        number = number.substringBefore('?') // заголовки sip:...?subject=...
        if (scheme == "sip") number = number.substringBefore('@') // sip:100@host — нужен только номер
        number = number.substringBefore(';').trim() // параметры вроде ;phone-context=...
        if (number.isEmpty()) return
        SadoEngine.requestDial(number.take(MAX_DIAL_LENGTH))
    }

    /**
     * Ссылка sado://login?server=…&number=…&password=… — передаём её в Dart как есть, там она проверяется
     * и только заполняет форму входа (входит человек сам). Поверх экрана блокировки окно здесь не показываем.
     * Ссылку не пишем в журнал: в ней может быть пароль.
     */
    private fun handleSetupLink(intent: Intent) {
        if (intent.action != Intent.ACTION_VIEW) return
        // Из списка недавних система подставляет прежнее намерение — форму второй раз не заполняем.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val uri = intent.data ?: return
        if (uri.scheme?.lowercase() != "sado" || uri.host?.lowercase() != "login") return
        val link = uri.toString()
        if (link.length > MAX_SETUP_LENGTH) return
        SadoEngine.requestSetup(link)
    }

    /** Показывать окно поверх экрана блокировки и включать экран — только на время звонка. */
    fun setOverLockScreen(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    /** С Android 13 уведомления нужно разрешить. Без разрешения служба работает, но уведомления не видно. */
    fun askForNotifications() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    /** Код запроса разрешения на контакты (отдельный от остальных, чтобы ответы не путались). */
    private val contactsRequestCode = 8

    /** Кто ждёт ответа на вопрос о контактах. */
    private var contactsCallback: ((Boolean) -> Unit)? = null

    /** Просит разрешение читать контакты; [done] получает ответ человека (или «да» сразу, если уже разрешено). */
    fun requestContacts(done: (Boolean) -> Unit) {
        if (checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED) {
            done(true)
            return
        }
        // Если прошлый вопрос ещё висит, он остаётся без ответа «да».
        contactsCallback?.invoke(false)
        contactsCallback = done
        requestPermissions(arrayOf(Manifest.permission.READ_CONTACTS), contactsRequestCode)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != contactsRequestCode) return
        val callback = contactsCallback
        contactsCallback = null
        callback?.invoke(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
    }

    /** Код запроса окна выбора мелодии (отдельный, чтобы не путать с ответами на разрешения). */
    private val ringtoneRequestCode = 9

    /**
     * Открывает системный выбор мелодии звонка с отмеченной текущей ([current], null — «как в телефоне»).
     * Ответ придёт в [onActivityResult]. Возвращает false, если окно выбора открыть не удалось.
     */
    fun pickRingtone(current: Uri?): Boolean {
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
            .putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_RINGTONE)
            .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            .putExtra(RingtoneManager.EXTRA_RINGTONE_DEFAULT_URI, Settings.System.DEFAULT_RINGTONE_URI)
            .putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, current ?: Settings.System.DEFAULT_RINGTONE_URI)
        return try {
            startActivityForResult(intent, ringtoneRequestCode)
            true
        } catch (e: Exception) {
            // На телефоне нет окна выбора мелодии.
            false
        }
    }

    // Старый способ чтения адреса нужен до Android 13 — отсюда подавление предупреждения.
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != ringtoneRequestCode) return
        // «Назад» в окне выбора — человек передумал, мелодия остаётся прежней.
        val picked = resultCode == RESULT_OK && data != null
        val uri: Uri? = when {
            !picked -> null
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ->
                data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
            else -> data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        }
        SadoEngine.ringtonePicked(applicationContext, picked, uri)
    }

    override fun onDestroy() {
        if (SadoEngine.activity?.get() === this) SadoEngine.activity = null
        super.onDestroy()
    }
}
