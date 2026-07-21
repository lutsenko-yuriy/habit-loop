/// Spacing scale shared across the app's widgets.
///
/// Replaces scattered `EdgeInsets`/`SizedBox` magic numbers with a single
/// numeric scale (HAB-187 WU7, renamed from the original named `xs`-`xl`
/// scale — see `CHK-2026-07-20-heavy-7` for the original migration and the
/// WU7 note in `docs/knowledge/notes/HAB-187.md` for the rename rationale).
/// Each constant is named after its own value (`s8` == 8), so the call site
/// stays self-documenting without needing to memorize a `xs`/`sm`/`md`
/// letter scale. Adoption is incremental: a numeric literal is only
/// migrated to a token when it already matches one of these values exactly,
/// so migrating a widget never changes its rendered layout.
abstract final class AppSpacing {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
}
