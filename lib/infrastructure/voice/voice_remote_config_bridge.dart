import 'package:flutter/services.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// HAB-269 WU2 — mirrors the `voice_mark_done_enabled` Remote Config flag into
/// native `UserDefaults`, since the Siri App Intents (`VoiceFeatureFlag.swift`)
/// have no live Dart process to read [RemoteConfigService] from directly.
///
/// Call [sync] once after every successful [RemoteConfigService] fetch (see
/// `main.dart`) — writes are cheap and idempotent, so calling it more than
/// once is harmless.
class VoiceRemoteConfigBridge {
  VoiceRemoteConfigBridge({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.habitloop.voice_remote_config';

  /// Matches `VoiceFeatureFlag.userDefaultsKey` in Swift and the Remote
  /// Config key registered in `RemoteConfigDefaults`.
  static const flagKey = 'voice_mark_done_enabled';

  final MethodChannel _channel;

  /// Reads the current flag value and writes it to native `UserDefaults`.
  /// No-throw — a platform channel failure (e.g. Android, where no handler is
  /// registered, or a test environment) is swallowed, matching the no-throw
  /// contract every other `lib/infrastructure/` service follows.
  Future<void> sync(RemoteConfigService rc) async {
    final enabled = rc.getBool(flagKey);
    try {
      await _channel.invokeMethod<void>('setVoiceMarkDoneEnabled', {'enabled': enabled});
    } catch (_) {
      // Platform channel unavailable — safe to ignore, see class doc.
    }
  }
}
