import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

/// Shows a [SimpleDialog] with the given language [options] and returns the
/// selected [Locale], `null` for the system option, or `null` when dismissed.
///
/// Shared between [DashboardPageAndroid] and [OnboardingCarouselAndroid].
Future<Locale?> showMaterialLanguagePicker(
  BuildContext context,
  List<({String label, Locale? locale})> options,
  Locale? currentOverride,
  AppLocalizations l10n,
) async {
  final result = await showDialog<(bool, Locale?)>(
    context: context,
    // ignore: use_build_context_synchronously
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.languagePickerTitle),
      children: options.map((opt) {
        final isSelected =
            opt.locale == null ? currentOverride == null : currentOverride?.languageCode == opt.locale!.languageCode;
        return SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, (opt.locale == null, opt.locale)),
          child: Row(
            children: [
              SizedBox(width: 28, child: isSelected ? const Icon(Icons.check, size: 18) : null),
              Text(opt.label),
            ],
          ),
        );
      }).toList(),
    ),
  );

  if (result == null) return null;
  final (isSystem, locale) = result;
  return isSystem ? null : locale;
}
