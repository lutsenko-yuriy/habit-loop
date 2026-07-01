import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';

/// In-memory [NotificationService] test double that records all calls.
///
/// Use in unit tests that need to assert on notification scheduling or
/// cancellation without touching the real [flutter_local_notifications] plugin.
///
/// Example:
/// ```dart
/// final fake = FakeNotificationService();
/// // ... wire into container ...
/// expect(fake.scheduledReminders, hasLength(1));
/// expect(fake.scheduledReminders.first.showup.id, equals('su-1'));
/// ```
final class FakeNotificationService implements NotificationService {
  /// Whether [requestPermission] should return `true` (granted).
  ///
  /// Settable by tests to simulate permission grant or denial.
  bool permissionGranted = false;

  /// Records of all [scheduleShowupReminder] calls in order.
  final List<({Showup showup, Pact pact, String titleText, String bodyText})> scheduledReminders = [];

  /// Records of all [scheduleDeadlineNotification] calls in order.
  final List<({Showup showup, String titleText, String bodyText})> scheduledDeadlines = [];

  /// [showupId] values passed to [cancelShowupReminder] in order.
  final List<String> cancelledShowupIds = [];

  /// [pactId] values passed to [cancelAllRemindersForPact] in order.
  final List<String> cancelledPactIds = [];

  /// [showupIds] lists passed to [cancelAllRemindersForPact] in order
  /// (parallel to [cancelledPactIds]).
  final List<List<String>> cancelledPactShowupIds = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> scheduleShowupReminder({
    required Showup showup,
    required Pact pact,
    required String titleText,
    required String bodyText,
  }) async {
    scheduledReminders.add((showup: showup, pact: pact, titleText: titleText, bodyText: bodyText));
  }

  @override
  Future<void> scheduleDeadlineNotification({
    required Showup showup,
    required String titleText,
    required String bodyText,
  }) async {
    scheduledDeadlines.add((
      showup: showup,
      titleText: titleText,
      bodyText: bodyText,
    ));
  }

  @override
  Future<void> cancelShowupReminder(String showupId) async {
    cancelledShowupIds.add(showupId);
  }

  @override
  Future<void> cancelAllRemindersForPact(
    String pactId, {
    List<String> showupIds = const [],
  }) async {
    cancelledPactIds.add(pactId);
    cancelledPactShowupIds.add(List.unmodifiable(showupIds));
  }

  @override
  Future<List<PendingNotificationInfo>> getPendingNotifications() async => const [];

  @override
  Future<NotificationLaunchInfo?> getAppLaunchDetails() async => null;

  /// Resets all recorded calls and the permission flag.
  void reset() {
    permissionGranted = false;
    scheduledReminders.clear();
    scheduledDeadlines.clear();
    cancelledShowupIds.clear();
    cancelledPactIds.clear();
    cancelledPactShowupIds.clear();
  }
}
