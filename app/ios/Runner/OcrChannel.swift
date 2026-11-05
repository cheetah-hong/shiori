import CoreImage
import Flutter
import ImageIO
import Vision

/// Apple Vision OCR behind the `TextRecognizer` port (Dart: PlatformTextRecognizer).
///
/// `recognize(path, starPass)` reads the photo Japanese-first and Korean-first and returns
/// `{"ja": OcrPage, "ko": OcrPage, "star"?: OcrPage, "turned": degrees, "timing": {...}}` as JSON.
/// Each OcrPage has the shape the research probe (tools/reference/vision_ocr.swift) recorded:
/// lines with t, c, x, y, w, h, normalized, origin at the top-left of the upright image.
///
/// - Upright: EXIF first; then the reading direction of the first Japanese pass votes. A photo
///   taken from above often has no rotation in EXIF. When the text is not upright the image is
///   read again turned the right way, so an upright photo costs nothing extra.
/// - Star pass (optional): a third Japanese pass over a binarized copy of the same frame. Vision
///   misses some ★ marks on the colour photo and reads them there; Dart takes only its ★ glyphs.
///
/// Runs on device, no network.
final class OcrChannel: NSObject, FlutterPlugin {
  static let name = "shiori/ocr"

  private static let japanese = ["ja-JP", "ko-KR"]
  private static let korean = ["ko-KR", "ja-JP"]

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
    let starPass = args["starPass"] as? Bool ?? false
    queue.async {
      let outcome: Any
      do {
        outcome = try Self.recognize(path: path, starPass: starPass)
      } catch let error as OcrError {
        outcome = FlutterError(code: error.code, message: error.message, details: nil)
      } catch {
        outcome = FlutterError(code: "ocr_failed", message: error.localizedDescription, details: nil)
      }
      DispatchQueue.main.async { result(outcome) }
    }
  }

  static func recognize(path: String, starPass: Bool) throws -> String {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let source = CGImageSourceCreateWithURL(url, nil) else {
      throw OcrError(code: "bad_image", message: "cannot open \(path)")
    }
    // Photos keep their rotation in EXIF; Vision returns boxes for the oriented image.
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    guard let image = decode(source, properties: properties) else {
      throw OcrError(code: "bad_image", message: "cannot decode \(path)")
    }
    let rawOrientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value ?? 1
    var orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up

    var timing: [String: Int] = [:]
    var ja = try read(image, orientation: orientation, languages: japanese)
    var turned = 0
    let turns = OcrOrientation.clockwiseTurns(votes: OcrOrientation.votes(ja.observations, orientation: orientation,
                                                                           width: image.width, height: image.height))
    if turns != 0 {
      if let upright = OcrOrientation.orientation(orientation, turnedClockwise: turns) {
        timing["orient_pass"] = ja.ms
        orientation = upright
        turned = turns * 90
        ja = try read(image, orientation: orientation, languages: japanese)
      } else {
        NSLog("[Shiori] text is not upright but the photo is mirrored (EXIF \(rawOrientation)); read as it is")
      }
    }
    let ko = try read(image, orientation: orientation, languages: korean)

    var pages: [String: Any] = [
      "ja": page(ja, languages: japanese),
      "ko": page(ko, languages: korean),
      "turned": turned,
    ]
    if starPass {
      let started = Date()
      // The two main passes are good on their own; a failed star pass only loses the ★ help.
      if let binary = binarized(image, orientation: orientation) {
        timing["star_binarize"] = milliseconds(since: started)
        do {
          let stars = try read(binary, orientation: .up, languages: japanese)
          pages["star"] = page(stars, languages: japanese)
        } catch {
          NSLog("[Shiori] star pass skipped: \(error.localizedDescription)")
        }
      } else {
        NSLog("[Shiori] star pass skipped: could not binarize the image")
      }
    }
    pages["timing"] = timing
    let data = try JSONSerialization.data(withJSONObject: pages)
    return String(decoding: data, as: UTF8.self)
  }

  private struct Pass {
    let observations: [VNRecognizedTextObservation]
    let ms: Int
  }

  /// Longest side handed to Vision. Phone photos (12 MP, 4032 px) pass at full size.
  static let maxSide = 4096

  /// The stored pixels (EXIF is applied by Vision), downsampled only beyond [maxSide].
  private static func decode(_ source: CGImageSource, properties: [CFString: Any]?) -> CGImage? {
    let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
    let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
    guard max(width, height) > maxSide else { return CGImageSourceCreateImageAtIndex(source, 0, nil) }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: maxSide,
      kCGImageSourceCreateThumbnailWithTransform: false,  // keep the stored frame; EXIF goes to Vision
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }

  private static func read(_ image: CGImage, orientation: CGImagePropertyOrientation,
                           languages: [String]) throws -> Pass {
    // Each pass frees its temporaries before the next one starts.
    try autoreleasepool {
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.recognitionLanguages = languages
      request.usesLanguageCorrection = true
      let started = Date()
      try VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:]).perform([request])
      return Pass(observations: request.results ?? [], ms: milliseconds(since: started))
    }
  }

  private static func page(_ pass: Pass, languages: [String]) -> [String: Any] {
    let lines: [[String: Any]] = pass.observations.compactMap { observation in
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
    return ["engine": "apple-vision", "langs": languages, "ms": pass.ms, "lines": lines]
  }

  private static func milliseconds(since start: Date) -> Int {
    Int((Date().timeIntervalSince(start) * 1000).rounded())
  }

  // MARK: - star pass image

  /// Non-linear sRGB working space: the threshold reads like an 8-bit value.
  private static let context: CIContext = {
    let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    return CIContext(options: [.workingColorSpace: sRGB, .outputColorSpace: sRGB])
  }()

  /// Upright gray copy divided by a small-radius paper estimate, thresholded at 0.80:
  /// strokes black, paper and colour bands white. Same frame as the oriented photo.
  static func binarized(_ image: CGImage, orientation: CGImagePropertyOrientation) -> CGImage? {
    autoreleasepool { binarizedImage(image, orientation: orientation) }
  }

  private static func binarizedImage(_ image: CGImage, orientation: CGImagePropertyOrientation) -> CGImage? {
    let upright = CIImage(cgImage: image).oriented(orientation)
    let page = upright.transformed(by: CGAffineTransform(translationX: -upright.extent.minX,
                                                         y: -upright.extent.minY))
    let extent = page.extent
    let gray = page.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
    // Paper estimate: a max filter erases strokes, a blur smooths it; computed at 1/8 scale.
    let down = 8.0
    let radius = Double(max(extent.width, extent.height)) * OcrOrientation.starPassRadius / down
    let paper = gray.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 1 / down,
                                                                             kCIInputAspectRatioKey: 1])
      .clampedToExtent()
      .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: radius])
      .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
      .transformed(by: CGAffineTransform(scaleX: down, y: down))
      .cropped(to: extent)
    // CIDivideBlendMode computes background / input: gray / paper.
    let binary = paper.applyingFilter("CIDivideBlendMode", parameters: [kCIInputBackgroundImageKey: gray])
      .cropped(to: extent)
      .applyingFilter("CIColorThreshold", parameters: ["inputThreshold": OcrOrientation.starPassThreshold])
    return context.createCGImage(binary, from: extent)
  }
}

/// Pure geometry for the OCR channel (unit tested in RunnerTests).
enum OcrOrientation {
  /// A turn is applied only when this share of the read characters agrees on it.
  static let minShare = 0.6
  /// Fewer characters than this: no text to tell the direction from.
  static let minCharacters = 20

  /// Star pass: paper-estimate radius (share of the long side) and black threshold.
  static let starPassRadius = 0.006
  static let starPassThreshold = 0.80

  struct Quad {
    let topLeft: CGPoint
    let topRight: CGPoint
    let characters: Int
  }

  /// Characters whose reading direction points 0°, 90°, 180°, 270° (counter-clockwise) in the
  /// image. Points are Vision's normalized coordinates (origin bottom-left) of an image
  /// [width] × [height] pixels.
  static func votes(_ quads: [Quad], width: Double, height: Double) -> [Int] {
    var votes = [0, 0, 0, 0]
    for q in quads {
      let dx = Double(q.topRight.x - q.topLeft.x) * width
      let dy = Double(q.topRight.y - q.topLeft.y) * height
      if dx == 0 && dy == 0 { continue }
      let angle = (atan2(dy, dx) * 180 / .pi + 360 + 45).truncatingRemainder(dividingBy: 360)
      votes[Int(angle / 90) % 4] += q.characters
    }
    return votes
  }

  static func votes(_ observations: [VNRecognizedTextObservation], orientation: CGImagePropertyOrientation,
                    width: Int, height: Int) -> [Int] {
    // Vision's coordinates are for the oriented image, whose sides swap for quarter turns.
    let swap = swapsSides(orientation)
    let quads = observations.map {
      Quad(topLeft: $0.topLeft, topRight: $0.topRight,
           characters: $0.topCandidates(1).first?.string.count ?? 0)
    }
    return votes(quads, width: Double(swap ? height : width), height: Double(swap ? width : height))
  }

  /// Whether the oriented image is [height] wide (a quarter turn, mirrored or not).
  static func swapsSides(_ o: CGImagePropertyOrientation) -> Bool {
    [.left, .right, .leftMirrored, .rightMirrored].contains(o)
  }

  /// Clockwise quarter turns that make the text upright, 0 when it is upright or unclear.
  /// Text running up the image (90°) needs one clockwise turn.
  static func clockwiseTurns(votes: [Int]) -> Int {
    let total = votes.reduce(0, +)
    guard total >= minCharacters, let best = votes.indices.max(by: { votes[$0] < votes[$1] }) else { return 0 }
    return Double(votes[best]) / Double(total) >= minShare ? best : 0
  }

  /// Clockwise quarter turns an orientation applies to show the image upright; nil for mirrored ones.
  static func quarterTurns(_ o: CGImagePropertyOrientation) -> Int? {
    switch o {
    case .up: return 0
    case .right: return 1
    case .down: return 2
    case .left: return 3
    default: return nil
    }
  }

  /// [o] followed by [turns] more clockwise quarter turns; nil for mirrored orientations (left as is).
  static func orientation(_ o: CGImagePropertyOrientation, turnedClockwise turns: Int) -> CGImagePropertyOrientation? {
    guard let base = quarterTurns(o) else { return nil }
    switch ((base + turns) % 4 + 4) % 4 {
    case 0: return .up
    case 1: return .right
    case 2: return .down
    default: return .left
    }
  }
}

struct OcrError: Error {
  let code: String
  let message: String
}
