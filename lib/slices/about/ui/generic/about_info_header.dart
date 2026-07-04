import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutInfoHeader extends StatelessWidget {
  final String? versionText;

  const AboutInfoHeader({super.key, this.versionText});

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

String? aboutVersionText(PackageInfo? info) {
  if (info == null) return null;
  return 'Version ${info.version} (build ${info.buildNumber})';
}
