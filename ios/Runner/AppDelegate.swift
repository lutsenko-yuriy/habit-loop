import Firebase
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, FlutterStreamHandler {
  private var deviceInfoChannel: FlutterMethodChannel?
  // HAB-269 WU2 — see VoiceRemoteConfigBridge.dart / VoiceWriteSignalListener.dart.
  private var voiceRemoteConfigChannel: FlutterMethodChannel?
  private var voiceWriteSignalChannel: FlutterEventChannel?
  private var voiceWriteSignalEventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // A backgrounded AppIntent never runs Dart's main(), so Firebase needs
    // configuring here too, or the native analytics calls silently no-op.
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    // Flutter 3.x no longer sets UNUserNotificationCenter.delegate automatically.
    // Without this, iOS has no delegate to call on notification tap, so the plugin's
    // didReceiveNotificationResponse is never invoked and navigation is silently dropped.
    // FlutterAppDelegate conforms to FlutterAppLifeCycleProvider, which implements
    // UNUserNotificationCenterDelegate and forwards to all registered plugin delegates
    // (including FlutterLocalNotificationsPlugin). Setting it here restores the chain.
    UNUserNotificationCenter.current().delegate = self

    // HAB-269 WU2 — observe the Darwin notification MarkShowupDoneIntent posts after
    // a successful native write (VoiceWriteSignal.post()), forwarding it to Dart via
    // voiceWriteSignalChannel below. Registered here (not didInitializeImplicitFlutterEngine)
    // since a backgrounded Siri mark-done can happen before the engine/controller exists —
    // the observer must be live from launch; only the eventSink handoff needs the channel.
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(),
      { _, observer, _, _, _ in
        guard let observer else { return }
        Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue().handleVoiceWriteSignal()
      },
      VoiceWriteSignal.darwinNotificationName,
      nil,
      .deliverImmediately
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  deinit {
    // Unlike AddObserver (which takes a bare CFString name), RemoveObserver's
    // API wants a CFNotificationName wrapper — the two functions disagree on
    // this, not a typo.
    CFNotificationCenterRemoveObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(),
      CFNotificationName(VoiceWriteSignal.darwinNotificationName),
      nil
    )
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

      voiceRemoteConfigChannel = FlutterMethodChannel(
        name: "com.habitloop.voice_remote_config",
        binaryMessenger: controller.binaryMessenger
      )
      voiceRemoteConfigChannel?.setMethodCallHandler { [weak self] call, result in
        self?.handleVoiceRemoteConfig(call, result: result)
      }

      voiceWriteSignalChannel = FlutterEventChannel(
        name: "com.habitloop.voice_write_signal",
        binaryMessenger: controller.binaryMessenger
      )
      voiceWriteSignalChannel?.setStreamHandler(self)
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

  private func handleVoiceRemoteConfig(_ call: FlutterMethodCall, result: FlutterResult) {
    guard call.method == "setVoiceMarkDoneEnabled" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any], let enabled = args["enabled"] as? Bool else {
      result(FlutterError(code: "bad_args", message: "enabled bool argument required", details: nil))
      return
    }
    UserDefaults.standard.set(enabled, forKey: VoiceFeatureFlag.userDefaultsKey)
    result(nil)
  }

  private func handleVoiceWriteSignal() {
    // CFNotificationCenter callbacks can fire on any thread; FlutterEventSink
    // must be called on the main thread.
    DispatchQueue.main.async { [weak self] in
      self?.voiceWriteSignalEventSink?(true)
    }
  }

  // MARK: - FlutterStreamHandler (voice_write_signal EventChannel)

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    voiceWriteSignalEventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    voiceWriteSignalEventSink = nil
    return nil
  }
}
