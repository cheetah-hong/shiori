package com.nihongoapp.shiori

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.os.Handler
import android.os.Looper
import android.util.Log
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
import java.util.concurrent.atomic.AtomicBoolean

/**
 * ML Kit OCR behind the Dart `TextRecognizer` port (PlatformTextRecognizer).
 *
 * `recognize(path)` runs the Japanese and the Korean recognizer (both bundled, on device)
 * and returns `{"ja": OcrPage, "ko": OcrPage}` JSON, the same shape as the iOS Vision
 * channel: lines with t, c, x, y, w, h normalized to the upright image, origin top-left.
 */
class OcrChannel : MethodChannel.MethodCallHandler {
    companion object {
        const val NAME = "shiori/ocr"
        private const val TAG = "ShioriOcr"

        /** Longest side handed to ML Kit; 12 MP phone photos pass unscaled. */
        private const val MAX_SIDE = 4096
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
        } catch (e: OutOfMemoryError) {
            // A huge photo: report it instead of taking the whole app down.
            Outcome.Failed("bad_image", "image too large to read")
        } catch (e: Exception) {
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
        val (bitmap, rotation) = loadDownsampled(File(path))
        val tasks = mutableListOf<Task<Text>>()
        try {
            // ML Kit applies the rotation; boxes come back in the upright frame,
            // whose width and height swap for 90° and 270°.
            val image = InputImage.fromBitmap(bitmap, rotation)
            val upright = rotation % 180 == 0
            val width = (if (upright) bitmap.width else bitmap.height).toDouble()
            val height = (if (upright) bitmap.height else bitmap.width).toDouble()
            // Start both passes before waiting, so they run side by side.
            val started = System.nanoTime()
            // Each pass is tracked as soon as it starts, so `finally` waits for it.
            val jaTask = japanese.process(image).also { tasks.add(it) }
            val koTask = korean.process(image).also { tasks.add(it) }
            val ja = Tasks.await(jaTask)
            val jaMs = (System.nanoTime() - started) / 1_000_000
            val ko = Tasks.await(koTask)
            val koMs = (System.nanoTime() - started) / 1_000_000
            return JSONObject()
                .put("ja", page(ja, width, height, "ja", jaMs))
                .put("ko", page(ko, width, height, "ko", koMs))
                .toString()
        } finally {
            // If one pass failed the other may still read the pixels.
            for (task in tasks) {
                try {
                    Tasks.await(task)
                } catch (e: Exception) {
                    Log.w(TAG, "pass ended with an error", e)
                }
            }
            bitmap.recycle()
        }
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
        val rotation = when (
            ExifInterface(file.path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        ) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90
            ExifInterface.ORIENTATION_ROTATE_180 -> 180
            ExifInterface.ORIENTATION_ROTATE_270 -> 270
            else -> 0
        }
        return bitmap to rotation
    }

    private fun page(text: Text, width: Double, height: Double, tag: String, ms: Long): JSONObject {
        val lines = JSONArray()
        var dropped = 0
        for (block in text.textBlocks) {
            for (line in block.lines) {
                val box = line.boundingBox
                if (box == null) {
                    dropped++
                    continue
                }
                val confidence = line.confidence
                lines.put(
                    JSONObject()
                        .put("t", line.text)
                        .put("c", if (confidence.isFinite()) confidence.toDouble() else 1.0)
                        .put("x", box.left / width)
                        .put("y", box.top / height)
                        .put("w", box.width() / width)
                        .put("h", box.height() / height),
                )
            }
        }
        if (dropped > 0) Log.w(TAG, "$tag pass: $dropped lines without a box were dropped")
        return JSONObject()
            .put("engine", "mlkit")
            // A label of the recognizer used (script + Latin), not a setting:
            // ML Kit picks languages by recognizer, unlike Vision's language list.
            .put("langs", JSONArray(listOf(tag, "en")))
            .put("ms", ms)
            .put("dropped", dropped)
            .put("lines", lines)
    }

    private sealed interface Outcome {
        data class Ok(val json: String) : Outcome

        data class Failed(val code: String, val message: String) : Outcome
    }

    private class BadImageException(message: String) : Exception(message)
}
