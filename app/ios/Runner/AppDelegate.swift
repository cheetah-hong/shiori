import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Device OCR block (Apple Vision) for the Dart TextRecognizer port.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShioriOcr") {
      OcrChannel.register(with: registrar)
    } else {
      // Without this the Dart side only sees "OCR unavailable"; say why.
      NSLog("[Shiori] OCR channel was not registered: no plugin registrar")
    }
    // Pronunciation clips (AVAudioPlayer) for the Dart speech block.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShioriAudio") {
      AudioChannel.register(with: registrar)
    } else {
      NSLog("[Shiori] audio channel was not registered: no plugin registrar")
    }
  }
}
