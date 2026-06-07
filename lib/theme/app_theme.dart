import 'package:flutter/material.dart';

/// Spacing scale (4-based) used across the app.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Corner radius scale.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 28;
}

/// Semantic colors that adapt per brightness. Read via
/// `Theme.of(context).extension<AppColors>()!`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.successSurface,
    required this.danger,
    required this.dangerSurface,
    required this.muted,
    required this.elevatedSurface,
  });

  final Color success;
  final Color successSurface;
  final Color danger;
  final Color dangerSurface;
  final Color muted;
  final Color elevatedSurface;

  static const light = AppColors(
    success: Color(0xFF059669),
    successSurface: Color(0xFFECFDF5),
    danger: Color(0xFFDC2626),
    dangerSurface: Color(0xFFFEF2F2),
    muted: Color(0xFF6B7280),
    elevatedSurface: Color(0xFFFFFFFF),
  );

  static const dark = AppColors(
    success: Color(0xFF34D399),
    successSurface: Color(0xFF0F2A1E),
    danger: Color(0xFFF87171),
    dangerSurface: Color(0xFF2A1416),
    muted: Color(0xFF8B949E),
    elevatedSurface: Color(0xFF1C2230),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? successSurface,
    Color? danger,
    Color? dangerSurface,
    Color? muted,
    Color? elevatedSurface,
  }) {
    return AppColors(
      success: success ?? this.success,
      successSurface: successSurface ?? this.successSurface,
      danger: danger ?? this.danger,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      muted: muted ?? this.muted,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
    );
  }
}

/// Centralized clean-minimal theme with a properly tuned dark variant.
abstract final class AppTheme {
  static const Color _accentLight = Color(0xFF2563EB); // blue-600
  static const Color _accentDark = Color(0xFF4F9CF9); // brighter for dark

  // Light palette
  static const Color _lightScaffold = Color(0xFFF6F7F9);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightBorder = Color(0xFFE5E7EB);
  static const Color _lightText = Color(0xFF111827);

  // Dark palette (GitHub-dark inspired, higher contrast than before)
  static const Color _darkScaffold = Color(0xFF0D1117);
  static const Color _darkSurface = Color(0xFF161B22);
  static const Color _darkBorder = Color(0xFF2D333B);
  static const Color _darkText = Color(0xFFE6EDF3);

  static ThemeData get light => _build(
        brightness: Brightness.light,
        accent: _accentLight,
        scaffold: _lightScaffold,
        surface: _lightSurface,
        border: _lightBorder,
        text: _lightText,
        colors: AppColors.light,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        accent: _accentDark,
        scaffold: _darkScaffold,
        surface: _darkSurface,
        border: _darkBorder,
        text: _darkText,
        colors: AppColors.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color accent,
    required Color scaffold,
    required Color surface,
    required Color border,
    required Color text,
    required AppColors colors,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      surface: surface,
      onSurface: text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      dividerColor: border,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: TextStyle(color: colors.muted),
        labelStyle: TextStyle(color: colors.muted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(fontSize: 16, color: text),
        bodyMedium: TextStyle(fontSize: 14, color: text),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        labelMedium: TextStyle(fontSize: 13, color: colors.muted),
      ),
    );
  }
}
