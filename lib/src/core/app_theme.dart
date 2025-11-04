import 'package:flutter/material.dart';

import 'design_tokens.dart';

const _lightScaffold = Color(0xFFF5F7FB);
const _lightSurface = Color(0xFFFFFFFF);
const _lightSurfaceHigh = Color(0xFFF0F2FA);

const _darkScaffold = Color(0xFF0F1626);
const _darkSurface = Color(0xFF131B2D);
const _darkSurfaceHigh = Color(0xFF172238);

const _primarySeed = Color(0xFF6D63FF);
const _secondarySeed = Color(0xFFA29BFE);
const _tertiarySeed = Color(0xFF64A6FF);
const _lightOutline = Color(0xFFD6DDF1);
const _lightOutlineVariant = Color(0xFFE4E9F8);
const _darkOutline = Color(0xFF263246);
const _darkOutlineVariant = Color(0xFF2F3C54);

TextTheme _buildTextTheme({
  required TextTheme base,
  required Color onSurface,
  required Color subdued,
}) {
  return base
      .apply(bodyColor: onSurface, displayColor: onSurface)
      .copyWith(
        headlineSmall: base.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: base.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: subdued,
        ),
        bodyLarge: base.bodyLarge?.copyWith(height: 1.4, color: onSurface),
        bodyMedium: base.bodyMedium?.copyWith(height: 1.45, color: subdued),
        labelLarge: base.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      );
}

ThemeData buildLightTheme(TextTheme baseTextTheme) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: _primarySeed,
    brightness: Brightness.light,
  );

  final colorScheme = baseScheme.copyWith(
    surface: _lightSurface,
    surfaceContainerLowest: _lightSurfaceHigh,
    surfaceContainerLow: _lightSurfaceHigh,
    surfaceContainer: _lightSurfaceHigh,
    surfaceContainerHigh: _lightSurfaceHigh,
    surfaceContainerHighest: _lightSurfaceHigh,
    onSurface: const Color(0xFF111827),
    onSurfaceVariant: const Color(0xFF5D6582),
    outline: _lightOutline,
    outlineVariant: _lightOutlineVariant,
    primary: _primarySeed,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFE6E4FF),
    onPrimaryContainer: const Color(0xFF1D1866),
    secondary: _secondarySeed,
    onSecondary: Colors.white,
    tertiary: _tertiarySeed,
    onTertiary: Colors.white,
  );

  final textTheme = _buildTextTheme(
    base: baseTextTheme,
    onSurface: colorScheme.onSurface,
    subdued: colorScheme.onSurfaceVariant,
  );

  return ThemeData(
    colorScheme: colorScheme,
    brightness: Brightness.light,
    textTheme: textTheme,
    scaffoldBackgroundColor: _lightScaffold,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadii.cardRadius,
        borderSide: BorderSide.none,
      ),
      hintStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        textStyle: textTheme.labelLarge,
        foregroundColor: colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.surface,
      contentTextStyle: textTheme.bodyLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: AppSpacing.sm,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

ThemeData buildDarkTheme(TextTheme baseTextTheme) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: _primarySeed,
    brightness: Brightness.dark,
  );

  final colorScheme = baseScheme.copyWith(
    surface: _darkSurface,
    surfaceContainerLowest: _darkSurface,
    surfaceContainerLow: _darkSurface,
    surfaceContainer: _darkSurface,
    surfaceContainerHigh: _darkSurfaceHigh,
    surfaceContainerHighest: _darkSurfaceHigh,
    onSurface: const Color(0xFFE5EBFF),
    onSurfaceVariant: const Color(0xFFA3B1D5),
    outline: _darkOutline,
    outlineVariant: _darkOutlineVariant,
    primary: const Color(0xFF847BFF),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF252F4A),
    onPrimaryContainer: const Color(0xFFDEE1FF),
    secondary: const Color(0xFF7F88FF),
    onSecondary: Colors.white,
    tertiary: const Color(0xFF5FA8FF),
    onTertiary: Colors.white,
  );

  final textTheme = _buildTextTheme(
    base: baseTextTheme,
    onSurface: colorScheme.onSurface,
    subdued: colorScheme.onSurfaceVariant,
  );

  return ThemeData(
    colorScheme: colorScheme,
    brightness: Brightness.dark,
    textTheme: textTheme,
    scaffoldBackgroundColor: _darkScaffold,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: _darkSurface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurfaceHigh,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadii.cardRadius,
        borderSide: BorderSide.none,
      ),
      hintStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        textStyle: textTheme.labelLarge,
        foregroundColor: colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _darkSurfaceHigh,
      contentTextStyle: textTheme.bodyLarge,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: AppSpacing.sm,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
