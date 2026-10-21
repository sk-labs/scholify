import 'package:flutter/material.dart';

/// Scholify's professional education color palette.
///
/// Designed around academic identity:
/// - **Academic Navy** — trust, tradition, institutional authority (primary)
/// - **Scholar Teal** — growth, learning, progress (secondary)
/// - **Achievement Amber** — honors, success, highlights (tertiary accent)
/// - Warm slate neutrals keep long admin sessions easy on the eyes.
abstract final class ScholifyColors {
  // ── Brand ──────────────────────────────────────────────────────────
  /// Deep academic navy — primary brand color.
  static const Color academicNavy = Color(0xFF1B2F4B);

  /// Lighter navy for gradients and large surfaces.
  static const Color navyLight = Color(0xFF2A4568);

  /// Deepest navy for the login branding panel / dark surfaces.
  static const Color navyDeep = Color(0xFF122036);

  /// Scholar teal — secondary brand color (growth, learning).
  static const Color scholarTeal = Color(0xFF0E7C7B);

  /// Soft teal for light tints.
  static const Color tealSoft = Color(0xFF3D9B9A);

  /// Achievement amber — tertiary accent (honors, highlights, warnings).
  static const Color achievementAmber = Color(0xFFD9A21B);

  /// Soft amber for light tints.
  static const Color amberSoft = Color(0xFFE8B93E);

  /// [accent] adjusted to stay readable as a foreground on its own
  /// translucent tint: unchanged in light mode, lightened toward
  /// white in dark mode — dark accents (navy especially) otherwise
  /// vanish on dark surfaces.
  static Color onTint(Color accent, Brightness brightness) =>
      brightness == Brightness.dark
          ? Color.lerp(accent, Colors.white, 0.45)!
          : accent;

  /// Background tint for a small accent tile (icon medallion, badge):
  /// a faint wash of the accent in light mode; in dark mode a
  /// stronger wash of the lightened accent, since a dark accent at
  /// low alpha disappears on dark surfaces.
  static Color tintOf(Color accent, Brightness brightness) =>
      brightness == Brightness.dark
          ? onTint(accent, brightness).withValues(alpha: 0.25)
          : accent.withValues(alpha: 0.12);

  // ── Light neutrals ─────────────────────────────────────────────────
  static const Color paperWhite = Color(0xFFFFFFFF);
  static const Color canvasLight = Color(0xFFF6F7F9);
  static const Color slate50 = Color(0xFFF1F3F6);
  static const Color slate100 = Color(0xFFE7EAF0);
  static const Color slate200 = Color(0xFFD5DAE3);
  static const Color slate400 = Color(0xFF8A94A6);
  static const Color slate600 = Color(0xFF4D586C);
  static const Color slate800 = Color(0xFF232B3A);

  // ── Dark neutrals ──────────────────────────────────────────────────
  static const Color canvasDark = Color(0xFF0F1622);
  static const Color surfaceDark = Color(0xFF182233);
  static const Color surfaceDarkElevated = Color(0xFF1F2C42);

  // ── Semantic ───────────────────────────────────────────────────────
  static const Color success = Color(0xFF1E9E6A);
  static const Color successDark = Color(0xFF35C48D);
  static const Color warning = Color(0xFFD9A21B);
  static const Color error = Color(0xFFD64545);
  static const Color errorDark = Color(0xFFE57373);
  static const Color info = Color(0xFF2F80ED);

  // ── Module accent colors (used for dashboard module cards) ─────────
  static const Color accentStudents = Color(0xFF2F80ED);
  static const Color accentAcademics = Color(0xFF0E7C7B);
  static const Color accentFinance = Color(0xFF1E9E6A);
  static const Color accentOperations = Color(0xFF8E5BD6);
  static const Color accentComms = Color(0xFFE8734A);
  static const Color accentAdmin = Color(0xFF1B2F4B);

  /// Tints a color for icon medallions / soft backgrounds in light mode.
  static Color tint(Color color, [double opacity = 0.12]) =>
      color.withValues(alpha: opacity);
}
