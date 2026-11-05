package dev.nihongo.mlkitprobe

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/**
 * BITMAP:      BitmapFactory, fromBitmap(rotation 0)     (EXIF ignored: input must already be upright)
 * BITMAP_EXIF: BitmapFactory, fromBitmap(EXIF degrees)  (pixels not rotated; ML Kit applies the rotation)
 * FILEPATH:    InputImage.fromFilePath                  (ML Kit decodes and rotates the pixels itself)
 */
enum class InputMode(val tag: String) { BITMAP("bitmap"), BITMAP_EXIF("bitmap-exif"), FILEPATH("filepath") }

data class ProbeConfig(val prepareOnly: Boolean, val inputDir: String, val mode: InputMode, val parallel: Boolean) {
    companion object {
        private val DIR_NAME = Regex("[A-Za-z0-9_-]+")

        /** [arg] looks up one instrumentation argument (null when absent); a function so it can be tested without Bundle. */
        fun from(arg: (String) -> String?): ProbeConfig {
            val prepareOnly = when (val a = arg("action") ?: "run") {
                "run" -> false
                "prepare" -> true
                else -> throw IllegalArgumentException("unknown action: $a")
            }
            val mode = InputMode.entries.firstOrNull { it.tag == (arg("mode") ?: "bitmap") }
                ?: throw IllegalArgumentException("unknown mode: ${arg("mode")}")
            val dir = arg("dir") ?: "upright"
            require(dir.matches(DIR_NAME)) { "bad dir: $dir" }
            return ProbeConfig(prepareOnly, dir, mode, arg("parallel") == "true")
        }
    }
}

private class Loaded(val image: InputImage, val bitmap: Bitmap?, val decodeMs: Long)

/** Reads every JPEG in <externalFiles>/in/<dir>, runs the Japanese and Korean recognizers, writes raw JSON dumps. */
class Probe(private val context: Context, private val config: ProbeConfig) {

    fun run(): String {
        val root = context.getExternalFilesDir(null) ?: error("external files dir unavailable")
        val inDir = File(root, "in/${config.inputDir}")
        if (config.prepareOnly) {
            // The app must own its input folder; folders made by `adb shell mkdir` are not readable by the app.
            check(inDir.isDirectory || inDir.mkdirs()) { "cannot create $inDir" }
            return "ready: ${inDir.absolutePath}"
        }
        val images = inDir.listFiles { f -> f.extension.lowercase() in setOf("jpg", "jpeg") }
            ?.sortedBy { it.name }
            .orEmpty()
        require(images.isNotEmpty()) { "no JPEG files in $inDir" }
        // A rerun must not leave dumps of an earlier run next to the new ones.
        val outDir = File(root, "out/${config.inputDir}-${config.mode.tag}")
        check(!outDir.exists() || outDir.deleteRecursively()) { "cannot clear $outDir" }
        check(outDir.mkdirs()) { "cannot create $outDir" }

        val recognizers: Map<String, TextRecognizer> = linkedMapOf(
            "ja" to TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build()),
            "ko" to TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build()),
        )
        try {
            return measure(images, outDir, recognizers)
        } finally {
            recognizers.values.forEach { it.close() }
        }
    }

    private fun measure(images: List<File>, outDir: File, recognizers: Map<String, TextRecognizer>): String {
        val report = StringBuilder()
        val rss = JSONObject().put("start_kb", rssKb())
        // The first call of each recognizer loads its model; time it separately so page timings are warm.
        val cold = JSONObject()
        withImage(images.first()) { first ->
            for ((lang, rec) in recognizers) {
                cold.put(lang, timed { await(rec.process(first.image), "cold $lang") }.second)
                rss.put("after_${lang}_kb", rssKb())
            }
        }
        report.appendLine("cold(model load + first page) ms: $cold")

        val pages = JSONArray()
        for (file in images) {
            pages.put(withImage(file) { loaded -> measurePage(file, loaded, outDir, recognizers, report) })
        }
        rss.put("end_kb", rssKb()).put("peak_kb", statusKb("VmHWM"))

        val timingDoc = JSONObject()
            .put("device", deviceInfo())
            .put("dir", config.inputDir)
            .put("mode", config.mode.tag)
            .put("cold_ms", cold)
            .put("rss", rss)
            .put("pages", pages)
        File(outDir, "timing.json").writeText(timingDoc.toString(2), Charsets.UTF_8)
        report.appendLine("wrote ${outDir.absolutePath}")
        return report.toString()
    }

    private fun measurePage(
        file: File, loaded: Loaded, outDir: File, recognizers: Map<String, TextRecognizer>, report: StringBuilder,
    ): JSONObject {
        val page = file.nameWithoutExtension
        val timing = JSONObject()
            .put("page", page)
            .put("decode_ms", loaded.decodeMs)
            .put("input_w", loaded.image.width)
            .put("input_h", loaded.image.height)
            .put("input_rotation", loaded.image.rotationDegrees)
        for ((lang, rec) in recognizers) {
            val (text, ms) = timed { await(rec.process(loaded.image), "$page $lang") }
            val dump = TextJson.page(text)
                .put("engine", "mlkit")
                .put("lang", lang)
                .put("mode", config.mode.tag)
                .put("source", file.name)
                .put("ms", ms)
                .put("input_w", loaded.image.width)
                .put("input_h", loaded.image.height)
                .put("input_rotation", loaded.image.rotationDegrees)
            File(outDir, "$page.$lang.raw.json").writeText(dump.toString(), Charsets.UTF_8)
            timing.put("${lang}_ms", ms)
            val lineCount = text.textBlocks.sumOf { it.lines.size }
            report.appendLine("$page $lang ${ms}ms blocks=${text.textBlocks.size} lines=$lineCount")
        }
        if (config.parallel) {
            // Both clients submitted together; wait for both before anything else touches the shared bitmap.
            val (_, ms) = timed {
                val tasks = recognizers.values.map { it.process(loaded.image) }
                await(Tasks.whenAllComplete(tasks), "$page parallel")
                tasks.forEach { t -> if (!t.isSuccessful) throw IllegalStateException("$page parallel failed", t.exception) }
            }
            timing.put("parallel_ms", ms)
            report.appendLine("$page parallel(ja+ko) ${ms}ms")
        }
        return timing
    }

    /** Decodes [file], runs [block], and always frees the decoded bitmap. */
    private fun <T> withImage(file: File, block: (Loaded) -> T): T {
        val loaded = load(file)
        try {
            return block(loaded)
        } finally {
            loaded.bitmap?.recycle()
        }
    }

    private fun load(file: File): Loaded {
        var bitmap: Bitmap? = null
        val (image, ms) = timed {
            when (config.mode) {
                InputMode.BITMAP, InputMode.BITMAP_EXIF -> {
                    val opts = BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }
                    val bmp = BitmapFactory.decodeFile(file.absolutePath, opts)
                        ?: error("cannot decode ${file.name}")
                    bitmap = bmp
                    val degrees = if (config.mode == InputMode.BITMAP_EXIF) exifDegrees(file) else 0
                    InputImage.fromBitmap(bmp, degrees)
                }
                InputMode.FILEPATH -> InputImage.fromFilePath(context, Uri.fromFile(file))
            }
        }
        return Loaded(image, bitmap, ms)
    }

    /** EXIF orientation as clockwise degrees; mirrored orientations are not expected from a phone camera. */
    private fun exifDegrees(file: File): Int =
        when (ExifInterface(file.absolutePath).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90
            ExifInterface.ORIENTATION_ROTATE_180 -> 180
            ExifInterface.ORIENTATION_ROTATE_270 -> 270
            else -> 0
        }

    private fun deviceInfo() = JSONObject()
        .put("model", Build.MODEL)
        .put("sdk", Build.VERSION.SDK_INT)
        .put("abi", Build.SUPPORTED_ABIS.firstOrNull())
        .put("cores", Runtime.getRuntime().availableProcessors())
        .put("emulator", Build.HARDWARE.contains("ranchu") || Build.FINGERPRINT.contains("generic"))

    private fun rssKb(): Long = statusKb("VmRSS")

    private fun statusKb(key: String): Long =
        File("/proc/self/status").readLines()
            .firstOrNull { it.startsWith("$key:") }
            ?.split(Regex("\\s+"))?.getOrNull(1)?.toLongOrNull() ?: -1L

    private inline fun <T> timed(block: () -> T): Pair<T, Long> {
        val t0 = SystemClock.elapsedRealtimeNanos()
        val value = block()
        return value to (SystemClock.elapsedRealtimeNanos() - t0) / 1_000_000
    }

    /** Blocks this instrumentation thread (never the main thread) with a limit, naming the step that hung. */
    private fun <T> await(task: Task<T>, what: String): T =
        try {
            Tasks.await(task, AWAIT_TIMEOUT_S, TimeUnit.SECONDS)
        } catch (e: TimeoutException) {
            throw IllegalStateException("$what: no result after ${AWAIT_TIMEOUT_S}s", e)
        }

    private companion object {
        const val AWAIT_TIMEOUT_S = 120L
    }
}

/** Full ML Kit hierarchy (block > line > element > symbol) with pixel boxes; normalization happens on the host. */
object TextJson {
    fun page(text: Text): JSONObject = JSONObject()
        .put("text", text.text)
        .put("blocks", JSONArray(text.textBlocks.map(::block)))

    private fun block(b: Text.TextBlock): JSONObject = JSONObject()
        .put("t", b.text)
        .put("lang", b.recognizedLanguage)
        .put("box", box(b.boundingBox))
        .put("lines", JSONArray(b.lines.map(::line)))

    private fun line(l: Text.Line): JSONObject = JSONObject()
        .put("t", l.text)
        .put("c", num(l.confidence))
        .put("angle", num(l.angle))
        .put("lang", l.recognizedLanguage)
        .put("box", box(l.boundingBox))
        .put("corners", corners(l.cornerPoints))
        .put("elements", JSONArray(l.elements.map(::element)))

    private fun element(e: Text.Element): JSONObject = JSONObject()
        .put("t", e.text)
        .put("c", num(e.confidence))
        .put("angle", num(e.angle))
        .put("lang", e.recognizedLanguage)
        .put("box", box(e.boundingBox))
        .put("symbols", JSONArray(e.symbols.map(::symbol)))

    private fun symbol(s: Text.Symbol): JSONObject = JSONObject()
        .put("t", s.text)
        .put("c", num(s.confidence))
        .put("box", box(s.boundingBox))

    private fun box(r: android.graphics.Rect?): Any =
        r?.let { JSONArray(listOf(it.left, it.top, it.right, it.bottom)) } ?: JSONObject.NULL

    private fun corners(points: Array<android.graphics.Point>?): Any =
        points?.let { ps -> JSONArray(ps.map { JSONArray(listOf(it.x, it.y)) }) } ?: JSONObject.NULL

    /** org.json rejects NaN and infinities; they become null. */
    internal fun num(v: Float): Any = if (v.isFinite()) v.toDouble() else JSONObject.NULL
}
