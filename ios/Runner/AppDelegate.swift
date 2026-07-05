import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var deviceInfoChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Flutter 3.x no longer sets UNUserNotificationCenter.delegate automatically.
    // Without this, iOS has no delegate to call on notification tap, so the plugin's
    // didReceiveNotificationResponse is never invoked and navigation is silently dropped.
    // FlutterAppDelegate conforms to FlutterAppLifeCycleProvider, which implements
    // UNUserNotificationCenterDelegate and forwards to all registered plugin delegates
    // (including FlutterLocalNotificationsPlugin). Setting it here restores the chain.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let controller = window?.rootViewController as? FlutterViewController {
      deviceInfoChannel = FlutterMethodChannel(
        name: "com.habitloop.device_info",
        binaryMessenger: controller.binaryMessenger
      )
      deviceInfoChannel?.setMethodCallHandler { [weak self] call, result in
        self?.handleDeviceInfo(call, result: result)
      }
    }
  }

  private func handleDeviceInfo(_ call: FlutterMethodCall, result: FlutterResult) {
    guard call.method == "getDeviceInfo" else {
      result(FlutterMethodNotImplemented)
      return
    }
    var sysInfo = utsname()
    uname(&sysInfo)
    let machine = withUnsafePointer(to: &sysInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
    }
    let v = ProcessInfo.processInfo.operatingSystemVersion
    result(["model": machine, "osVersion": "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"])
  }
}
