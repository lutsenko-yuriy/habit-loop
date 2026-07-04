import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutPageIos extends ConsumerWidget {
  final VoidCallback onLicencesTapped;

  const AboutPageIos({super.key, required this.onLicencesTapped});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final info = ref.watch(packageInfoProvider).valueOrNull;
    final versionText = _versionText(info);

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
              _AppInfoHeader(versionText: versionText),
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

class _AppInfoHeader extends StatelessWidget {
  final String? versionText;

  const _AppInfoHeader({this.versionText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          const Text(
            'Habit Loop',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (versionText != null) ...[
            const SizedBox(height: 4),
            Text(
              versionText!,
              style: const TextStyle(fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            '© 2026 Iurii Lutsenko',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

String? _versionText(PackageInfo? info) {
  if (info == null) return null;
  return 'Version ${info.version} (build ${info.buildNumber})';
}
