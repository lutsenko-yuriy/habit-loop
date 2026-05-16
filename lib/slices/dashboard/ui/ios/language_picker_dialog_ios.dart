import 'package:flutter/cupertino.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

/// Shows a [CupertinoActionSheet] with the given language [options] and returns
/// the selected [Locale], `null` for the system option, or `null` when dismissed.
///
/// Shared between [DashboardPageIos] and [OnboardingCarouselIos].
Future<Locale?> showCupertinoLanguagePicker(
  BuildContext context,
  List<({String label, Locale? locale})> options,
  Locale? currentOverride,
  AppLocalizations l10n,
) async {
  String prefixed(String label, Locale? locale) {
    final isSelected = locale == null ? currentOverride == null : currentOverride?.languageCode == locale.languageCode;
    return isSelected ? '✓ $label' : label;
  }

  final result = await showCupertinoModalPopup<(bool, Locale?)>(
    context: context,
    // ignore: use_build_context_synchronously
    builder: (ctx) => CupertinoActionSheet(
      title: Text(l10n.languagePickerTitle),
      actions: options.map((opt) {
        return CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, (opt.locale == null, opt.locale)),
          child: Text(prefixed(opt.label, opt.locale)),
        );
      }).toList(),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: Text(l10n.cancel),
      ),
    ),
  );

  if (result == null) return null;
  final (isSystem, locale) = result;
  return isSystem ? null : locale;
}
