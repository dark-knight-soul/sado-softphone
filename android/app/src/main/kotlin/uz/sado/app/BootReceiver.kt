package uz.sado.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Запускает приложение в фоне после включения телефона и после обновления самого приложения,
 * чтобы оно вышло на связь с АТС без открытия вручную.
 *
 * Здесь только поднимается служба в режиме ожидания. Нужно ли оставаться на связи, решает код Dart
 * (вошёл ли человек, включены ли «Звонки в фоне»): если нет — он сам остановит службу.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON" ->
                CallService.start(context, CallService.MODE_STANDBY, title = "SADO", text = "")
        }
    }
}
