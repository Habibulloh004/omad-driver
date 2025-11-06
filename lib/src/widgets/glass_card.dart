import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/design_tokens.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseSurface = theme.colorScheme.surface;
    final overlay = theme.colorScheme.primary.withValues(
      alpha: isDark ? 0.16 : 0.08,
    );
    final background = Color.alphaBlend(
      overlay,
      baseSurface.withValues(alpha: isDark ? 0.74 : 0.88),
    );
    final shadows = AppShadows.soft(
      baseColor: theme.colorScheme.primary,
      isDark: isDark,
    );

    return Padding(
      padding: margin,
      child: AnimatedContainer(
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: AppRadii.cardRadius,
          boxShadow: shadows,
        ),
        child: ClipRRect(
          borderRadius: AppRadii.cardRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: isDark ? 0.42 : 0.16,
                  ),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          baseSurface.withValues(alpha: 0.82),
                          baseSurface.withValues(alpha: 0.68),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.92),
                          Colors.white.withValues(alpha: 0.76),
                        ],
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: AppRadii.cardRadius,
                  splashColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  highlightColor: Colors.transparent,
                  child: Padding(padding: padding, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
