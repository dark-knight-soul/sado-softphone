package uz.sado.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
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

        /** Окно приложения сейчас на экране. Тогда входящий показывает само приложение, без всплывающего уведомления. */
        @Volatile
        var visible = false
    }

    override fun onStart() {
        super.onStart()
        visible = true
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
        // Отвечать на звонок и показывать окно поверх блокировки просит только наше же уведомление.
        // Намерение без метки (от другого приложения или от рабочего стола) просто открывает окно.
        if (intent.getStringExtra(EXTRA_TOKEN) != CallService.intentToken) return
        // То же, если окно открыли из списка недавних приложений: система подставляет прежнее намерение.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val accept = intent.action == ACTION_ACCEPT
        if (accept || intent.getBooleanExtra(EXTRA_RING, false)) setOverLockScreen(true)
        if (accept) SadoEngine.send("accept")
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

    override fun onDestroy() {
        if (SadoEngine.activity?.get() === this) SadoEngine.activity = null
        super.onDestroy()
    }
}
