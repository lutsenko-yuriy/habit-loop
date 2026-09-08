// HAB-269 WU2 — Darwin notification posted by MarkShowupDoneIntent.perform()
// after a successful native write. AppDelegate observes this and forwards it
// to Dart via the voice_write_signal EventChannel, which invalidates
// dashboardRefreshSignalProvider (VoiceWriteSignalListener) — otherwise a
// live-in-background Flutter engine's caches would go stale after a
// Siri-triggered mark-done.
//
// Darwin notifications carry no payload — the mere posting is the signal;
// Dart doesn't need to know which showup changed, it just reloads everything.

import Foundation

enum VoiceWriteSignal {
  static let darwinNotificationName = "com.habitloop.voice_write_signal_posted" as CFString

  static func post() {
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(darwinNotificationName),
      nil, nil, true
    )
  }
}
