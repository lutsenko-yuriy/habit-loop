import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/about/analytics/about_analytics_events.dart';
import 'package:habit_loop/slices/about/ui/android/about_page_android.dart';
import 'package:habit_loop/slices/about/ui/ios/about_page_ios.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(
        () => ref.read(analyticsServiceProvider).logScreenView(const AboutAnalyticsScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const AboutPageIos();
    }
    return const AboutPageAndroid();
  }
}
