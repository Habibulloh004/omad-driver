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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: baseContainer.withValues(alpha: isDark ? 0.42 : 0.65),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.35 : 0.22,
          ),
        ),
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = index == current;
          return Expanded(
            child: AnimatedContainer(
              duration: AppDurations.medium,
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      )
                    : null,
                color: selected
                    ? null
                    : theme.colorScheme.surface.withValues(
                        alpha: isDark ? 0.12 : 0.06,
                      ),
                borderRadius: AppRadii.pillRadius,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: AppRadii.pillRadius,
                  onTap: () => onChanged(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Center(
                      child: Text(
                        tabs[index],
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: selected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.85,
                                ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
