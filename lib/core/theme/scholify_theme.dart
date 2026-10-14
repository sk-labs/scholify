import 'package:flutter/material.dart';

import 'scholify_colors.dart';

/// Central Scholify theme: professional education identity.
///
/// Provides a full light and dark [ThemeData] with:
/// - Academic navy / scholar teal / achievement amber color schemes
/// - A defined type scale (display → label) with tuned weights & spacing
/// - Consistent component styling (cards, buttons, inputs, nav, dialogs)
abstract final class ScholifyTheme {
  // ── Typography ─────────────────────────────────────────────────────
  // A clear hierarchy: every screen reads the same way.
  static const TextTheme typeScale = TextTheme(
    displayLarge: TextStyle(
      fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.1,
    ),
    displayMedium: TextStyle(
      fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.15,
    ),
    headlineLarge: TextStyle(
      fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.25, height: 1.2,
    ),
    headlineMedium: TextStyle(
      fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0, height: 1.25,
    ),
    headlineSmall: TextStyle(
      fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 0, height: 1.3,
    ),
    titleLarge: TextStyle(
      fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.35,
    ),
    titleMedium: TextStyle(
      fontSize: 15.5, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.4,
    ),
    titleSmall: TextStyle(
      fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2, height: 1.4,
    ),
    bodyLarge: TextStyle(
      fontSize: 15.5, fontWeight: FontWeight.w400, letterSpacing: 0.1, height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.15, height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w400, letterSpacing: 0.2, height: 1.5,
    ),
    labelLarge: TextStyle(
      fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.4, height: 1.4,
    ),
    labelMedium: TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.4, height: 1.4,
    ),
    labelSmall: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, height: 1.4,
    ),
  );

  static const _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );

  static const _dialogShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(20)),
  );

  // ── Light theme ────────────────────────────────────────────────────
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: ScholifyColors.academicNavy,
      primary: ScholifyColors.academicNavy,
      secondary: ScholifyColors.scholarTeal,
      tertiary: ScholifyColors.achievementAmber,
      surface: ScholifyColors.paperWhite,
      error: ScholifyColors.error,
      brightness: Brightness.light,
    );
    return _build(scheme, Brightness.light);
  }

  // ── Dark theme ─────────────────────────────────────────────────────
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: ScholifyColors.academicNavy,
      primary: const Color(0xFF8FB3E8),
      secondary: const Color(0xFF5FC6C5),
      tertiary: ScholifyColors.amberSoft,
      surface: ScholifyColors.surfaceDark,
      error: ScholifyColors.errorDark,
      brightness: Brightness.dark,
    );
    return _build(scheme, Brightness.dark);
  }

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: typeScale,
      scaffoldBackgroundColor:
          isDark ? ScholifyColors.canvasDark : ScholifyColors.canvasLight,
      // ── App bar: academic navy in light mode, deep surface in dark ──
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? ScholifyColors.surfaceDark : ScholifyColors.academicNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: typeScale.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // ── Cards: soft, rounded, subtle ──
      cardTheme: CardThemeData(
        shape: _cardShape,
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? ScholifyColors.surfaceDarkElevated : scheme.surface,
        surfaceTintColor: scheme.primary,
      ),
      // ── Buttons ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: typeScale.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: typeScale.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: typeScale.labelLarge,
        ),
      ),
      // ── Inputs ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? ScholifyColors.surfaceDarkElevated
            : ScholifyColors.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : ScholifyColors.slate100,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: typeScale.bodyMedium,
        hintStyle: typeScale.bodyMedium?.copyWith(
          color: isDark ? Colors.white38 : ScholifyColors.slate400,
        ),
      ),
      // ── Navigation ──
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor:
            isDark ? ScholifyColors.surfaceDark : scheme.surface,
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
        unselectedIconTheme: IconThemeData(
          color: isDark ? Colors.white54 : ScholifyColors.slate400,
          size: 22,
        ),
        selectedLabelTextStyle: typeScale.labelSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: typeScale.labelSmall?.copyWith(
          color: isDark ? Colors.white54 : ScholifyColors.slate400,
        ),
        indicatorColor: ScholifyColors.tint(
          scheme.primary,
          isDark ? 0.22 : 0.12,
        ),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? ScholifyColors.surfaceDark : scheme.surface,
        indicatorColor: ScholifyColors.tint(
          scheme.primary,
          isDark ? 0.22 : 0.12,
        ),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return typeScale.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            );
          }
          return typeScale.labelSmall?.copyWith(
            color: isDark ? Colors.white54 : ScholifyColors.slate400,
          );
        }),
      ),
      // ── Chips, dialogs, misc ──
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        labelStyle: typeScale.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dialogTheme: const DialogThemeData(shape: _dialogShape),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white10 : ScholifyColors.slate100,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.secondary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ScholifyColors.tint(scheme.secondary, 0.4);
          }
          return null;
        }),
      ),
    );
  }
}
