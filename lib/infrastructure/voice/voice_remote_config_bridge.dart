import 'package:flutter/services.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/app_version.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/feature_flags.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// HAB-269 WU2 — mirrors the `voice_mark_done_enabled` Remote Config flag (and,
/// since GH #464 WU7, the release-gated `checklister_integration_enabled`) into
/// native `UserDefaults`, since the Siri App Intents (`VoiceFeatureFlag.swift`)
/// have no live Dart process to read [RemoteConfigService] from directly.
///
/// Call [sync] once after every successful [RemoteConfigService] fetch (see
/// `main.dart`) — writes are cheap and idempotent, so calling it more than
/// once is harmless.
class VoiceRemoteConfigBridge {
  /// [appVersion] resolves the checklister release gate, as in [FeatureFlags.fromRemoteConfig].
  VoiceRemoteConfigBridge({MethodChannel? channel, String appVersion = unspecifiedAppVersion})
      : _channel = channel ?? const MethodChannel(_channelName),
        _appVersion = appVersion;

  static const _channelName = 'com.habitloop.voice_remote_config';

  /// Matches `VoiceFeatureFlag.userDefaultsKey` in Swift and the Remote
  /// Config key registered in `RemoteConfigDefaults`.
  static const flagKey = 'voice_mark_done_enabled';

  final MethodChannel _channel;
  final String _appVersion;

  /// Reads the current flag value and writes it to native `UserDefaults`.
  /// No-throw — a platform channel failure (e.g. Android, where no handler is
  /// registered, or a test environment) is swallowed, matching the no-throw
  /// contract every other `lib/infrastructure/` service follows.
  Future<void> sync(RemoteConfigService rc) async {
    await _set('setVoiceMarkDoneEnabled', rc.getBool(flagKey));
    final checklister = FeatureFlags.fromRemoteConfig(rc, appVersion: _appVersion).checklisterIntegrationEnabled;
    await _set('setChecklisterIntegrationEnabled', checklister);
  }

  Future<void> _set(String method, bool enabled) async {
    try {
      await _channel.invokeMethod<void>(method, {'enabled': enabled});
    } catch (_) {
      // Platform channel unavailable — safe to ignore, see class doc.
    }
  }
}
