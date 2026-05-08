import Flutter
import UIKit
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var screenChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "studio59.app") {
      let messenger = registrar.messenger()
      let channel = FlutterMethodChannel(name: "studio59/screen_record", binaryMessenger: messenger)
      screenChannel = channel
      channel.setMethodCallHandler { call, result in
        if call.method == "isCaptured" {
          result(UIScreen.main.isCaptured)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }

      let galleryChannel = FlutterMethodChannel(name: "studio59/gallery", binaryMessenger: messenger)
      galleryChannel.setMethodCallHandler { call, result in
        guard call.method == "saveToGallery" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "invalid_args", message: "Missing arguments", details: nil))
          return
        }
        let name = (args["name"] as? String) ?? "photo.jpg"
        let dataArg = args["bytes"] as? FlutterStandardTypedData
        let data = dataArg?.data
        guard let bytes = data else {
          result(FlutterError(code: "invalid_bytes", message: "Invalid image bytes", details: nil))
          return
        }

        if #available(iOS 14, *) {
          PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
              DispatchQueue.main.async { result(false) }
              return
            }
            PHPhotoLibrary.shared().performChanges({
              let request = PHAssetCreationRequest.forAsset()
              let options = PHAssetResourceCreationOptions()
              options.originalFilename = name
              request.addResource(with: .photo, data: bytes, options: options)
            }) { success, error in
              DispatchQueue.main.async {
                if success {
                  result(true)
                } else {
                  result(FlutterError(code: "save_failed", message: "Failed to save photo", details: error?.localizedDescription))
                }
              }
            }
          }
        } else {
          PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
              DispatchQueue.main.async { result(false) }
              return
            }
            PHPhotoLibrary.shared().performChanges({
              let request = PHAssetCreationRequest.forAsset()
              let options = PHAssetResourceCreationOptions()
              options.originalFilename = name
              request.addResource(with: .photo, data: bytes, options: options)
            }) { success, error in
              DispatchQueue.main.async {
                if success {
                  result(true)
                } else {
                  result(FlutterError(code: "save_failed", message: "Failed to save photo", details: error?.localizedDescription))
                }
              }
            }
          }
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

    NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.screenChannel?.invokeMethod("captureChanged", arguments: ["captured": UIScreen.main.isCaptured])
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
