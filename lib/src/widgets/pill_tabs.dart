import 'package:flutter/material.dart';

import '../core/design_tokens.dart';

class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.tabs,
    required this.current,
    required this.onChanged,
  });

  final List<String> tabs;
  final int current;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseContainer = theme.colorScheme.surfaceContainerHighest;
    final highlightGradient = LinearGradient(
      colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
    );
    return ClipRRect(
      borderRadius: AppRadii.pillRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: baseContainer.withValues(alpha: isDark ? 0.42 : 0.65),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.35 : 0.22,
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (tabs.isEmpty) return const SizedBox.shrink();
            final itemWidth = constraints.maxWidth / tabs.length;
            final highlightLeft = current * itemWidth;

            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                AnimatedPositioned(
                  duration: AppDurations.medium,
                  curve: Curves.easeInOutCubic,
                  left: highlightLeft,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.pillRadius,
                      gradient: highlightGradient,
                    ),
                  ),
                ),
                Row(
                  children: List.generate(tabs.length, (index) {
                    final selected = index == current;
                    final background = selected
                        ? Colors.transparent
                        : theme.colorScheme.surface.withValues(
                            alpha: isDark ? 0.12 : 0.06,
                          );
                    final textColor = selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.82,
                          );
                    return Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: AppRadii.pillRadius,
                          onTap: () => onChanged(index),
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          child: AnimatedContainer(
                            duration: AppDurations.medium,
                            curve: Curves.easeInOutCubic,
                            decoration: BoxDecoration(
                              color: background,
                              borderRadius: AppRadii.pillRadius,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                              horizontal: AppSpacing.lg,
                            ),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: AppDurations.short,
                                curve: Curves.easeInOutCubic,
                                style: theme.textTheme.labelLarge?.copyWith(
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                    ) ??
                                    TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                child: Text(tabs[index]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
