import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let environmentalChannelName = "com.humsukhan/environmental_monitor"
  private var environmentalChannel: FlutterMethodChannel?
  private var environmentalState = "OFF"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: environmentalChannelName,
      binaryMessenger: engineBridge.binaryMessenger
    )
    environmentalChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "APP_DELEGATE", message: "App delegate unavailable", details: nil))
        return
      }

      switch call.method {
      case "getState":
        result(self.environmentalState)

      case "isSupported":
        // iOS supports microphone capture while the app is active and can
        // continue audio work in the background when the Audio background
        // capability is enabled. The OS may still terminate the process.
        result(true)

      case "start":
        self.requestMicrophoneAndStart(result: result)

      case "stop":
        self.stopEnvironmentalMonitoring()
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func requestMicrophoneAndStart(result: @escaping FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    session.requestRecordPermission { [weak self] granted in
      DispatchQueue.main.async {
        guard let self else { return }
        guard granted else {
          self.environmentalState = "ERROR"
          result(FlutterError(code: "MIC_PERMISSION", message: "Microphone permission denied", details: nil))
          return
        }

        do {
          try session.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
          try session.setActive(true, options: [])
          self.environmentalState = "STARTING"
          // The actual sherpa-ONNX pipeline remains in Flutter. This call
          // asks the main Flutter isolate to start the shared local service.
          self.environmentalChannel?.invokeMethod("startLocalMonitoring", arguments: nil)
          result(true)
        } catch {
          self.environmentalState = "ERROR"
          result(FlutterError(code: "AUDIO_SESSION", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func stopEnvironmentalMonitoring() {
    environmentalState = "STOPPING"
    environmentalChannel?.invokeMethod("stopLocalMonitoring", arguments: nil)
    do {
      try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
      // Deactivation failure must not keep the app reporting ACTIVE.
    }
    environmentalState = "OFF"
  }
}
