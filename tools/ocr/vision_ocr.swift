import Foundation
import Vision
import AppKit

// usage: vision_ocr <image> [lang1,lang2]  -> JSON of text observations (top-left origin, normalized)
let args = CommandLine.arguments
let langs = args.count > 2 ? args[2].split(separator: ",").map(String.init) : ["ja-JP", "ko-KR"]
guard let img = NSImage(contentsOfFile: args[1]),
      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("cannot load image") }
let req = VNRecognizeTextRequest()
req.recognitionLevel = .accurate
req.recognitionLanguages = langs
req.usesLanguageCorrection = true
let t0 = Date()
try VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
let ms = Date().timeIntervalSince(t0) * 1000
var obs: [[String: Any]] = []
for o in req.results ?? [] {
    guard let c = o.topCandidates(1).first else { continue }
    let b = o.boundingBox
    obs.append(["t": c.string, "c": Double(c.confidence), "x": Double(b.minX), "y": Double(1 - b.maxY), "w": Double(b.width), "h": Double(b.height)])
}
let supported = (try? req.supportedRecognitionLanguages()) ?? []
let out: [String: Any] = ["ms": ms, "langs": langs, "supported": supported, "count": obs.count, "obs": obs]
print(String(data: try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted]), encoding: .utf8)!)
