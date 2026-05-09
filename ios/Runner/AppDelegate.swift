import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
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
  }
}
