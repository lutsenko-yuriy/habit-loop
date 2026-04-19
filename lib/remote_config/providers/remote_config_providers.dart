import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/remote_config/data/noop_remote_config_service.dart';
import 'package:habit_loop/remote_config/domain/remote_config_service.dart';

/// Provides the active [RemoteConfigService] to the app.
///
/// Defaults to [NoopRemoteConfigService] so tests and non-Firebase environments
/// work without any additional setup. Override in release builds in `main.dart`
/// after calling `FirebaseRemoteConfigService.initialize()`.
final remoteConfigServiceProvider = Provider<RemoteConfigService>(
  (ref) => NoopRemoteConfigService(),
);
