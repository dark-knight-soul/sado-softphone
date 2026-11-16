package uz.sado.app

import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.common.BitMatrix
import com.google.zxing.qrcode.QRCodeWriter
import java.nio.ByteBuffer
import java.util.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Разбор QR-кода без камеры: рисуем код со ссылкой настройки в «кадр» (яркость точек, как её отдаёт камера)
 * и проверяем, что [QrDecoder] читает его в разных условиях.
 */
class QrDecoderTest {
    private val link =
        "sado://login?server=pbx.example.com%3A8089%2Fws&number=1003&password=use-a-long-random-password"

    private val width = 1280
    private val height = 720

    /** Поворачивает рисунок кода на четверть оборота. */
    private fun rotated(m: BitMatrix): BitMatrix {
        val r = BitMatrix(m.height, m.width)
        for (y in 0 until m.height) for (x in 0 until m.width) if (m.get(x, y)) r.set(m.height - 1 - y, x)
        return r
    }

    /**
     * Кадр [width]×[height] со строками длиной [rowStride]: серый фон с шумом и код в стороне от центра.
     * [scale] — точек кадра на клетку кода; [inverted] — светлый код на тёмном фоне; [turns] — повороты на 90°.
     */
    private fun frame(
        text: String?,
        scale: Int = 6,
        rowStride: Int = width,
        inverted: Boolean = false,
        turns: Int = 0,
    ): ByteBuffer {
        val random = Random(7)
        val light = if (inverted) 40 else 205
        val dark = if (inverted) 215 else 35
        val data = ByteArray(rowStride * height)
        for (y in 0 until height) for (x in 0 until rowStride) data[y * rowStride + x] = (light + random.nextInt(21) - 10).toByte()
        if (text != null) {
            // Кодируем в UTF-8, как это делают обычные генераторы QR-кодов.
            var matrix = QRCodeWriter().encode(
                text, BarcodeFormat.QR_CODE, 0, 0, mapOf(EncodeHintType.CHARACTER_SET to "UTF-8"),
            )
            repeat(turns) { matrix = rotated(matrix) }
            val left = 300
            val top = 90
            for (my in 0 until matrix.height) for (mx in 0 until matrix.width) {
                // Поле вокруг кода (в рисунке оно «пустое») остаётся цвета фона.
                if (!matrix.get(mx, my)) continue
                for (dy in 0 until scale) for (dx in 0 until scale) {
                    val x = left + mx * scale + dx
                    val y = top + my * scale + dy
                    if (x < width && y < height) data[y * rowStride + x] = (dark + random.nextInt(21) - 10).toByte()
                }
            }
        }
        return ByteBuffer.wrap(data)
    }

    private fun read(buffer: ByteBuffer, rowStride: Int = width, inverted: Boolean = false): String? =
        QrDecoder.decode(QrDecoder.luminance(buffer, rowStride, width, height), width, height, inverted)

    @Test
    fun readsSetupLink() {
        assertEquals(link, read(frame(link)))
    }

    @Test
    fun readsSmallCode() {
        // Код далеко от камеры: три точки кадра на клетку.
        assertEquals(link, read(frame(link, scale = 3)))
    }

    @Test
    fun readsFrameWithPaddedRows() {
        // У многих камер строка кадра длиннее его ширины.
        assertEquals(link, read(frame(link, rowStride = 1344), rowStride = 1344))
    }

    @Test
    fun readsRotatedCode() {
        assertEquals(link, read(frame(link, turns = 1)))
        assertEquals(link, read(frame(link, turns = 2)))
    }

    @Test
    fun readsLightCodeOnDarkBackgroundWhenAsked() {
        assertEquals(link, read(frame(link, inverted = true), inverted = true))
    }

    @Test
    fun readsNonLatinText() {
        val text = "sado://login?server=pbx.example.com&number=1003#Офис на Чиланзаре"
        assertEquals(text, read(frame(text)))
    }

    @Test
    fun emptyFrameGivesNothing() {
        assertNull(read(frame(null)))
        assertNull(read(frame(null), inverted = true))
    }

    @Test
    fun brokenInputGivesNothing() {
        assertNull(QrDecoder.decode(ByteArray(10), width, height))
        assertNull(QrDecoder.decode(ByteArray(0), 0, 0))
    }
}
