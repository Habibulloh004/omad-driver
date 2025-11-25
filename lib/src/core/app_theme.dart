import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';

const _lightScaffold = Color(0xFFF6F7FC);
const _lightSurface = Color(0xFFFFFFFF);
const _lightSurfaceLow = Color(0xFFF1F3FB);
const _lightSurfaceHigh = Color(0xFFE9ECF7);

const _darkScaffold = Color(0xFF0E1524);
const _darkSurface = Color(0xFF131C30);
const _darkSurfaceLow = Color(0xFF172135);
const _darkSurfaceHigh = Color(0xFF1D2942);

const _primarySeed = Color(0xFF675BFF);
const _secondarySeed = Color(0xFF8B82FF);
const _tertiarySeed = Color(0xFFB7AEFF);
const _lightOutline = Color(0xFFD9DEF2);
const _lightOutlineVariant = Color(0xFFE7EBFA);
const _darkOutline = Color(0xFF273349);
const _darkOutlineVariant = Color(0xFF303D56);
const _fontFamily = 'Urbanist';
const _fontFamilyFallback = ['NotoSans'];

TextTheme _buildTextTheme({
  required TextTheme base,
  required Color onSurface,
  required Color subdued,
}) {
  return base
      .apply(bodyColor: onSurface, displayColor: onSurface)
      .copyWith(
        headlineMedium: base.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        titleSmall: base.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: subdued,
          letterSpacing: 0.2,
        ),
        bodyLarge: base.bodyLarge?.copyWith(height: 1.4, color: onSurface),
        bodyMedium: base.bodyMedium?.copyWith(height: 1.5, color: subdued),
        bodySmall: base.bodySmall?.copyWith(height: 1.45, color: subdued),
        labelLarge: base.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelMedium: base.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelSmall: base.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: subdued,
        ),
      );
}

ThemeData buildLightTheme(TextTheme baseTextTheme) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: _primarySeed,
    brightness: Brightness.light,
  );

  final colorScheme = baseScheme.copyWith(
    surface: _lightSurface,
    surfaceContainerLowest: _lightSurface,
    surfaceContainerLow: _lightSurfaceLow,
    surfaceContainer: _lightSurfaceHigh,
    surfaceContainerHigh: _lightSurfaceHigh,
    surfaceContainerHighest: _lightSurfaceHigh,
    onSurface: const Color(0xFF111827),
    onSurfaceVariant: const Color(0xFF5D6583),
    outline: _lightOutline,
    outlineVariant: _lightOutlineVariant,
    primary: _primarySeed,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFE6E4FF),
    onPrimaryContainer: const Color(0xFF1D1866),
    secondary: _secondarySeed,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFE2E0FF),
    onSecondaryContainer: const Color(0xFF221D5E),
    tertiary: _tertiarySeed,
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFF1EEFF),
    onTertiaryContainer: const Color(0xFF231952),
    surfaceTint: _primarySeed,
    error: const Color(0xFFDC2626),
    onError: Colors.white,
  );

  return _buildTheme(
    baseTextTheme: baseTextTheme,
    colorScheme: colorScheme,
    scaffoldBackground: _lightScaffold,
    outlineVariant: _lightOutlineVariant,
    isDark: false,
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
    surfaceContainerLow: _darkSurfaceLow,
    surfaceContainer: _darkSurfaceLow,
    surfaceContainerHigh: _darkSurfaceHigh,
    surfaceContainerHighest: _darkSurfaceHigh,
    onSurface: const Color(0xFFE5EBFF),
    onSurfaceVariant: const Color(0xFFA6B3D8),
    outline: _darkOutline,
    outlineVariant: _darkOutlineVariant,
    primary: const Color(0xFF9188FF),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF2C3453),
    onPrimaryContainer: const Color(0xFFE2E5FF),
    secondary: const Color(0xFF847CFF),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFF343C5F),
    onSecondaryContainer: const Color(0xFFDFE2FF),
    tertiary: const Color(0xFFB8B1FF),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFF3A4366),
    onTertiaryContainer: const Color(0xFFEAE9FF),
    surfaceTint: const Color(0xFF9188FF),
    error: const Color(0xFFFF6B6B),
    onError: const Color(0xFF160404),
  );

  return _buildTheme(
    baseTextTheme: baseTextTheme,
    colorScheme: colorScheme,
    scaffoldBackground: _darkScaffold,
    outlineVariant: _darkOutlineVariant,
    isDark: true,
  );
}

ThemeData _buildTheme({
  required TextTheme baseTextTheme,
  required ColorScheme colorScheme,
  required Color scaffoldBackground,
  required bool isDark,
  required Color outlineVariant,
}) {
  final textTheme = _buildTextTheme(
    base: baseTextTheme,
    onSurface: colorScheme.onSurface,
    subdued: colorScheme.onSurfaceVariant,
  );

  final buttonTextStyle = (textTheme.labelLarge ??
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))
      .copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  const buttonPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.xl,
    vertical: AppSpacing.md,
  );
  const buttonMinSize = Size(88, 48);
  const buttonShape = RoundedRectangleBorder(
    borderRadius: AppRadii.buttonRadius,
  );

  final disabledForeground = colorScheme.onSurface.withValues(alpha: 0.38);
  final disabledOutline =
      outlineVariant.withValues(alpha: isDark ? 0.35 : 0.5);

  final filledButtonStyle = ButtonStyle(
    minimumSize: WidgetStateProperty.all(buttonMinSize),
    padding: WidgetStateProperty.all(buttonPadding),
    shape: WidgetStateProperty.all(buttonShape),
    textStyle: WidgetStateProperty.all(buttonTextStyle),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return disabledForeground;
      return colorScheme.onPrimary;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return colorScheme.primary.withValues(alpha: 0.28);
      }
      return colorScheme.primary;
    }),
    elevation: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return 0;
      if (states.contains(WidgetState.pressed)) {
        return isDark ? 0.0 : 1.0;
      }
      return isDark ? 0.0 : 3.0;
    }),
    shadowColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.transparent;
      }
      return colorScheme.primary.withValues(alpha: isDark ? 0.24 : 0.2);
    }),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return colorScheme.onPrimary.withValues(alpha: 0.2);
      }
      if (states.contains(WidgetState.hovered)) {
        return colorScheme.onPrimary.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.focused)) {
        return colorScheme.onPrimary.withValues(alpha: 0.16);
      }
      return null;
    }),
    alignment: Alignment.center,
    animationDuration: AppDurations.short,
    tapTargetSize: MaterialTapTargetSize.padded,
  );

  final elevatedButtonStyle = filledButtonStyle.copyWith(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return colorScheme.secondary.withValues(alpha: 0.28);
      }
      return colorScheme.secondary;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return disabledForeground;
      return colorScheme.onSecondary;
    }),
    shadowColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.transparent;
      }
      return colorScheme.secondary.withValues(alpha: isDark ? 0.24 : 0.2);
    }),
  );

  final outlinedButtonStyle = ButtonStyle(
    minimumSize: WidgetStateProperty.all(buttonMinSize),
    padding: WidgetStateProperty.all(buttonPadding),
    shape: WidgetStateProperty.all(buttonShape),
    textStyle: WidgetStateProperty.all(buttonTextStyle),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return disabledForeground;
      return colorScheme.primary;
    }),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return colorScheme.primary.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.hovered)) {
        return colorScheme.primary.withValues(alpha: 0.08);
      }
      return null;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(color: disabledOutline);
      }
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: colorScheme.primary, width: 1.5);
      }
      return BorderSide(color: outlineVariant);
    }),
    animationDuration: AppDurations.short,
    alignment: Alignment.center,
    tapTargetSize: MaterialTapTargetSize.padded,
  );

  final textButtonStyle = ButtonStyle(
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    ),
    textStyle: WidgetStateProperty.all(
      buttonTextStyle.copyWith(letterSpacing: 0.1),
    ),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return disabledForeground;
      return colorScheme.primary;
    }),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return colorScheme.primary.withValues(alpha: 0.14);
      }
      return colorScheme.primary.withValues(alpha: 0.08);
    }),
    alignment: Alignment.center,
    tapTargetSize: MaterialTapTargetSize.padded,
  );

  final iconButtonStyle = ButtonStyle(
    padding: WidgetStateProperty.all(
      const EdgeInsets.all(AppSpacing.sm),
    ),
    minimumSize: WidgetStateProperty.all(const Size(40, 40)),
    shape: WidgetStateProperty.all(
      const RoundedRectangleBorder(borderRadius: AppRadii.rounded),
    ),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return disabledForeground;
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.selected)) {
        return colorScheme.onPrimary;
      }
      return colorScheme.onSurface;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.selected)) {
        return colorScheme.primary.withValues(alpha: isDark ? 0.32 : 0.16);
      }
      if (states.contains(WidgetState.hovered)) {
        return colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1);
      }
      return Colors.transparent;
    }),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return colorScheme.primary.withValues(alpha: 0.18);
      }
      if (states.contains(WidgetState.hovered)) {
        return colorScheme.primary.withValues(alpha: 0.12);
      }
      return null;
    }),
    iconSize: WidgetStateProperty.all(22),
  );

  final chipLabelStyle = (textTheme.labelMedium ??
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))
      .copyWith(fontWeight: FontWeight.w600);
  final chipSelectedStyle =
      chipLabelStyle.copyWith(color: colorScheme.onPrimary);
  final chipTheme = ChipThemeData(
    backgroundColor: colorScheme.surfaceContainerLow,
    selectedColor: colorScheme.primary.withValues(alpha: isDark ? 0.32 : 0.22),
    secondarySelectedColor: colorScheme.primary,
    disabledColor: colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    labelStyle: chipLabelStyle,
    secondaryLabelStyle: chipSelectedStyle,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
    side: BorderSide(color: outlineVariant.withValues(alpha: 0.6)),
    brightness: isDark ? Brightness.dark : Brightness.light,
    showCheckmark: false,
  );

  final trackBase = colorScheme.surfaceContainerLow.withValues(
    alpha: isDark ? 0.5 : 0.7,
  );
  final switchTheme = SwitchThemeData(
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return trackBase.withValues(alpha: 0.3);
      }
      if (states.contains(WidgetState.selected)) {
        return colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.45);
      }
      return trackBase;
    }),
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return outlineVariant.withValues(alpha: 0.7);
      }
      if (states.contains(WidgetState.selected)) {
        return colorScheme.primary;
      }
      return outlineVariant;
    }),
    trackOutlineColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return Colors.transparent;
      }
      return outlineVariant.withValues(alpha: 0.6);
    }),
  );

  final OutlineInputBorder baseBorder = OutlineInputBorder(
    borderRadius: AppRadii.cardRadius,
    borderSide: BorderSide(
      color: outlineVariant.withValues(alpha: isDark ? 0.35 : 0.55),
    ),
  );
  final focusedBorder = baseBorder.copyWith(
    borderSide: BorderSide(
      color: colorScheme.primary.withValues(alpha: isDark ? 0.6 : 0.7),
      width: 1.4,
    ),
  );
  final errorBorder = baseBorder.copyWith(
    borderSide: BorderSide(
      color: colorScheme.error.withValues(alpha: 0.85),
    ),
  );

  return ThemeData(
    colorScheme: colorScheme,
    brightness: colorScheme.brightness,
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    textTheme: textTheme,
    scaffoldBackgroundColor: scaffoldBackground,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge,
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.9)
          : colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      border: baseBorder,
      enabledBorder: baseBorder,
      disabledBorder: baseBorder.copyWith(
        borderSide: BorderSide(
          color: outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: focusedBorder,
      errorBorder: errorBorder,
      focusedErrorBorder: baseBorder.copyWith(
        borderSide: BorderSide(
          color: colorScheme.error,
          width: 1.4,
        ),
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      labelStyle: textTheme.bodyMedium,
      floatingLabelStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: colorScheme.primary,
      suffixIconColor: colorScheme.onSurfaceVariant,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: colorScheme.surface.withValues(alpha: 0.98),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.card),
        ),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
      extendedPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: textButtonStyle),
    filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle),
    elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButtonStyle),
    iconButtonTheme: IconButtonThemeData(style: iconButtonStyle),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.surface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      actionTextColor: colorScheme.primary,
      closeIconColor: colorScheme.onSurfaceVariant,
    ),
    dividerTheme: DividerThemeData(
      color: outlineVariant.withValues(alpha: isDark ? 0.3 : 0.6),
      thickness: 1,
      space: AppSpacing.sm,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      dense: false,
      horizontalTitleGap: AppSpacing.md,
      tileColor: Colors.transparent,
    ),
    chipTheme: chipTheme,
    switchTheme: switchTheme,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor:
          colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.18),
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colorScheme.onSurfaceVariant;
        return IconThemeData(color: color);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final baseStyle = textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        );
        if (baseStyle == null) return null;
        if (states.contains(WidgetState.selected)) {
          return baseStyle.copyWith(color: colorScheme.onPrimary);
        }
        return baseStyle.copyWith(color: colorScheme.onSurfaceVariant);
      }),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      selectedIconTheme: IconThemeData(color: colorScheme.primary),
      unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      selectedLabelStyle: textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: textTheme.labelMedium,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      circularTrackColor: colorScheme.primary.withValues(alpha: 0.12),
      linearTrackColor: outlineVariant.withValues(alpha: 0.4),
    ),
    iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
    primaryIconTheme: IconThemeData(color: colorScheme.onPrimary),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.92),
        borderRadius: AppRadii.cardRadius,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      textStyle: textTheme.labelSmall?.copyWith(
        color: colorScheme.surface,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      elevation: 4,
      textStyle: textTheme.bodyMedium,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colorScheme.primary,
      selectionColor: colorScheme.primary.withValues(alpha: 0.25),
      selectionHandleColor: colorScheme.primary,
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: const FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.android: const FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
