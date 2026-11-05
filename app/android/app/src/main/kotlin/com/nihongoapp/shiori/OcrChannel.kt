package com.nihongoapp.shiori

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.exifinterface.media.ExifInterface
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import kotlin.math.roundToLong
import java.util.concurrent.atomic.AtomicBoolean

/**
 * ML Kit OCR behind the Dart `TextRecognizer` port (PlatformTextRecognizer).
 *
 * `recognize(path)` runs the Japanese recognizer, then the Korean one (both bundled, on device), on
 * the same image and returns `{"ja": OcrPage, "ko": OcrPage, "turned": degrees, "timing": {...}}`
 * JSON, the shape of the iOS Vision channel: lines with t, c, x, y, w, h normalized to the upright
 * image, origin top-left. The lines are pieces (OcrGeometry.segments), not ML Kit lines.
 *
 * Upright: the EXIF rotation goes in with the bitmap; then, if the Japanese pass's line angles say
 * the text still lies sideways or upside down (a photo taken from above has no rotation in EXIF),
 * the boxes are turned. ML Kit reads turned text well, so no second read is needed.
 */
class OcrChannel : MethodChannel.MethodCallHandler {
    companion object {
        const val NAME = "shiori/ocr"
        private const val TAG = "ShioriOcr"

        /** Longest side handed to ML Kit; 12 MP phone photos pass unscaled. */
        private const val MAX_SIDE = 4096

        /** One recognizer pass may take this long before the photo is given up. */
        private const val PASS_TIMEOUT_S = 60L

        /** After a failure, how long to wait for a pass still reading the pixels. */
        private const val DRAIN_TIMEOUT_S = 30L

        /** Confidence written for a piece ML Kit gave none (NaN). */
        private const val UNKNOWN_CONFIDENCE = 0.5

        /** Same precision as the recorded passes (4 decimals). */
        private fun round4(v: Double) = (v * 10_000).roundToLong() / 10_000.0
    }

    // One job at a time: a second photo waits instead of doubling peak memory.
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val disposed = AtomicBoolean(false)
    private val japanese: TextRecognizer =
        TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build())
    private val korean: TextRecognizer =
        TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "recognize") {
            result.notImplemented()
            return
        }
        val path = call.argument<String>("path")
        if (path.isNullOrBlank()) {
            result.error("bad_args", "path is required", null)
            return
        }
        try {
            executor.execute { reply(result) { recognize(path) } }
        } catch (e: RejectedExecutionException) {
            result.error("ocr_failed", "OCR channel is shutting down", null)
        }
    }

    /**
     * Closes the recognizers after any job already queued, so a running
     * `process()` never sees a closed client. Later calls are refused.
     */
    fun dispose() {
        if (!disposed.compareAndSet(false, true)) return
        try {
            executor.execute {
                japanese.close()
                korean.close()
            }
        } catch (e: RejectedExecutionException) {
            Log.w(TAG, "dispose after shutdown", e)
        }
        executor.shutdown()
    }

    private fun reply(result: MethodChannel.Result, work: () -> String) {
        val outcome = try {
            if (disposed.get()) {
                Outcome.Failed("ocr_failed", "OCR channel was closed")
            } else {
                Outcome.Ok(work())
            }
        } catch (e: BadImageException) {
            Outcome.Failed("bad_image", e.message ?: "bad image")
        } catch (e: OcrTimeoutException) {
            Outcome.Failed("ocr_failed", e.message ?: "timeout")
        } catch (e: OutOfMemoryError) {
            // A huge photo: report it instead of taking the whole app down.
            Outcome.Failed("bad_image", "image too large to read")
        } catch (e: Throwable) {
            // Anything else still answers the call, so the Dart side never waits forever.
            Log.e(TAG, "recognize failed", e)
            Outcome.Failed("ocr_failed", e.message ?: e.javaClass.simpleName)
        }
        main.post {
            when (outcome) {
                is Outcome.Ok -> result.success(outcome.json)
                is Outcome.Failed -> result.error(outcome.code, outcome.message, null)
            }
        }
    }

    private fun recognize(path: String): String {
        val decodeStarted = System.nanoTime()
        val (bitmap, rotation) = loadDownsampled(File(path))
        val decodeMs = (System.nanoTime() - decodeStarted) / 1_000_000
        val running = mutableListOf<Task<Text>>()
        try {
            // ML Kit applies the rotation; boxes come back in the rotated frame,
            // whose width and height swap for 90° and 270°.
            val image = InputImage.fromBitmap(bitmap, rotation)
            val upright = rotation % 180 == 0
            val width = (if (upright) bitmap.width else bitmap.height).toDouble()
            val height = (if (upright) bitmap.height else bitmap.width).toDouble()
            // One after the other: the line angles of the Japanese pass decide the turn, and the two
            // models are not both held in memory at the peak.
            val (ja, jaMs) = pass(japanese, image, running)
            val (ko, koMs) = pass(korean, image, running)
            val jaLines = lines(ja)
            val turns = OcrGeometry.textTurns(jaLines, rotation)
            return JSONObject()
                .put("ja", page(jaLines, turns, width, height, "ja", jaMs))
                .put("ko", page(lines(ko), turns, width, height, "ko", koMs))
                .put("turned", turns * 90)
                .put("timing", JSONObject().put("decode", decodeMs).put("exif_rotation", rotation))
                .toString()
        } finally {
            // A pass that failed or timed out may still be reading the pixels.
            for (task in running) {
                if (task.isComplete) continue
                try {
                    Tasks.await(task, DRAIN_TIMEOUT_S, TimeUnit.SECONDS)
                } catch (e: InterruptedException) {
                    Thread.currentThread().interrupt()
                    break
                } catch (e: Exception) {
                    Log.w(TAG, "pass ended with an error", e)
                }
            }
            // Free the pixels only when no pass can still read them.
            if (running.all { it.isComplete }) {
                bitmap.recycle()
            } else {
                Log.w(TAG, "a pass is still running; the bitmap is left to the garbage collector")
            }
        }
    }

    private fun pass(recognizer: TextRecognizer, image: InputImage, running: MutableList<Task<Text>>): Pair<Text, Long> {
        val started = System.nanoTime()
        val task = recognizer.process(image).also { running.add(it) }
        val text = try {
            Tasks.await(task, PASS_TIMEOUT_S, TimeUnit.SECONDS)
        } catch (e: TimeoutException) {
            throw OcrTimeoutException("a recognizer pass took longer than $PASS_TIMEOUT_S s")
        }
        return text to (System.nanoTime() - started) / 1_000_000
    }

    /** Decodes [file] at most [MAX_SIDE] on its longest side and reads its EXIF rotation. */
    private fun loadDownsampled(file: File): Pair<Bitmap, Int> {
        if (!file.exists()) throw BadImageException("cannot open ${file.path}")
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            throw BadImageException("not an image: ${file.path}")
        }
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > MAX_SIDE) sample *= 2
        val bitmap = BitmapFactory.decodeFile(
            file.path,
            BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: throw BadImageException("cannot decode ${file.path}")
        // The androidx reader works around vendor EXIF bugs; mirrored photos keep their rotation only.
        val rotation = try {
            ExifInterface(file.path).rotationDegrees
        } catch (e: java.io.IOException) {
            Log.w(TAG, "no readable EXIF in ${file.name}; reading it as stored", e)
            0
        }
        return bitmap to rotation
    }

    private fun lines(text: Text): List<OcrGeometry.Line> = text.textBlocks.flatMap { block ->
        block.lines.map { line ->
            OcrGeometry.Line(
                text = line.text,
                box = line.boundingBox.toBox(),
                confidence = line.confidence.toConfidence(),
                angle = line.angle.toDouble(),
                elements = line.elements.map { e ->
                    OcrGeometry.Element(
                        text = e.text,
                        box = e.boundingBox.toBox(),
                        confidence = e.confidence.toConfidence(),
                        symbols = e.symbols.map { s ->
                            OcrGeometry.Symbol(s.text, s.boundingBox.toBox(), s.confidence.toConfidence())
                        },
                    )
                },
            )
        }
    }

    private fun Rect?.toBox() = this?.let {
        OcrGeometry.Box(it.left.toDouble(), it.top.toDouble(), it.right.toDouble(), it.bottom.toDouble())
    }

    private fun Float.toConfidence(): Double? = if (isFinite()) toDouble() else null

    private fun page(
        lines: List<OcrGeometry.Line>,
        turns: Int,
        width: Double,
        height: Double,
        tag: String,
        ms: Long,
    ): JSONObject {
        val (upright, w, h) = OcrGeometry.turned(lines, turns, width, height)
        val out = JSONArray()
        var dropped = 0
        var lostGlyphs = 0
        var noConfidence = 0
        for (line in upright) {
            val pieces = OcrGeometry.segments(line)
            if (pieces.isEmpty()) dropped++
            lostGlyphs += OcrGeometry.glyphsWithoutBox(line)
            for (p in pieces) {
                if (p.confidence == null) noConfidence++
                out.put(
                    JSONObject()
                        .put("t", p.text)
                        // Not measured: neither certain (1.0 would pass every confidence rule)
                        // nor garbage (0.0 would drop real text).
                        .put("c", round4(p.confidence ?: UNKNOWN_CONFIDENCE))
                        .put("x", round4(p.box.left / w))
                        .put("y", round4(p.box.top / h))
                        .put("w", round4((p.box.right - p.box.left) / w))
                        .put("h", round4(p.box.height / h)),
                )
            }
        }
        if (dropped > 0) Log.w(TAG, "$tag pass: $dropped lines without a box were dropped")
        if (lostGlyphs > 0) Log.w(TAG, "$tag pass: $lostGlyphs glyphs without a box were left out")
        if (noConfidence > 0) Log.w(TAG, "$tag pass: $noConfidence pieces had no confidence")
        return JSONObject()
            .put("engine", "mlkit")
            // A label of the recognizer used (script + Latin), not a setting:
            // ML Kit picks languages by recognizer, unlike Vision's language list.
            .put("langs", JSONArray(listOf(tag, "en")))
            .put("ms", ms)
            .put("dropped", dropped)
            .put("lost_glyphs", lostGlyphs)
            .put("no_confidence", noConfidence)
            .put("lines", out)
    }

    private sealed interface Outcome {
        data class Ok(val json: String) : Outcome

        data class Failed(val code: String, val message: String) : Outcome
    }

    private class BadImageException(message: String) : Exception(message)

    private class OcrTimeoutException(message: String) : Exception(message)
}
