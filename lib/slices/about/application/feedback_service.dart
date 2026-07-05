import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/about/analytics/about_analytics_events.dart';
import 'package:url_launcher/url_launcher.dart';

const _feedbackBaseUrl = 'https://forms.gle/EttqwfhCvCzRrWuSA';

Future<void> openFeedback(WidgetRef ref) async {
  final deviceInfo = await ref.read(deviceInfoProvider.future);
  final packageInfo = await ref.read(packageInfoProvider.future);

  final uri = Uri.parse(_feedbackBaseUrl).replace(queryParameters: {
    if (deviceInfo.model.isNotEmpty) 'model': deviceInfo.model,
    if (deviceInfo.osVersion.isNotEmpty) 'os': deviceInfo.osVersion,
    if (packageInfo != null && packageInfo.buildNumber.isNotEmpty) 'build': packageInfo.buildNumber,
  });

  await ref.read(analyticsServiceProvider).logEvent(const FeedbackTappedEvent());
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
