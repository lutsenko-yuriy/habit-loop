import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show LicenseEntry, LicenseRegistry;
import 'package:flutter/material.dart' show Theme;
import 'package:habit_loop/l10n/generated/app_localizations.dart';

class CupertinoLicensesPage extends StatefulWidget {
  const CupertinoLicensesPage({super.key});

  @override
  State<CupertinoLicensesPage> createState() => _CupertinoLicensesPageState();
}

class _CupertinoLicensesPageState extends State<CupertinoLicensesPage> {
  late final Future<_LicenseData> _future = _loadLicenses();

  Future<_LicenseData> _loadLicenses() async {
    final map = <String, List<LicenseEntry>>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        map.putIfAbsent(package, () => []).add(entry);
      }
    }
    final packages = map.keys.toList()..sort();
    return _LicenseData(packages: packages, entriesByPackage: map);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surface = Theme.of(context).colorScheme.surface;
    final mq = MediaQuery.of(context);
    return CupertinoPageScaffold(
      backgroundColor: surface,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: surface,
        middle: Text(l10n.aboutLicences),
      ),
      child: FutureBuilder<_LicenseData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CupertinoActivityIndicator());
          }
          final data = snapshot.data!;
          return ListView.separated(
            padding: EdgeInsets.only(
              top: mq.padding.top,
              bottom: mq.padding.bottom,
            ),
            itemCount: data.packages.length,
            separatorBuilder: (_, __) => Container(
              height: 0.5,
              color: CupertinoColors.separator.resolveFrom(context),
            ),
            itemBuilder: (context, index) {
              final package = data.packages[index];
              final count = data.entriesByPackage[package]!.length;
              return CupertinoListTile(
                backgroundColor: CupertinoColors.transparent,
                title: Text(package),
                additionalInfo: Text('$count'),
                trailing: const Icon(CupertinoIcons.forward),
                onTap: () => unawaited(
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => _LicenseDetailPage(
                        package: package,
                        entries: data.entriesByPackage[package]!,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LicenseDetailPage extends StatelessWidget {
  final String package;
  final List<LicenseEntry> entries;

  const _LicenseDetailPage({required this.package, required this.entries});

  @override
  Widget build(BuildContext context) {
    final paragraphs = [for (final e in entries) ...e.paragraphs];
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final mq = MediaQuery.of(context);
    return CupertinoPageScaffold(
      backgroundColor: surface,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: surface,
        middle: Text(package),
      ),
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: mq.padding.top + 16,
          left: 16,
          right: 16,
          bottom: mq.padding.bottom + 16,
        ),
        itemCount: paragraphs.length,
        itemBuilder: (context, index) {
          final p = paragraphs[index];
          return Padding(
            padding: EdgeInsets.only(left: p.indent * 16.0, bottom: 8),
            child: Text(
              p.text,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: onSurface,
                fontWeight: FontWeight.normal,
                decoration: TextDecoration.none,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LicenseData {
  final List<String> packages;
  final Map<String, List<LicenseEntry>> entriesByPackage;

  const _LicenseData({required this.packages, required this.entriesByPackage});
}
