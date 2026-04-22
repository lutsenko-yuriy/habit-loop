import 'package:flutter/widgets.dart';

/// Platform-agnostic two-column label/value row used in the commitment step's
/// summary card. Extracted from `commitment_step_ios.dart` and
/// `commitment_step_android.dart` where the same layout was duplicated with
/// only the label color differing (Cupertino `systemGrey` vs Material
/// `onSurfaceVariant`).
///
/// The label column is a fixed 110px wide so successive rows align cleanly;
/// the value takes the remaining horizontal space.
class SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  /// Colour for the label text. Pass a platform-idiom colour from the call
  /// site (e.g. `CupertinoColors.systemGrey` on iOS or
  /// `Theme.of(context).colorScheme.onSurfaceVariant` on Android) rather than
  /// hard-coding one here.
  final Color? labelColor;

  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
