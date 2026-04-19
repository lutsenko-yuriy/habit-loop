import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/remote_config/data/noop_remote_config_service.dart';
import 'package:habit_loop/remote_config/domain/remote_config_service.dart';

/// Provides the active [RemoteConfigService] to the app.
///
/// Defaults to [NoopRemoteConfigService] so tests and non-Firebase environments
/// work without any additional setup. `main.dart` overrides this with
/// [FirebaseRemoteConfigService] after `Firebase.initializeApp()` completes,
/// but only in release mode.
final remoteConfigServiceProvider = Provider<RemoteConfigService>(
  (ref) => NoopRemoteConfigService(),
);
