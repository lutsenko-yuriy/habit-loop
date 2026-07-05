import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/about/application/feedback_service.dart';
import 'package:habit_loop/slices/about/ui/generic/about_info_header.dart';

class AboutPageAndroid extends ConsumerWidget {
  const AboutPageAndroid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final info = ref.watch(packageInfoProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutTitle),
      ),
      body: ListView(
        children: [
          AboutInfoHeader(versionText: aboutVersionText(info)),
          ListTile(
            title: Text(l10n.aboutSendFeedback),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await openFeedback(
                deviceInfo: await ref.read(deviceInfoProvider.future),
                packageInfo: await ref.read(packageInfoProvider.future),
                analytics: ref.read(analyticsServiceProvider),
                crashlytics: ref.read(crashlyticsServiceProvider),
              );
            },
          ),
        ],
      ),
    );
  }
}
