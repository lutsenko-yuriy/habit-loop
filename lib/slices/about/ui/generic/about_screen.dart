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
      final theme = Theme.of(context);
      final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
      final themedLicensePage = Theme(
        data: theme.copyWith(
          textTheme: isIOS ? theme.textTheme.apply(fontFamily: '.SF Pro Text') : theme.textTheme,
          scaffoldBackgroundColor: theme.colorScheme.surface,
          appBarTheme: theme.appBarTheme.copyWith(
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
        ),
        child: const LicensePage(applicationName: 'Habit Loop'),
      );
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        unawaited(
          Navigator.of(context).push(
            CupertinoPageRoute<void>(builder: (_) => themedLicensePage),
          ),
        );
      } else {
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => themedLicensePage),
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
