/// Spacing scale shared across the app's widgets.
///
/// Replaces scattered `EdgeInsets`/`SizedBox` magic numbers with a single
/// named scale (HAB-187 WU3, checkup finding `CHK-2026-07-20-heavy-7`).
/// Adoption is incremental: a numeric literal is only migrated to a token
/// when it already matches one of these values exactly, so migrating a
/// widget never changes its rendered layout.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}
