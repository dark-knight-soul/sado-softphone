package uz.sado.app

import android.content.Context

/**
 * Push-уведомления — в этой сборке («foss», без сервисов Google) их нет.
 *
 * Тот же объект с настоящей работой лежит в сборке «gms» (src/gms). Приложение спрашивает [info]
 * и, получив null, остаётся на постоянной связи с АТС, как и раньше.
 */
object Push {
    /** Сведения для АТС: кому и как слать push. Здесь всегда null — слать некуда. */
    fun info(context: Context, done: (Map<String, String>?) -> Unit) = done(null)
}
