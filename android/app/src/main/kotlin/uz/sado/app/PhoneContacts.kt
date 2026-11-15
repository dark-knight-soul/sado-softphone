package uz.sado.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

/**
 * Адресная книга телефона, только чтение. Свой канал, чтобы не смешиваться с каналом звонков.
 * Контакты никуда не копируются: Dart читает их каждый раз заново и держит только в памяти.
 */
object PhoneContacts {
    private const val CHANNEL = "uz.sado.app/contacts"

    /** Больше строк в списке не нужно: так огромная книга не раздует память и не затянет чтение. */
    private const val MAX_ROWS = 5000

    private val main = Handler(Looper.getMainLooper())

    fun register(app: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "granted" -> result.success(granted(app))
                "request" -> {
                    // Диалог разрешения можно показать только из окна; без окна просто отвечаем «нет».
                    val activity = SadoEngine.activity?.get()
                    if (activity == null) result.success(false) else activity.requestContacts { result.success(it) }
                }
                "list" -> {
                    // Чтение книги может быть долгим, поэтому не в основном потоке.
                    thread {
                        val rows = try {
                            read(app)
                        } catch (e: Exception) {
                            emptyList()
                        }
                        main.post { result.success(rows) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun granted(app: Context): Boolean =
        app.checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED

    private fun read(app: Context): List<Map<String, String>> {
        if (!granted(app)) return emptyList()
        val rows = ArrayList<Map<String, String>>()
        val columns = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
        )
        app.contentResolver.query(ContactsContract.CommonDataKinds.Phone.CONTENT_URI, columns, null, null, null)
            ?.use { cursor ->
                while (cursor.moveToNext() && rows.size < MAX_ROWS) {
                    val number = cursor.getString(1)?.trim().orEmpty()
                    if (number.isEmpty()) continue
                    rows.add(mapOf("name" to (cursor.getString(0) ?: ""), "number" to number))
                }
            }
        return rows
    }
}
