import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    void onLicencesTapped() {
      if (!context.mounted) return;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        unawaited(
          Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => const LicensePage(),
            ),
          ),
        );
      } else {
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const LicensePage(),
            ),
          ),
        );
      }
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AboutPageIos(onLicencesTapped: onLicencesTapped);
    }
    return AboutPageAndroid(onLicencesTapped: onLicencesTapped);
  }
}
