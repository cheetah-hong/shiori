import AVFoundation
import Darwin
import Flutter

/// Plays a pronunciation clip (a WAV the speech engine wrote into the app cache folder).
///
/// `MethodChannel('shiori/audio')`:
/// - `play {"path": absolute path}`: starts the clip and answers `nil`. A clip still playing is
///   stopped and the new one starts from the beginning. Any failure is `play_failed`.
/// - `stop`: stops the clip, `nil` even when nothing is playing.
///
/// Only regular files inside the app cache folder are played (symbolic links resolved first), so
/// the channel cannot be pointed at other files of the app or the system.
///
/// Session category `.playback`: the user pressed a button to hear the word, so it sounds even with
/// the silent switch on. Other apps' audio pauses while it plays and is told to resume after.
final class AudioChannel: NSObject, FlutterPlugin, AVAudioPlayerDelegate {
  static let name = "shiori/audio"

  private var player: AVAudioPlayer?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(AudioChannel(), channel: channel)
  }

  // Method calls and player callbacks both arrive on the main thread.
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "play":
      let path = (call.arguments as? [String: Any])?["path"] as? String
      result(play(path: path))
    case "stop":
      stopPlayer()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// `nil` when the clip started, otherwise the error for the Dart side.
  private func play(path: String?) -> FlutterError? {
    guard let path = path, !path.isEmpty else {
      return Self.failure("path is required")
    }
    guard let root = Self.cacheFolder(), let url = AudioPath.cachedFile(path, cacheFolder: root) else {
      return Self.failure("not a file in the app cache folder")
    }
    stopPlayer()
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback)
      try AVAudioSession.sharedInstance().setActive(true)
      let next = try AVAudioPlayer(contentsOf: url)
      next.delegate = self
      guard next.prepareToPlay(), next.play() else {
        deactivateSession()
        return Self.failure("the clip could not be played")
      }
      player = next
      return nil
    } catch {
      deactivateSession()
      return Self.failure(error.localizedDescription)
    }
  }

  private func stopPlayer() {
    guard let current = player else { return }
    current.delegate = nil
    current.stop()
    player = nil
    deactivateSession()
  }

  func audioPlayerDidFinishPlaying(_ finished: AVAudioPlayer, successfully flag: Bool) {
    guard finished === player else { return }
    if !flag { NSLog("[Shiori] pronunciation clip ended with a decoding error") }
    player = nil
    deactivateSession()
  }

  func audioPlayerDecodeErrorDidOccur(_ failed: AVAudioPlayer, error: Error?) {
    NSLog("[Shiori] pronunciation clip could not be decoded: \(error?.localizedDescription ?? "unknown")")
    guard failed === player else { return }
    player = nil
    deactivateSession()
  }

  /// Lets the audio another app was playing go on.
  private func deactivateSession() {
    do {
      try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
      NSLog("[Shiori] audio session was not deactivated: \(error.localizedDescription)")
    }
  }

  private static func cacheFolder() -> URL? {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
  }

  private static func failure(_ message: String) -> FlutterError {
    FlutterError(code: "play_failed", message: message, details: nil)
  }
}

/// Which paths the audio channel may play (pure; no player involved).
enum AudioPath {
  /// The file at [path] when it is an absolute path to a regular file inside [cacheFolder] once
  /// symbolic links are resolved on both sides; otherwise nil.
  static func cachedFile(_ path: String, cacheFolder: URL) -> URL? {
    guard path.hasPrefix("/"),
          let file = resolved(path),
          let root = resolved(cacheFolder.path)
    else { return nil }
    let inside = root == "/" ? "/" : root + "/"
    guard file.hasPrefix(inside), file.count > inside.count else { return nil }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: file, isDirectory: &isDirectory), !isDirectory.boolValue else {
      return nil
    }
    return URL(fileURLWithPath: file)
  }

  /// The canonical path with every symbolic link, `.` and `..` resolved; nil when it does not exist.
  static func resolved(_ path: String) -> String? {
    guard let real = realpath(path, nil) else { return nil }
    defer { free(real) }
    return String(cString: real)
  }
}
