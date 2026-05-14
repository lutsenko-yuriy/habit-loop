import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';

class SyncStatusOpenedEvent extends AnalyticsEvent {
  SyncStatusOpenedEvent({required this.state});

  final String state;

  @override
  String get name => 'sync_status_opened';

  @override
  Map<String, Object> toParameters() => {'state': state};
}

class ManualSyncTriggeredEvent extends AnalyticsEvent {
  ManualSyncTriggeredEvent({required this.fromState});

  final String fromState;

  @override
  String get name => 'manual_sync_triggered';

  @override
  Map<String, Object> toParameters() => {'from_state': fromState};
}

class SignInWithGoogleTappedEvent extends AnalyticsEvent {
  @override
  String get name => 'sign_in_with_google_tapped';

  @override
  Map<String, Object> toParameters() => {};
}

class SignInWithGoogleSucceededEvent extends AnalyticsEvent {
  @override
  String get name => 'sign_in_with_google_succeeded';

  @override
  Map<String, Object> toParameters() => {};
}

class SignInWithGoogleFailedEvent extends AnalyticsEvent {
  SignInWithGoogleFailedEvent({required this.errorCode});

  final String errorCode;

  @override
  String get name => 'sign_in_with_google_failed';

  @override
  Map<String, Object> toParameters() => {'error_code': errorCode};
}

class SignOutTappedEvent extends AnalyticsEvent {
  SignOutTappedEvent({required this.fromState});

  final String fromState;

  @override
  String get name => 'sign_out_tapped';

  @override
  Map<String, Object> toParameters() => {'from_state': fromState};
}
