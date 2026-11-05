import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

// Document-scan preprocessing probe. Uses only Vision + Core Image so the same calls run on iOS.
//
// usage:
//   scan process <photo> --name pNNN --out DIR [--rotate DEG] [--detector seg|rect|none] [--max-side N]
//        -> DIR/<variant>/<name>.{jpg,png} and DIR/meta/<name>.json (quads of both detectors, timings, sizes)
//        --detector none: skip the perspective step and clean up the whole upright photo (isolates the filters)
//   scan orient <photo> [--no-exif] [--rotate DEG] [--max-side N]
//        -> JSON: reading direction votes from Vision text quads, suggested correction
// Coordinates in JSON are normalized to the upright input image with a top-left origin (same as the OCR fixtures).
// --rotate is an extra counter-clockwise rotation after EXIF, same convention as make_fixture.py (-90 = clockwise).

let argv = CommandLine.arguments
func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}
/// Value after `key`; the last occurrence wins so callers can append overrides.
func opt(_ key: String) -> String? {
    guard let i = argv.lastIndex(of: key) else { return nil }
    guard i + 1 < argv.count, !argv[i + 1].hasPrefix("--") else { fail("\(key) needs a value") }
    return argv[i + 1]
}
func flag(_ key: String) -> Bool { argv.contains(key) }
func intOpt(_ key: String, default value: Int) -> Int {
    guard let raw = opt(key) else { return value }
    guard let v = Int(raw) else { fail("\(key) must be an integer, got \(raw)") }
    return v
}
func sideOpt(_ key: String) -> CGFloat? {
    guard let raw = opt(key) else { return nil }
    guard let v = Double(raw), v >= 64 else { fail("\(key) must be a number >= 64, got \(raw)") }
    return CGFloat(v)
}

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
let gray8 = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
// Non-linear sRGB working space: thresholds read like 8-bit values, and division commutes with the gamma curve.
let ctx = CIContext(options: [.workingColorSpace: sRGB, .outputColorSpace: sRGB])

func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
func ms(since t0: UInt64) -> Double { (Double(now() - t0) / 1e6 * 10).rounded() / 10 }
func r4(_ v: CGFloat) -> Double { (Double(v) * 10000).rounded() / 10000 }

// MARK: - loading and rotation

func rotated(_ img: CIImage, by degrees: Int) -> CIImage {
    let d = ((degrees % 360) + 360) % 360
    let t: CGAffineTransform
    switch d {
    case 0: return img
    case 90: t = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0)  // counter-clockwise
    case 180: t = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
    case 270: t = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 0)
    default: fail("rotation must be a multiple of 90, got \(degrees)")
    }
    let r = img.transformed(by: t)
    return r.transformed(by: CGAffineTransform(translationX: -r.extent.minX, y: -r.extent.minY))
}

func load(_ path: String, exif: Bool, rotate: Int) -> CIImage {
    guard let img = CIImage(contentsOf: URL(fileURLWithPath: path), options: [.applyOrientationProperty: exif]) else {
        fail("cannot load image \(path)")
    }
    let r = rotated(img, by: rotate)
    return r.transformed(by: CGAffineTransform(translationX: -r.extent.minX, y: -r.extent.minY))
}

func downscaled(_ img: CIImage, maxSide: CGFloat) -> CIImage {
    let s = maxSide / max(img.extent.width, img.extent.height)
    guard s < 1 else { return img }
    let out = img.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: s, kCIInputAspectRatioKey: 1])
    return out.transformed(by: CGAffineTransform(translationX: -out.extent.minX, y: -out.extent.minY))
}

// MARK: - page detection

struct Quad {
    let source: String
    let tl: CGPoint, tr: CGPoint, br: CGPoint, bl: CGPoint  // Vision normalized, bottom-left origin
    let confidence: Float

    init(_ source: String, tl: CGPoint, tr: CGPoint, br: CGPoint, bl: CGPoint) {
        self.source = source
        self.tl = tl; self.tr = tr; self.br = br; self.bl = bl
        confidence = 1
    }

    init(_ source: String, _ o: VNRectangleObservation) {
        self.source = source
        tl = o.topLeft; tr = o.topRight; br = o.bottomRight; bl = o.bottomLeft
        confidence = o.confidence
    }

    var corners: [CGPoint] { [tl, tr, br, bl] }
    var area: CGFloat {
        let p = corners
        var s: CGFloat = 0
        for i in 0..<4 { s += p[i].x * p[(i + 1) % 4].y - p[(i + 1) % 4].x * p[i].y }
        return abs(s) / 2
    }
    func contains(_ q: CGPoint) -> Bool {
        let p = corners
        var sign: CGFloat = 0
        for i in 0..<4 {
            let a = p[i], b = p[(i + 1) % 4]
            let cross = (b.x - a.x) * (q.y - a.y) - (b.y - a.y) * (q.x - a.x)
            if cross != 0 {
                if sign == 0 { sign = cross } else if (sign > 0) != (cross > 0) { return false }
            }
        }
        return true
    }
    var json: [String: Any] {
        // top-left origin, like the OCR fixtures
        let pt = { (p: CGPoint) in [r4(p.x), r4(1 - p.y)] }
        return ["source": source, "tl": pt(tl), "tr": pt(tr), "br": pt(br), "bl": pt(bl),
                "confidence": Double(confidence), "area": r4(area)]
    }
}

func detectSegmentation(_ img: CIImage) throws -> [Quad] {
    let req = VNDetectDocumentSegmentationRequest()
    try VNImageRequestHandler(ciImage: img, options: [:]).perform([req])
    return (req.results ?? []).map { Quad("segmentation", $0) }
}

func detectRectangles(_ img: CIImage) throws -> [Quad] {
    let req = VNDetectRectanglesRequest()
    req.maximumObservations = 8
    req.minimumAspectRatio = 0.3
    req.maximumAspectRatio = 1.0
    req.minimumSize = 0.2
    req.quadratureTolerance = 30
    req.minimumConfidence = 0
    try VNImageRequestHandler(ciImage: img, options: [:]).perform([req])
    return (req.results ?? []).map { Quad("rectangles", $0) }
}

/// The page we want is the one under the camera's centre; a neighbouring page rarely covers it.
func pickPage(_ cands: [Quad]) -> Quad? {
    let centre = CGPoint(x: 0.5, y: 0.5)
    let covering = cands.filter { $0.contains(centre) }
    return (covering.isEmpty ? cands : covering).max { $0.area < $1.area }
}

func rectify(_ img: CIImage, _ q: Quad) -> CIImage {
    let w = img.extent.width, h = img.extent.height
    let px = { (p: CGPoint) in CGPoint(x: p.x * w, y: p.y * h) }
    let f = CIFilter.perspectiveCorrection()
    f.inputImage = img
    f.topLeft = px(q.tl); f.topRight = px(q.tr); f.bottomRight = px(q.br); f.bottomLeft = px(q.bl)
    f.crop = true
    let out = f.outputImage!
    return out.transformed(by: CGAffineTransform(translationX: -out.extent.minX, y: -out.extent.minY))
}

// MARK: - clean-up variants

func toGray(_ img: CIImage) -> CIImage {
    img.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
}

/// Linear stretch so that `lo` maps to black and `hi` to white, clamped.
func levels(_ img: CIImage, lo: Double, hi: Double) -> CIImage {
    let s = 1 / max(hi - lo, 1e-3)
    let m = CIFilter.colorMatrix()
    m.inputImage = img
    m.rVector = CIVector(x: s, y: 0, z: 0, w: 0)
    m.gVector = CIVector(x: 0, y: s, z: 0, w: 0)
    m.bVector = CIVector(x: 0, y: 0, z: s, w: 0)
    m.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
    m.biasVector = CIVector(x: -lo * s, y: -lo * s, z: -lo * s, w: 0)
    return m.outputImage!.applyingFilter("CIColorClamp")
}

/// Brightness percentiles of a gray image, measured on a small copy.
func percentiles(_ img: CIImage, _ qs: [Double]) -> [Double] {
    let small = downscaled(img, maxSide: 512)
    let w = Int(small.extent.width), h = Int(small.extent.height)
    guard w > 0, h > 0 else { fail("percentiles: empty image") }
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    ctx.render(small, toBitmap: &buf, rowBytes: w * 4,
               bounds: CGRect(x: small.extent.minX, y: small.extent.minY, width: CGFloat(w), height: CGFloat(h)),
               format: .RGBA8, colorSpace: sRGB)
    var hist = [Int](repeating: 0, count: 256)
    for k in stride(from: 0, to: buf.count, by: 4) { hist[Int(buf[k])] += 1 }
    let n = Double(w * h)
    return qs.map { q in
        var acc = 0
        for v in 0..<256 {
            acc += hist[v]
            if Double(acc) >= q * n { return Double(v) / 255 }
        }
        return 1
    }
}

/// Paper brightness estimate: a max filter erases dark strokes, a blur smooths the shadow field.
/// Computed at 1/`down` scale (cheap on device), then scaled back. `radius` is in full-resolution pixels.
func background(_ img: CIImage, radius: Double, down: Double = 8) -> CIImage {
    let e = img.extent
    let small = img.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 1 / down, kCIInputAspectRatioKey: 1])
    let r = radius / down
    let bg = small.clampedToExtent()
        .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: r])
        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: r])
    return bg.transformed(by: CGAffineTransform(scaleX: down, y: down)).cropped(to: e)
}

/// img / background, clamped (CIDivideBlendMode computes background / input).
func divide(_ img: CIImage, by bg: CIImage) -> CIImage {
    bg.applyingFilter("CIDivideBlendMode", parameters: [kCIInputBackgroundImageKey: img]).cropped(to: img.extent)
}

struct Variant {
    let name: String
    let note: String
    let png: Bool
    let make: (CIImage) -> CIImage
}

// Radii are relative to the page's long side so the result does not depend on the camera resolution.
func variants(longSide: CGFloat) -> [Variant] {
    let small = Double(longSide) * 0.006  // > half a stroke, < half a colour band: bands turn white
    let large = Double(longSide) * 0.03  // > half a band: only paper counts as background, bands keep their tone
    return [
        Variant(name: "a-persp", note: "perspective correction only", png: false) { $0 },
        Variant(name: "b-gray", note: "grayscale + 1%/99% contrast stretch", png: false) { page in
            let g = toGray(page)
            let p = percentiles(g, [0.01, 0.99])
            return levels(g, lo: p[0], hi: p[1])
        },
        Variant(name: "c-flat", note: "grayscale / blurred max-filtered background (shadow removal), levels 0.15-0.92", png: false) { page in
            let g = toGray(page)
            return levels(divide(g, by: background(g, radius: large)), lo: 0.15, hi: 0.92)
        },
        Variant(name: "c-flatcolor", note: "colour / background (white paper, colours kept) for the review screen", png: false) { page in
            levels(divide(page, by: background(page, radius: large)), lo: 0.08, hi: 0.94)
        },
        Variant(name: "d-binary", note: "adaptive threshold: gray / small-radius background < 0.80 -> black", png: true) { page in
            let g = toGray(page)
            return divide(g, by: background(g, radius: small)).applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.80])
        },
    ]
}

func write(_ img: CIImage, to url: URL, png: Bool, grayscale: Bool) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    if png {
        try ctx.writePNGRepresentation(of: img, to: url, format: grayscale ? .L8 : .RGBA8, colorSpace: grayscale ? gray8 : sRGB)
    } else {
        try ctx.writeJPEGRepresentation(of: img, to: url, colorSpace: grayscale ? gray8 : sRGB,
                                        options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.85])
    }
}

func fileSize(_ url: URL) -> Int { (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0 }

func process() throws {
    guard argv.count > 2, let name = opt("--name"), let out = opt("--out") else {
        fail("usage: scan process <photo> --name pNNN --out DIR [--rotate DEG] [--detector seg|rect|none] [--max-side N]")
    }
    let outDir = URL(fileURLWithPath: out)
    let detector = opt("--detector") ?? "seg"
    guard ["seg", "rect", "none"].contains(detector) else { fail("unknown --detector \(detector) (seg|rect|none)") }
    let rotate = intOpt("--rotate", default: 0)
    let exif = !flag("--no-exif")
    var t0 = now()
    let img = load(argv[2], exif: exif, rotate: rotate)
    // Vision works on its own downscaled copy; a 2048 px input gives the same quad and is faster to hand over.
    let probe = downscaled(img, maxSide: 2048)
    var timings: [String: Double] = ["load": ms(since: t0)]
    t0 = now(); let seg = try detectSegmentation(probe); timings["detect_segmentation"] = ms(since: t0)
    t0 = now(); let rect = try detectRectangles(probe); timings["detect_rectangles"] = ms(since: t0)
    let whole = Quad("none", tl: CGPoint(x: 0, y: 1), tr: CGPoint(x: 1, y: 1), br: CGPoint(x: 1, y: 0), bl: CGPoint(x: 0, y: 0))
    guard let page = detector == "none" ? whole : pickPage(detector == "rect" ? rect : seg) else {
        fail("\(name): no page found by \(detector)")
    }

    t0 = now()
    var flat = detector == "none" ? img : rectify(img, page)
    if let side = sideOpt("--max-side") { flat = downscaled(flat, maxSide: side) }
    // materialise once so each variant starts from the same pixels and timings separate cleanly
    guard let cg = ctx.createCGImage(flat, from: flat.extent) else { fail("render failed") }
    let base = CIImage(cgImage: cg)
    timings["rectify"] = ms(since: t0)

    var outputs: [[String: Any]] = []
    for v in variants(longSide: max(base.extent.width, base.extent.height)) {
        t0 = now()
        let result = v.make(base)
        let file = outDir.appendingPathComponent(v.name).appendingPathComponent("\(name).\(v.png ? "png" : "jpg")")
        let gray = v.name != "a-persp" && v.name != "c-flatcolor"
        try write(result, to: file, png: v.png, grayscale: gray)
        outputs.append(["variant": v.name, "note": v.note, "file": file.path, "bytes": fileSize(file), "ms": ms(since: t0)])
    }
    let meta: [String: Any] = [
        "photo": argv[2], "name": name, "detector": detector, "exif": exif, "rotate": rotate,
        "input_size": [Int(img.extent.width), Int(img.extent.height)],
        "page_size": [Int(base.extent.width), Int(base.extent.height)],
        "page": page.json,
        "candidates": ["segmentation": seg.map { $0.json }, "rectangles": rect.map { $0.json }],
        "timings_ms": timings, "outputs": outputs,
    ]
    let metaURL = outDir.appendingPathComponent("meta").appendingPathComponent("\(name).json")
    try FileManager.default.createDirectory(at: metaURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys]).write(to: metaURL)
    print("\(name): page \(Int(base.extent.width))x\(Int(base.extent.height)) by \(detector), seg=\(seg.count) rect=\(rect.count) " +
          "detect=\(timings["detect_segmentation"]!)/\(timings["detect_rectangles"]!)ms rectify=\(timings["rectify"]!)ms")
}

// MARK: - orientation

/// Vision's accurate recogniser reads sideways and upside-down text and returns quads that follow the text.
/// The topLeft -> topRight vector is the reading direction; its dominant angle tells how the photo is turned.
func orient() throws {
    guard argv.count > 2 else { fail("usage: scan orient <photo> [--no-exif] [--rotate DEG] [--max-side N]") }
    let img0 = load(argv[2], exif: !flag("--no-exif"), rotate: intOpt("--rotate", default: 0))
    let img = downscaled(img0, maxSide: sideOpt("--max-side") ?? 1600)
    let w = img.extent.width, h = img.extent.height
    let handler = VNImageRequestHandler(ciImage: img, options: [:])

    var t0 = now()
    let rects = VNDetectTextRectanglesRequest()
    try handler.perform([rects])
    let rectMs = ms(since: t0)
    let aspects = (rects.results ?? []).filter { $0.boundingBox.height > 0 }
        .map { Double($0.boundingBox.width * w / ($0.boundingBox.height * h)) }.sorted()

    t0 = now()
    let rec = VNRecognizeTextRequest()
    rec.recognitionLevel = .accurate
    rec.recognitionLanguages = ["ja-JP", "ko-KR"]
    rec.usesLanguageCorrection = false
    try handler.perform([rec])
    let recMs = ms(since: t0)
    var votes = [0, 0, 0, 0]  // characters whose reading direction points 0 / 90 / 180 / 270 degrees (counter-clockwise)
    for o in rec.results ?? [] {
        let dx = Double((o.topRight.x - o.topLeft.x) * w), dy = Double((o.topRight.y - o.topLeft.y) * h)
        let angle = (atan2(dy, dx) * 180 / .pi + 360 + 45).truncatingRemainder(dividingBy: 360)
        votes[Int(angle / 90) % 4] += o.topCandidates(1).first?.string.count ?? 0
    }
    let total = max(votes.reduce(0, +), 1)
    let best = votes.indices.max { votes[$0] < votes[$1] }!
    let correction = [0, -90, 180, 90][best]  // counter-clockwise rotation that makes the text upright
    let n = aspects.count
    let median: Double? = n == 0 ? nil : (n % 2 == 1 ? aspects[n / 2] : (aspects[n / 2 - 1] + aspects[n / 2]) / 2)
    let out: [String: Any] = [
        "photo": argv[2], "size": [Int(w), Int(h)],
        "votes_0_90_180_270": votes, "share": Double(votes[best]) / Double(total), "correction": correction,
        "chars": votes.reduce(0, +),  // 0 = no text read, the vote (and correction 0) means nothing
        "text_rect_count": n, "text_rect_median_w_over_h": median.map { ($0 * 100).rounded() / 100 } ?? NSNull(),
        "sideways_by_aspect": median.map { $0 < 1.5 } ?? NSNull(), "ms": ["text_rects": rectMs, "recognize": recMs],
    ]
    print(String(data: try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys]), encoding: .utf8)!)
}

switch argv.count > 1 ? argv[1] : "" {
case "process": try process()
case "orient": try orient()
default: fail("usage: scan process|orient <photo> ...")
}
