package uz.sado.app

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.content.Intent
import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * Один на всё приложение «мотор» Flutter, который живёт отдельно от окна.
 *
 * Зачем: обычно код Dart (а в нём — связь с АТС) умирает вместе с окном приложения. Здесь мотор
 * принадлежит процессу, а не окну: окно можно свернуть или закрыть, а регистрация на АТС остаётся,
 * пока фоновая служба ([CallService]) держит процесс живым. Когда приходит звонок, окно открывается
 * заново и подключается к тому же мотору.
 */
object SadoEngine {
    private const val ID = "sado"
    private const val CHANNEL = "uz.sado.app/call"

    private var channel: MethodChannel? = null
    private var proximityLock: PowerManager.WakeLock? = null
    private val main = Handler(Looper.getMainLooper())

    /** Окно приложения, если оно сейчас открыто. Нужно для того, что без окна не сделать (запросы разрешений). */
    @Volatile
    var activity: WeakReference<MainActivity>? = null

    @Synchronized
    fun get(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        cache.get(ID)?.let { return it }

        val app = context.applicationContext
        val engine = FlutterEngine(app)
        // Запускаем main() из Dart сразу, не дожидаясь окна.
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        cache.put(ID, engine)

        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result -> handle(app, call, result) }
        channel = ch
        PhoneContacts.register(app, engine.dartExecutor.binaryMessenger)
        return engine
    }

    /**
     * Номер из ссылки tel:/sip:, который Dart ещё не забрал. При холодном запуске мотор может быть
     * не готов принять событие, поэтому номер ждёт здесь, пока Dart не спросит ([takePendingDial]).
     */
    @Volatile
    var pendingDial: String? = null

    /** Запоминает номер и сразу сообщает Dart — на случай, когда приложение уже запущено. */
    fun requestDial(number: String) {
        pendingDial = number
        send("dialRequest", number)
    }

    /**
     * Ссылка настройки sado://login?…, которую Dart ещё не забрал (как [pendingDial]). Хранится как есть
     * и только до первого [takePendingSetup]: в ней может быть пароль. Разбирает и проверяет её Dart.
     */
    @Volatile
    var pendingSetup: String? = null

    /** Запоминает ссылку настройки и сразу сообщает Dart. Ссылку не пишем в журнал — в ней может быть пароль. */
    fun requestSetup(link: String) {
        pendingSetup = link
        send("setupRequest", link)
    }

    /** Когда пришёл push «проснись» (время по часам работы телефона); 0 — не приходил. */
    @Volatile
    private var pushWokeAt = 0L

    /**
     * Пришёл push «проснись»: поднимаем службу и мотор (как после включения телефона) и сообщаем Dart.
     * Срочный push даёт приложению право запустить службу из фона. Что делать дальше — выйти на связь
     * и ждать звонка — решает код Dart; если он ещё не запущен, он спросит сам ([takePushWake]).
     */
    fun pushWake(app: Context) {
        pushWokeAt = android.os.SystemClock.elapsedRealtime()
        CallService.start(app, CallService.MODE_STANDBY, title = "SADO", text = "")
        send("pushWake")
    }

    /**
     * Google сменил адрес телефона для push. Если код Dart работает — сообщаем ему. Если приложение спит
     * и выгружено — поднимаем мотор: при запуске он регистрируется на АТС уже с новым адресом. Иначе АТС
     * будила бы телефон по старому адресу, то есть не будила бы вовсе, пока приложение не откроют руками.
     * Фоновую службу тоже пробуем поднять; Android может не разрешить это из фона — тогда обходимся без неё.
     */
    fun pushTokenChanged(app: Context) {
        main.post {
            val running = channel != null
            get(app)
            if (running) {
                channel?.invokeMethod("pushToken", null)
            } else {
                CallService.start(app, CallService.MODE_STANDBY, title = "SADO", text = "")
            }
        }
    }

    /** Сообщение в Dart: «hangUp» или «accept» (кнопки в уведомлении); при необходимости — с одним значением. */
    fun send(method: String, argument: Any? = null) {
        main.post { channel?.invokeMethod(method, argument) }
    }

    private fun handle(app: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "standby", "show", "ring" -> {
                // Спрашиваем разрешение на уведомления сразу, как только приложение вышло на связь: мелодия
                // и показ входящего идут через уведомление, и без разрешения первый же звонок был бы беззвучным.
                activity?.get()?.askForNotifications()
                CallService.start(
                    app,
                    mode = call.method,
                    title = call.argument<String>("title") ?: "SADO",
                    text = call.argument<String>("text") ?: "",
                    primary = call.argument<String>("primary") ?: "",
                    secondary = call.argument<String>("secondary") ?: "",
                    silent = call.argument<Boolean>("silent") ?: false,
                )
                result.success(null)
            }
            "missed" -> {
                MissedCalls.show(app, call.argument<String>("title") ?: "", call.argument<String>("text") ?: "")
                result.success(null)
            }
            "clearMissed" -> {
                MissedCalls.clear(app)
                result.success(null)
            }
            "hide" -> {
                CallService.stop(app)
                setProximity(app, false)
                result.success(null)
            }
            "proximity" -> {
                setProximity(app, call.arguments as? Boolean ?: false)
                result.success(null)
            }
            "lockScreen" -> {
                activity?.get()?.setOverLockScreen(call.arguments as? Boolean ?: false)
                result.success(null)
            }
            "ringSettings" -> result.success(IncomingRing.state(app))
            "pickRingtone" -> pickRingtone(app, result)
            "scanQr" -> scanQr(call.argument<String>("hint") ?: "", call.argument<String>("close") ?: "", result)
            "setRingVibration" -> {
                IncomingRing.setVibrate(app, call.arguments as? Boolean ?: true)
                result.success(IncomingRing.state(app))
            }
            "batteryUnrestricted" -> result.success(batteryUnrestricted(app))
            "askBattery" -> {
                askBatteryExemption(app)
                result.success(null)
            }
            "hasAutostart" -> result.success(hasAutostartSettings())
            "openAutostart" -> {
                openAutostartSettings(app)
                result.success(null)
            }
            "notificationsAllowed" ->
                result.success(app.getSystemService(NotificationManager::class.java).areNotificationsEnabled())
            "openNotifications" -> {
                openNotificationSettings(app)
                result.success(null)
            }
            "canFullScreen" -> result.success(canFullScreen(app))
            "openFullScreen" -> {
                openFullScreenSettings(app)
                result.success(null)
            }
            "takePendingDial" -> {
                val number = pendingDial
                pendingDial = null
                result.success(number)
            }
            "takePendingSetup" -> {
                val link = pendingSetup
                pendingSetup = null
                result.success(link)
            }
            "pushInfo" -> Push.info(app) { info -> main.post { result.success(info) } }
            "takePushWake" -> {
                // «Будили недавно» — в пределах минуты: более старый push уже не про текущий звонок.
                val at = pushWokeAt
                pushWokeAt = 0L
                result.success(at != 0L && android.os.SystemClock.elapsedRealtime() - at < 60_000)
            }
            "appIcon" -> result.success(appIcon(app))
            "setAppIcon" -> {
                setAppIcon(app, call.arguments as? String ?: "")
                result.success(null)
            }
            "openUrl" -> {
                // Открываем только страницы своего репозитория: адрес пришёл из ответа сервера,
                // и подменённая ссылка не должна увести человека на чужой сайт.
                val url = call.arguments as? String ?: ""
                if (url.startsWith("https://github.com/dark-knight-soul/sado-softphone/")) {
                    try {
                        app.startActivity(
                            Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    } catch (e: Exception) {
                        // На телефоне нет браузера — молча ничего не делаем, приложение не падает.
                    }
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Ответ Dart, ждущий закрытия системного окна выбора мелодии. Хранится здесь, а не в окне приложения:
     * пока открыт выбор, Android может пересоздать окно, а результат придёт уже новому.
     */
    private var ringtoneResult: MethodChannel.Result? = null

    /** Ответ Dart, ждущий закрытия сканера QR-кода (хранится здесь по той же причине, что и [ringtoneResult]). */
    private var scanResult: MethodChannel.Result? = null

    /** Открывает сканер QR-кода; ответ Dart — словарь «status» (ok, cancelled, denied) и «text». */
    private fun scanQr(hint: String, close: String, result: MethodChannel.Result) {
        // Прошлый вопрос остался без ответа — закрываем его, чтобы Dart не ждал вечно.
        scanResult?.success(mapOf("status" to "cancelled"))
        scanResult = result
        // Экран сканера открыть не удалось (нет окна приложения) — это не отказ в камере: отвечаем
        // «сканера нет», и приложение подскажет навести обычную камеру телефона.
        if (activity?.get()?.scanQr(hint, close) != true) qrScanned("unavailable", null)
    }

    /** Сканер закрылся. Ответ Dart отправляется ровно один раз. */
    fun qrScanned(status: String, text: String?) {
        val result = scanResult ?: return
        scanResult = null
        result.success(mapOf("status" to status, "text" to text))
    }

    /** Открывает системный выбор мелодии звонка; ответ Dart — состояние после закрытия окна. */
    private fun pickRingtone(app: Context, result: MethodChannel.Result) {
        val window = activity?.get()
        if (window == null) {
            // Без окна выбор не открыть — возвращаем всё как есть.
            result.success(IncomingRing.state(app))
            return
        }
        // Прошлый вопрос почему-то остался без ответа — отвечаем на него, чтобы Dart не ждал вечно.
        ringtoneResult?.success(IncomingRing.state(app))
        ringtoneResult = result
        if (!window.pickRingtone(IncomingRing.chosenUri(app))) ringtonePicked(app, picked = false, uri = null)
    }

    /**
     * Окно выбора мелодии закрылось. [picked] — человек что-то выбрал (а не нажал «Назад»);
     * [uri] null или системный адрес — «как в телефоне». Ответ Dart отправляется ровно один раз.
     */
    fun ringtonePicked(app: Context, picked: Boolean, uri: Uri?) {
        val result = ringtoneResult ?: return
        ringtoneResult = null
        if (picked) IncomingRing.setRingtone(app, uri)
        result.success(IncomingRing.state(app))
    }

    /** Гасит экран, когда телефон у уха, чтобы щека не нажимала кнопки. */
    private fun setProximity(app: Context, on: Boolean) {
        if (on) {
            if (proximityLock?.isHeld == true) return
            val power = app.getSystemService(PowerManager::class.java)
            if (!power.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) return
            proximityLock = power.newWakeLock(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "sado:proximity").apply {
                setReferenceCounted(false)
                acquire(4 * 60 * 60 * 1000L)
            }
        } else {
            proximityLock?.let { if (it.isHeld) it.release() }
            proximityLock = null
        }
    }

    /**
     * Свои экраны «работа в фоне» у разных производителей. Пока запрет там не снят, телефон выгружает
     * приложение из памяти и не даёт ему подняться снова — входящие перестают доходить.
     * Узнать, снят ли запрет, обычному приложению нельзя, можно только открыть нужный экран.
     * Для каждого производителя — несколько вариантов: у разных версий прошивки экран называется по-разному.
     */
    private val backgroundScreens: Map<String, List<Pair<String, String>>> = mapOf(
        // Xiaomi, Redmi, POCO: «Автозапуск».
        "xiaomi" to listOf("com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity"),
        // Samsung: «Батарея» → «Ограничения в фоновом режиме» → «Приложения, которые никогда не спят».
        "samsung" to listOf(
            "com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity",
            "com.samsung.android.lool" to "com.samsung.android.sm.ui.battery.BatteryActivity",
            "com.samsung.android.sm" to "com.samsung.android.sm.ui.battery.BatteryActivity",
        ),
        // Huawei и Honor: «Запуск приложений».
        "huawei" to listOf(
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
            "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
        ),
        // Oppo, Realme, OnePlus: «Автозапуск».
        "oppo" to listOf(
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
            "com.oplus.battery" to "com.oplus.startupapp.view.StartupAppListActivity",
            "com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
        ),
        // Vivo и iQOO: «Автозапуск».
        "vivo" to listOf(
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
        ),
        // Tecno, Infinix, Itel.
        "transsion" to listOf("com.transsion.phonemaster" to "com.cyin.himgr.autostart.AutoStartActivity"),
        // Asus.
        "asus" to listOf("com.asus.mobilemanager" to "com.asus.mobilemanager.autostart.AutoStartActivity"),
    )

    /** К какой «семье» прошивок относится телефон; null — обычный Android без своих запретов. */
    private fun vendorFamily(): String? {
        val maker = Build.MANUFACTURER.lowercase()
        return when {
            maker in setOf("xiaomi", "redmi", "poco") -> "xiaomi"
            maker == "samsung" -> "samsung"
            maker in setOf("huawei", "honor") -> "huawei"
            maker in setOf("oppo", "realme", "oneplus") -> "oppo"
            maker in setOf("vivo", "iqoo") -> "vivo"
            maker.startsWith("tecno") || maker.startsWith("infinix") || maker.startsWith("itel") -> "transsion"
            maker == "asus" -> "asus"
            else -> null
        }
    }

    private fun hasAutostartSettings(): Boolean = vendorFamily() != null

    private fun openAutostartSettings(app: Context) {
        val from = activity?.get() ?: app
        for ((pkg, cls) in backgroundScreens[vendorFamily()].orEmpty()) {
            try {
                from.startActivity(Intent().setComponent(ComponentName(pkg, cls)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return
            } catch (e: Exception) {
                // Такого экрана в этой версии прошивки нет — пробуем следующий.
            }
        }
        openAppDetails(app)
    }

    /** Страница приложения в системных настройках — запасной путь, когда особого экрана нет. */
    private fun openAppDetails(app: Context) {
        try {
            app.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${app.packageName}"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (ignored: Exception) {
        }
    }

    /** Системный экран с уведомлениями приложения — если человек когда-то запретил их. */
    private fun openNotificationSettings(app: Context) {
        try {
            (activity?.get() ?: app).startActivity(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, app.packageName)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (e: Exception) {
            openAppDetails(app)
        }
    }

    /**
     * Можно ли показывать экран звонка поверх экрана блокировки. С Android 14 это отдельное разрешение,
     * и у приложений не из магазина оно бывает выключено — тогда при входящем видна только плашка уведомления.
     */
    private fun canFullScreen(app: Context): Boolean =
        Build.VERSION.SDK_INT < 34 || app.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()

    private fun openFullScreenSettings(app: Context) {
        if (Build.VERSION.SDK_INT < 34) return
        try {
            (activity?.get() ?: app).startActivity(
                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:${app.packageName}"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (e: Exception) {
            openAppDetails(app)
        }
    }

    // ---- Значок на рабочем столе ----

    /** Имена значков; у каждого в манифесте свой «псевдоним» главного окна (IconEmerald, IconNight…). */
    private val appIcons = listOf("emerald", "night", "air", "sunset", "cupertino", "material", "sado", "sadodark")

    private fun iconAlias(app: Context, name: String) =
        ComponentName(app, "uz.sado.app.Icon${name.replaceFirstChar { it.uppercase() }}")

    private fun appIcon(app: Context): String {
        val pm = app.packageManager
        for (name in appIcons) {
            val state = pm.getComponentEnabledSetting(iconAlias(app, name))
            val on = state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                // «По умолчанию» означает «как в манифесте», а там включён только первый.
                (state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && name == appIcons.first())
            if (on) return name
        }
        return appIcons.first()
    }

    private fun setAppIcon(app: Context, name: String) {
        if (name !in appIcons) return
        val pm = app.packageManager
        // Сначала включаем новый значок, потом выключаем остальные — чтобы ни на миг не остаться без значка.
        pm.setComponentEnabledSetting(
            iconAlias(app, name),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for (other in appIcons) {
            if (other == name) continue
            pm.setComponentEnabledSetting(
                iconAlias(app, other),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }

    private fun batteryUnrestricted(app: Context): Boolean =
        app.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(app.packageName)

    /**
     * Открывает системное окно «Разрешить работу в фоне без ограничений». Без этого телефон в глубоком сне
     * отключает приложению сеть, и входящие перестают доходить.
     */
    private fun askBatteryExemption(app: Context) {
        if (batteryUnrestricted(app)) return
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${app.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            (activity?.get() ?: app).startActivity(intent)
        } catch (e: Exception) {
            // На некоторых прошивках такого окна нет — тогда открываем общий список.
            try {
                app.startActivity(
                    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            } catch (ignored: Exception) {
            }
        }
    }
}
