package dev.nihongo.mlkitprobe

import android.app.Activity
import android.app.Instrumentation
import android.os.Bundle
import android.util.Log

/**
 * Entry point: `adb shell am instrument -w -e dir upright -e mode bitmap dev.nihongo.mlkitprobe/.ProbeInstrumentation`
 *
 * Arguments (all optional):
 *  - action:   "run" (default) or "prepare" (only create <externalFiles>/in/<dir> so adb can push into it)
 *  - dir:      input folder under <externalFiles>/in (default "upright")
 *  - mode:     "bitmap" (fromBitmap, rotation 0), "bitmap-exif" (fromBitmap, EXIF degrees) or "filepath" (fromFilePath)
 *  - parallel: "true" also times both recognizers submitted at once on each page
 */
class ProbeInstrumentation : Instrumentation() {
    private var args: Bundle = Bundle.EMPTY

    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        args = arguments ?: Bundle.EMPTY
        start()
    }

    override fun onStart() {
        super.onStart()
        val results = Bundle()
        val code = try {
            val report = Probe(targetContext, ProbeConfig.from { args.getString(it) }).run()
            results.putString(REPORT_KEY_STREAMRESULT, report + "\n")
            Activity.RESULT_OK
        } catch (t: Throwable) {
            Log.e(TAG, "probe failed", t)
            results.putString(REPORT_KEY_STREAMRESULT, "PROBE FAILED: ${t.stackTraceToString()}\n")
            Activity.RESULT_CANCELED
        }
        finish(code, results)
    }

    companion object {
        const val TAG = "MlKitProbe"
    }
}
