import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/about/application/feedback_service.dart';
import 'package:habit_loop/slices/about/ui/generic/about_info_header.dart';

class AboutPageIos extends ConsumerWidget {
  const AboutPageIos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final info = ref.watch(packageInfoProvider).valueOrNull;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        middle: Text(l10n.aboutTitle),
      ),
      child: SafeArea(
        bottom: false,
        child: Material(
          type: MaterialType.transparency,
          child: ListView(
            children: [
              AboutInfoHeader(versionText: aboutVersionText(info)),
              Container(height: 0.5, color: CupertinoColors.separator.resolveFrom(context)),
              CupertinoListTile(
                backgroundColor: CupertinoColors.transparent,
                title: Text(l10n.aboutSendFeedback),
                trailing: const Icon(CupertinoIcons.forward),
                onTap: () async {
                  await openFeedback(
                    deviceInfo: await ref.read(deviceInfoProvider.future),
                    packageInfo: await ref.read(packageInfoProvider.future),
                    analytics: ref.read(analyticsServiceProvider),
                    crashlytics: ref.read(crashlyticsServiceProvider),
                    launch: ref.read(launchUrlProvider),
                  );
                },
              ),
              Container(height: 0.5, color: CupertinoColors.separator.resolveFrom(context)),
            ],
          ),
        ),
      ),
    );
  }
}
