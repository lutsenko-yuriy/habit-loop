import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';

final class SyncStatusOpenedEvent extends AnalyticsEvent {
  SyncStatusOpenedEvent({required this.state});

  final String state;

  @override
  String get name => 'sync_status_opened';

  @override
  Map<String, Object> toParameters() => {'state': state};
}

final class ManualSyncTriggeredEvent extends AnalyticsEvent {
  ManualSyncTriggeredEvent({required this.fromState});

  final String fromState;

  @override
  String get name => 'manual_sync_triggered';

  @override
  Map<String, Object> toParameters() => {'from_state': fromState};
}

final class SignInWithGoogleTappedEvent extends AnalyticsEvent {
  @override
  String get name => 'sign_in_with_google_tapped';

  @override
  Map<String, Object> toParameters() => {};
}

final class SignInWithGoogleSucceededEvent extends AnalyticsEvent {
  @override
  String get name => 'sign_in_with_google_succeeded';

  @override
  Map<String, Object> toParameters() => {};
}

final class SignInWithGoogleFailedEvent extends AnalyticsEvent {
  SignInWithGoogleFailedEvent({required this.errorCode});

  final String errorCode;

  @override
  String get name => 'sign_in_with_google_failed';

  @override
  Map<String, Object> toParameters() => {'error_code': errorCode};
}

final class SignOutTappedEvent extends AnalyticsEvent {
  SignOutTappedEvent({required this.fromState});

  final String fromState;

  @override
  String get name => 'sign_out_tapped';

  @override
  Map<String, Object> toParameters() => {'from_state': fromState};
}

final class FullSyncTriggeredEvent extends AnalyticsEvent {
  FullSyncTriggeredEvent({required this.fromState});

  final String fromState;

  @override
  String get name => 'full_sync_triggered';

  @override
  Map<String, Object> toParameters() => {'from_state': fromState};
}

final class FullSyncCompletedEvent extends AnalyticsEvent {
  FullSyncCompletedEvent({required this.fromState});

  final String fromState;

  @override
  String get name => 'full_sync_completed';

  @override
  Map<String, Object> toParameters() => {'from_state': fromState};
}

final class FullSyncFailedEvent extends AnalyticsEvent {
  FullSyncFailedEvent({required this.fromState, required this.recordsFailed});

  final String fromState;
  final int recordsFailed;

  @override
  String get name => 'full_sync_failed';

  @override
  Map<String, Object> toParameters() => {'from_state': fromState, 'records_failed': recordsFailed};
}
