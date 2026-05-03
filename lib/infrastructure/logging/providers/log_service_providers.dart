import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/logging/contracts/log_service.dart';
import 'package:habit_loop/infrastructure/logging/data/noop_log_service.dart';

/// Riverpod provider for [LogService].
///
/// Defaults to [NoopLogService] — silent, safe for tests.
///
/// In `main.dart`, override with [TalkerLogService] for debug/profile builds:
/// ```dart
/// logServiceProvider.overrideWithValue(TalkerLogService(talker)),
/// ```
///
/// Do NOT override in release builds; `TalkerLogService` itself is no-op
/// in release mode, but we keep the noop as the default to avoid importing
/// the Talker SDK in release builds unnecessarily.
final logServiceProvider = Provider<LogService>((ref) => NoopLogService());
