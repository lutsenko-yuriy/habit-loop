import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';

/// No-op [NotificationService] used as the default when the real plugin is not
/// wired in (tests, debug/profile builds).
///
/// All methods are silent no-ops returning safe defaults. This ensures call
/// sites can always use `ref.read(notificationServiceProvider)` without null
/// guards, and tests that do not care about notifications remain unaffected.
final class NoopNotificationService implements NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleShowupReminder({
    required Showup showup,
    required Pact pact,
    required String titleText,
    required String bodyText,
  }) async {}

  @override
  Future<void> scheduleDeadlineNotification({
    required Showup showup,
    required String titleText,
    required String bodyText,
  }) async {}

  @override
  Future<void> cancelShowupReminder(String showupId) async {}

  @override
  Future<void> cancelAllRemindersForPact(
    String pactId, {
    List<String> showupIds = const [],
  }) async {}

  @override
  Future<List<PendingNotificationInfo>> getPendingNotifications() async => const [];

  @override
  Future<NotificationLaunchInfo?> getAppLaunchDetails() async => null;
}
