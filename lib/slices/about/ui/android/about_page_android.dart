import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutPageAndroid extends ConsumerWidget {
  final VoidCallback onLicencesTapped;

  const AboutPageAndroid({super.key, required this.onLicencesTapped});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final info = ref.watch(packageInfoProvider).valueOrNull;
    final versionText = _versionText(info);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutTitle),
      ),
      body: ListView(
        children: [
          _AppInfoHeader(versionText: versionText),
          ListTile(
            title: Text(l10n.aboutSendFeedback),
            trailing: const Icon(Icons.chevron_right),
            onTap: null,
          ),
          ListTile(
            title: Text(l10n.aboutLicences),
            trailing: const Icon(Icons.chevron_right),
            onTap: onLicencesTapped,
          ),
        ],
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
              style: Theme.of(context).textTheme.bodySmall,
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
