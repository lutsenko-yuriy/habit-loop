import 'package:characters/characters.dart';

/// Maximum accepted display-name length (HAB-232) — caps what eventually
/// reaches notification copy. Enforced both by the platform bodies'
/// `LengthLimitingTextInputFormatter` and, defensively, in `EnterNameScreen`
/// and `openChangeNameDialog`.
const int enterNameMaxLength = 40;

/// Size of [EnterNameIllustration] — matches the onboarding carousel's own
/// slide illustrations exactly (200 wide, `BoxFit.contain` inside a 320×240
/// (4:3) viewBox renders at 150 tall), per user request after seeing the
/// smaller version live (HAB-272). The screen's existing `SingleChildScrollView`
/// absorbs any keyboard overflow, same as it already does for a long
/// personalized name or a small device.
const double enterNameIllustrationWidth = 200;
const double enterNameIllustrationHeight = 150;

/// Caps [value] to [enterNameMaxLength] by grapheme cluster (via
/// `.characters`), not UTF-16 code unit (`.length`/`.substring`) — a
/// multi-code-point grapheme (ZWJ sequence, decomposed diacritic) could
/// otherwise be split mid-sequence and stored mangled.
///
/// Shared by `EnterNameScreen` (a name arriving via sync or seeded straight
/// into the controller bypasses the field's input formatter) and
/// `openChangeNameDialog` (same concern, different entry point) — both need
/// a defensive cap in addition to the formatter's typed-input cap.
String capToMaxNameLength(String value) {
  final chars = value.characters;
  if (chars.length <= enterNameMaxLength) return value;
  return chars.take(enterNameMaxLength).toString();
}
