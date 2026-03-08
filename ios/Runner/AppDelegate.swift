import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var screenChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "studio59/screen_record", binaryMessenger: controller.binaryMessenger)
      screenChannel = channel
      channel.setMethodCallHandler { call, result in
        if call.method == "isCaptured" {
          result(UIScreen.main.isCaptured)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    NotificationCenter.default.addObserver(
      forName: UIApplication.userDidTakeScreenshotNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.screenChannel?.invokeMethod("screenshotTaken", arguments: nil)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
