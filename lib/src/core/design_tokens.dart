import 'package:flutter/material.dart';

/// Central place for design system constants to keep spacing, radii and motion uniform.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets page = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );
}

class AppRadii {
  const AppRadii._();

  static const double card = 16;
  static const double button = 12;
  static const double pill = 28;

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );

  static const BorderRadius rounded = cardRadius;
}

class AppDurations {
  const AppDurations._();

  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration long = Duration(milliseconds: 420);
}

class AppShadows {
  const AppShadows._();

  static List<BoxShadow> soft({
    required Color baseColor,
    required bool isDark,
  }) {
    final primary = baseColor.withValues(alpha: isDark ? 0.12 : 0.08);
    final ambient = Colors.black.withValues(alpha: isDark ? 0.12 : 0.05);
    return [
      BoxShadow(
        color: ambient,
        blurRadius: 12,
        offset: const Offset(0, 8),
        spreadRadius: 0.5,
      ),
      BoxShadow(
        color: primary,
        blurRadius: 16,
        offset: const Offset(0, 4),
        spreadRadius: 0.5,
      ),
    ];
  }
}
