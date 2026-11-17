package uz.sado.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.os.Bundle
import android.util.Size
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Сканер QR-кода для входа: показывает камеру и закрывается, как только в кадре прочитан код.
 *
 * Кадры разбираются на телефоне ([QrDecoder]) и никуда не сохраняются и не отправляются.
 * Камера работает, только пока открыт этот экран. Надписи приходят из приложения — на его языке.
 *
 * Итог: [RESULT_OK] и текст кода в [EXTRA_TEXT]; [RESULT_CANCELED] — человек закрыл экран;
 * [RESULT_NO_CAMERA] — камеры нет или к ней не дали доступ.
 */
class ScanActivity : ComponentActivity() {
    companion object {
        const val EXTRA_HINT = "hint"
        const val EXTRA_CLOSE = "close"
        const val EXTRA_TEXT = "text"
        const val RESULT_NO_CAMERA = RESULT_FIRST_USER

        private const val REQUEST_CAMERA = 1

        /** Какой размер кадра просим для разбора: хватает и для плотного кода, и разбирается быстро. */
        private val ANALYSIS_SIZE = Size(1280, 720)
    }

    private lateinit var preview: PreviewView
    private var analysisExecutor: ExecutorService? = null

    /** Код уже прочитан (или экран закрывается) — остальные кадры пропускаем. */
    @Volatile
    private var done = false

    /** Яркость прошлого кадра: массив переиспользуется (кадры разбирает один поток). */
    private var frame: ByteArray? = null

    /** Счётчик кадров: каждый третий проверяем ещё и «наоборот» (светлый код на тёмном фоне). */
    private var frames = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildContent())
        if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            startCamera()
        } else {
            requestPermissions(arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CAMERA) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) startCamera() else finishWithoutCamera()
    }

    override fun onDestroy() {
        done = true
        analysisExecutor?.shutdown()
        super.onDestroy()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    /** Экран: камера во весь экран, рамка-прицел, подсказка снизу и кнопка закрытия сверху. */
    private fun buildContent(): View {
        val root = FrameLayout(this)
        root.setBackgroundColor(Color.BLACK)

        preview = PreviewView(this)
        preview.scaleType = PreviewView.ScaleType.FILL_CENTER
        root.addView(preview, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        root.addView(FrameOverlay(this), FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))

        val hint = TextView(this)
        hint.text = intent.getStringExtra(EXTRA_HINT) ?: ""
        hint.setTextColor(Color.WHITE)
        hint.textSize = 16f
        hint.gravity = Gravity.CENTER
        hint.setShadowLayer(6f, 0f, 1f, Color.BLACK)
        hint.setPadding(dp(24), dp(12), dp(24), dp(12))
        val hintParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM,
        )
        root.addView(hint, hintParams)

        // Кнопка закрытия — надписью («Отмена» на языке приложения): так не нужен отдельный значок.
        val close = TextView(this)
        close.text = intent.getStringExtra(EXTRA_CLOSE) ?: "✕"
        close.setTextColor(Color.WHITE)
        close.textSize = 16f
        close.gravity = Gravity.CENTER
        close.setShadowLayer(6f, 0f, 1f, Color.BLACK)
        close.setPadding(dp(20), dp(14), dp(20), dp(14))
        close.isClickable = true
        close.isFocusable = true
        close.setOnClickListener { finish() }
        val closeParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.START,
        )
        root.addView(close, closeParams)

        // Экран рисуется под строкой состояния и полосой навигации — отодвигаем от них надписи.
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            closeParams.setMargins(bars.left, bars.top, 0, 0)
            close.layoutParams = closeParams
            hintParams.setMargins(bars.left, 0, bars.right, bars.bottom + dp(40))
            hint.layoutParams = hintParams
            insets
        }
        return root
    }

    private fun startCamera() {
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            try {
                val provider = future.get()
                val previewCase = Preview.Builder().build()
                previewCase.surfaceProvider = preview.surfaceProvider
                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setResolutionSelector(
                        ResolutionSelector.Builder()
                            .setResolutionStrategy(
                                ResolutionStrategy(ANALYSIS_SIZE, ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER),
                            )
                            .build(),
                    )
                    .build()
                val executor = Executors.newSingleThreadExecutor()
                analysisExecutor = executor
                analysis.setAnalyzer(executor, ::analyze)
                provider.unbindAll()
                // Обычно код снимают задней камерой; на устройстве только с передней (планшет) берём её.
                val camera = if (provider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)) {
                    CameraSelector.DEFAULT_BACK_CAMERA
                } else {
                    CameraSelector.DEFAULT_FRONT_CAMERA
                }
                provider.bindToLifecycle(this, camera, previewCase, analysis)
            } catch (e: Exception) {
                // Камеры нет, она занята другим приложением или не открылась.
                finishWithoutCamera()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    /** Разбирает один кадр (в своём потоке, не в потоке экрана). */
    private fun analyze(image: ImageProxy) {
        image.use {
            if (done) return
            val plane = image.planes.firstOrNull() ?: return
            val data = QrDecoder.luminance(plane.buffer, plane.rowStride, image.width, image.height, frame)
            frame = data
            val inverted = ++frames % 3 == 0
            val text = QrDecoder.decode(data, image.width, image.height, inverted) ?: return
            done = true
            runOnUiThread {
                setResult(RESULT_OK, Intent().putExtra(EXTRA_TEXT, text))
                finish()
            }
        }
    }

    private fun finishWithoutCamera() {
        done = true
        setResult(RESULT_NO_CAMERA)
        finish()
    }

    /** Затемнение с прозрачным квадратом посередине и светлой рамкой — куда наводить код. */
    private class FrameOverlay(context: Context) : View(context) {
        private val dim = Paint().apply { color = Color.argb(120, 0, 0, 0) }
        private val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = 3f * resources.displayMetrics.density
        }
        private val path = Path()
        private val window = RectF()

        override fun onDraw(canvas: Canvas) {
            val side = minOf(width, height) * 0.72f
            val left = (width - side) / 2f
            val top = (height - side) / 2f
            val radius = 20f * resources.displayMetrics.density
            window.set(left, top, left + side, top + side)
            path.reset()
            path.fillType = Path.FillType.EVEN_ODD
            path.addRect(0f, 0f, width.toFloat(), height.toFloat(), Path.Direction.CW)
            path.addRoundRect(window, radius, radius, Path.Direction.CW)
            canvas.drawPath(path, dim)
            canvas.drawRoundRect(window, radius, radius, border)
        }
    }
}
