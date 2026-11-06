package com.nihongoapp.shiori

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/**
 * Plays a pronunciation clip (a WAV the speech engine wrote into the app cache folder).
 *
 * `MethodChannel("shiori/audio")`, the shape of the iOS channel:
 * - `play {"path": absolute path}`: starts the clip and answers null. A clip still playing is
 *   released and the new one starts from the beginning. Any failure is `play_failed`.
 * - `stop`: releases the clip, null even when nothing is playing.
 *
 * Only regular files inside [cacheDir] are played (canonical paths compared, so symbolic links and
 * `..` cannot leave it). Method calls and player callbacks run on the main thread; the clips are
 * short local files, so `prepare()` there does not hold the UI.
 */
class AudioChannel(private val cacheDir: File) : MethodChannel.MethodCallHandler {
    companion object {
        const val NAME = "shiori/audio"
        private const val TAG = "ShioriAudio"
        private const val FAILED = "play_failed"
    }

    private var player: MediaPlayer? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> play(call.argument<String>("path"), result)
            "stop" -> {
                release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** Releases the clip; the channel stays usable (a new engine registers a new one anyway). */
    fun dispose() {
        release()
    }

    private fun play(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.error(FAILED, "path is required", null)
            return
        }
        val file = AudioPath.cachedFile(path, cacheDir)
        if (file == null) {
            result.error(FAILED, "not a file in the app cache folder", null)
            return
        }
        release()
        val next = MediaPlayer()
        try {
            next.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            next.setDataSource(file.path)
            next.setOnCompletionListener { finished -> finish(finished) }
            next.setOnErrorListener { failed, what, extra ->
                Log.w(TAG, "pronunciation clip failed while playing (what=$what, extra=$extra)")
                finish(failed)
                true
            }
            next.prepare()
            next.start()
        } catch (e: Exception) {
            // IOException, IllegalStateException, IllegalArgumentException, SecurityException.
            next.release()
            Log.w(TAG, "pronunciation clip could not be played", e)
            result.error(FAILED, e.message ?: e.javaClass.simpleName, null)
            return
        }
        player = next
        result.success(null)
    }

    /** A clip that ended (or failed) is released; an older one already replaced is released too. */
    private fun finish(done: MediaPlayer) {
        if (done === player) player = null
        done.release()
    }

    private fun release() {
        val current = player ?: return
        player = null
        try {
            current.stop()
        } catch (e: IllegalStateException) {
            // Not started or already completed: nothing to stop.
        }
        current.release()
    }
}

/** Which paths the audio channel may play (pure JVM; no Android types). */
object AudioPath {
    /**
     * The canonical file for [path] when it is an absolute path to an existing regular file inside
     * [cacheDir] once both are made canonical (symbolic links and `..` resolved); otherwise null.
     */
    fun cachedFile(path: String, cacheDir: File): File? {
        val requested = File(path)
        if (!requested.isAbsolute) return null
        return try {
            // Strings, not java.nio.file.Path: Path needs API 26 and the app
            // runs from API 24.
            val root = cacheDir.canonicalPath.trimEnd(File.separatorChar) + File.separator
            val file = requested.canonicalFile
            val inside = file.path.startsWith(root)
            if (inside && file.isFile) file else null
        } catch (e: IOException) {
            null
        } catch (e: SecurityException) {
            null
        }
    }
}
