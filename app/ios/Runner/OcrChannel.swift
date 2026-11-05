import Flutter
import ImageIO
import Vision

/// Apple Vision OCR behind the `TextRecognizer` port (Dart: PlatformTextRecognizer).
///
/// `recognize(path)` reads the photo twice, Japanese-first and Korean-first, and returns
/// `{"ja": OcrPage, "ko": OcrPage}` as JSON. Each OcrPage has the shape the research probe
/// (tools/reference/vision_ocr.swift) recorded: lines with t, c, x, y, w, h, normalized,
/// origin at the top-left of the upright image. Runs on device, no network.
final class OcrChannel: NSObject, FlutterPlugin {
  static let name = "shiori/ocr"

  private static let passes: [(tag: String, languages: [String])] = [
    ("ja", ["ja-JP", "ko-KR"]),
    ("ko", ["ko-KR", "ja-JP"]),
  ]

  private let queue = DispatchQueue(label: "shiori.ocr", qos: .userInitiated)

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(OcrChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "recognize" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any], let path = args["path"] as? String, !path.isEmpty else {
      result(FlutterError(code: "bad_args", message: "path is required", details: nil))
      return
    }
    queue.async {
      let outcome: Any
      do {
        outcome = try Self.recognize(path: path)
      } catch let error as OcrError {
        outcome = FlutterError(code: error.code, message: error.message, details: nil)
      } catch {
        outcome = FlutterError(code: "ocr_failed", message: error.localizedDescription, details: nil)
      }
      DispatchQueue.main.async { result(outcome) }
    }
  }

  static func recognize(path: String) throws -> String {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let source = CGImageSourceCreateWithURL(url, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw OcrError(code: "bad_image", message: "cannot open \(path)")
    }
    // Photos keep their rotation in EXIF; Vision returns boxes for the upright page.
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let rawOrientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value ?? 1
    let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up

    var pages: [String: Any] = [:]
    for pass in passes {
      pages[pass.tag] = try page(image: image, orientation: orientation, languages: pass.languages)
    }
    let data = try JSONSerialization.data(withJSONObject: pages)
    return String(decoding: data, as: UTF8.self)
  }

  private static func page(image: CGImage, orientation: CGImagePropertyOrientation, languages: [String]) throws -> [String: Any] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = languages
    request.usesLanguageCorrection = true
    let started = Date()
    try VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:]).perform([request])
    let elapsedMs = Date().timeIntervalSince(started) * 1000

    let lines: [[String: Any]] = (request.results ?? []).compactMap { observation in
      guard let best = observation.topCandidates(1).first else { return nil }
      let box = observation.boundingBox  // normalized, origin at the bottom-left
      return [
        "t": best.string,
        "c": Double(best.confidence),
        "x": Double(box.minX),
        "y": Double(1 - box.maxY),
        "w": Double(box.width),
        "h": Double(box.height),
      ]
    }
    return ["engine": "apple-vision", "langs": languages, "ms": Int(elapsedMs.rounded()), "lines": lines]
  }
}

struct OcrError: Error {
  let code: String
  let message: String
}
