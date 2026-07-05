import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';
import 'package:habit_loop/slices/about/analytics/about_analytics_events.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _feedbackBaseUrl = 'https://forms.gle/EttqwfhCvCzRrWuSA';

Future<void> openFeedback({
  required ({String model, String osVersion}) deviceInfo,
  required PackageInfo? packageInfo,
  required AnalyticsService analytics,
  required CrashlyticsService crashlytics,
  required Future<void> Function(Uri) launch,
}) async {
  final uri = Uri.parse(_feedbackBaseUrl).replace(queryParameters: {
    if (deviceInfo.model.isNotEmpty) 'model': deviceInfo.model,
    if (deviceInfo.osVersion.isNotEmpty) 'os': deviceInfo.osVersion,
    if (packageInfo != null && packageInfo.buildNumber.isNotEmpty) 'build': packageInfo.buildNumber,
  });

  await analytics.logEvent(const FeedbackTappedEvent());
  try {
    await launch(uri);
  } catch (e, st) {
    await crashlytics.recordError(e, st, information: ['openFeedback']);
  }
}
