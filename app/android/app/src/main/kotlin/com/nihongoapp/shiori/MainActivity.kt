package com.nihongoapp.shiori

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ocr: OcrChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // A new engine for this activity: release the previous channel first.
        ocr?.dispose()
        // Device OCR block (ML Kit) for the Dart TextRecognizer port.
        val channel = OcrChannel()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OcrChannel.NAME).setMethodCallHandler(channel)
        ocr = channel
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ocr?.dispose()
        ocr = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
