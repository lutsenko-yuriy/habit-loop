// HAB-269 WU1 — reads the `voice_mark_done_enabled` Remote Config flag.
// `VoiceRemoteConfigBridge` (WU2) mirrors the flag into UserDefaults after each RC
// fetch, since the native perform() path runs without a live Dart/RemoteConfigService
// instance. WU1 never writes this key, so it defaults `false` until WU2 lands —
// see docs/FEATURE_TOGGLES.md.

import Foundation

enum VoiceFeatureFlag {
  static let userDefaultsKey = "voice_mark_done_enabled"

  static var markDoneEnabled: Bool {
    UserDefaults.standard.bool(forKey: userDefaultsKey)
  }
}
