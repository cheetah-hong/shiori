import Flutter
import Foundation

/// Keeps folders the app can lose without harm (the crash log) out of the device backup.
///
/// `MethodChannel('shiori/backup')`:
/// - `exclude {"path": absolute path}`: sets `isExcludedFromBackup` on the file or folder (a
///   folder's contents are left out with it) and answers `nil`.
/// - `isExcluded {"path": absolute path}`: whether that file or folder itself carries the mark.
///
/// Only paths inside the app's container are accepted (symbolic links, `.` and `..` resolved).
/// Errors: `outside_app`, `missing`, `failed`.
final class BackupChannel: NSObject, FlutterPlugin {
  static let name = "shiori/backup"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(BackupChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "exclude" || call.method == "isExcluded" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let path = (call.arguments as? [String: Any])?["path"] as? String, !path.isEmpty else {
      result(FlutterError(code: "failed", message: "path is required", details: nil))
      return
    }
    do {
      if call.method == "exclude" {
        try BackupExclusion.exclude(path: path)
        result(nil)
      } else {
        result(try BackupExclusion.isExcluded(path: path))
      }
    } catch let failure as BackupExclusion.Failure {
      result(FlutterError(code: failure.code, message: failure.message, details: nil))
    } catch {
      result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
    }
  }
}

/// The backup mark on paths inside the app container (no channel involved, for tests).
enum BackupExclusion {
  enum Failure: Error, Equatable {
    case outsideApp
    case missing

    var code: String {
      switch self {
      case .outsideApp: return "outside_app"
      case .missing: return "missing"
      }
    }

    var message: String {
      switch self {
      case .outsideApp: return "not a path inside the app container"
      case .missing: return "no such file or folder"
      }
    }
  }

  static func exclude(path: String, container: String = NSHomeDirectory()) throws {
    var url = try inside(path, container: container)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try url.setResourceValues(values)
  }

  static func isExcluded(path: String, container: String = NSHomeDirectory()) throws -> Bool {
    let url = try inside(path, container: container)
    return try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup ?? false
  }

  /// The resolved URL of [path] when it exists strictly inside [container].
  private static func inside(_ path: String, container: String) throws -> URL {
    guard path.hasPrefix("/") else { throw Failure.outsideApp }
    guard let file = AudioPath.resolved(path) else { throw Failure.missing }
    guard let root = AudioPath.resolved(container) else { throw Failure.outsideApp }
    let prefix = root == "/" ? "/" : root + "/"
    guard file.hasPrefix(prefix), file.count > prefix.count else { throw Failure.outsideApp }
    return URL(fileURLWithPath: file)
  }
}
