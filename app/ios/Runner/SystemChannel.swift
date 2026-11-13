import Flutter
import UIKit
import UserNotifications

/// The system's notification permission and the way to this app's notification settings, for
/// the Dart reminder block (the plugin schedules the reminders themselves).
///
/// `MethodChannel('shiori/system')`:
/// - `notificationStatus`: the `UNAuthorizationStatus` name (`notDetermined`, `denied`,
///   `authorized`, `provisional`, `ephemeral`, or `unknown`).
/// - `openNotificationSettings`: opens this app's notification settings in Settings; answers
///   `nil`, or the error `failed` when Settings could not be opened.
final class SystemChannel: NSObject, FlutterPlugin {
  static let name = "shiori/system"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(SystemChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "notificationStatus":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let status = SystemChannel.statusName(settings.authorizationStatus)
        DispatchQueue.main.async { result(status) }
      }
    case "openNotificationSettings":
      guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else {
        result(FlutterError(code: "failed", message: "no settings address", details: nil))
        return
      }
      UIApplication.shared.open(url) { opened in
        result(opened ? nil : FlutterError(code: "failed", message: "settings not opened", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// The name the Dart side reads for [status].
  static func statusName(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .denied: return "denied"
    case .authorized: return "authorized"
    case .provisional: return "provisional"
    case .ephemeral: return "ephemeral"
    @unknown default: return "unknown"
    }
  }
}
