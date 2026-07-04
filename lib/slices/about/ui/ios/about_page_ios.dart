import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/about/ui/generic/about_info_header.dart';

class AboutPageIos extends ConsumerWidget {
  final VoidCallback onLicencesTapped;

  const AboutPageIos({super.key, required this.onLicencesTapped});

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
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile.notched(
                    title: Text(l10n.aboutSendFeedback),
                    trailing: const Icon(CupertinoIcons.forward),
                    onTap: null,
                  ),
                  CupertinoListTile.notched(
                    title: Text(l10n.aboutLicences),
                    trailing: const Icon(CupertinoIcons.forward),
                    onTap: onLicencesTapped,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
