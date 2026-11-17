package uz.sado.app

import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.LuminanceSource
import com.google.zxing.PlanarYUVLuminanceSource
import com.google.zxing.ReaderException
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeReader
import java.nio.ByteBuffer

/**
 * Разбор QR-кода из кадра камеры (библиотека ZXing, всё происходит на телефоне).
 *
 * Отдельно от экрана сканера, чтобы разбор можно было проверить обычным тестом без камеры.
 */
object QrDecoder {
    private val hints = mapOf(
        DecodeHintType.POSSIBLE_FORMATS to listOf(BarcodeFormat.QR_CODE),
        DecodeHintType.CHARACTER_SET to "UTF-8",
    )

    /** Длиннее текст из кода не отдаём: ссылка настройки короче, а всё остальное нам не нужно. */
    private const val MAX_TEXT = 2000

    /**
     * Собирает яркость кадра в сплошной массив [width]×[height].
     * В кадре камеры строка может быть длиннее ширины ([rowStride]) — хвосты строк отбрасываем.
     * [reuse] — массив от прошлого кадра: если он подходит по размеру, пишем в него, чтобы не выделять
     * почти мегабайт памяти на каждый кадр.
     */
    fun luminance(plane: ByteBuffer, rowStride: Int, width: Int, height: Int, reuse: ByteArray? = null): ByteArray {
        val data = if (reuse != null && reuse.size == width * height) reuse else ByteArray(width * height)
        val start = plane.position()
        if (rowStride == width) {
            plane.get(data, 0, minOf(plane.remaining(), data.size))
        } else {
            for (row in 0 until height) {
                plane.position(start + row * rowStride)
                plane.get(data, row * width, minOf(width, plane.remaining()))
            }
        }
        return data
    }

    /**
     * Ищет QR-код в кадре; [luminance] — яркость точек построчно. Возвращает текст кода или null.
     * [inverted] — искать светлый код на тёмном фоне (экран в тёмной теме, печать «наоборот»).
     */
    fun decode(luminance: ByteArray, width: Int, height: Int, inverted: Boolean = false): String? {
        if (width <= 0 || height <= 0 || luminance.size < width * height) return null
        val source: LuminanceSource = PlanarYUVLuminanceSource(luminance, width, height, 0, 0, width, height, false)
        val text = try {
            QRCodeReader().decode(BinaryBitmap(HybridBinarizer(if (inverted) source.invert() else source)), hints).text
        } catch (e: ReaderException) {
            null // кода в кадре нет или он не читается — ждём следующий кадр
        }
        return text?.takeIf { it.isNotEmpty() && it.length <= MAX_TEXT }
    }
}
