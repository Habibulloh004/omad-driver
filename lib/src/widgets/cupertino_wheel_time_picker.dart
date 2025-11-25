import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/design_tokens.dart';

/// Shows an iOS-style wheel time picker that matches the iPhone alarm UI.
Future<TimeOfDay?> showCupertinoWheelTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  final now = DateTime.now();
  final materialLocalizations = MaterialLocalizations.of(context);
  final mediaQuery = MediaQuery.of(context);
  TimeOfDay currentSelection = initialTime;

  return showCupertinoModalPopup<TimeOfDay>(
    context: context,
    barrierDismissible: true,
    builder: (popupContext) {
      final theme = Theme.of(popupContext);
      final isDark = theme.brightness == Brightness.dark;

      final cupertinoTheme = CupertinoThemeData(
        brightness: theme.brightness,
        primaryColor: theme.colorScheme.primary,
        barBackgroundColor: isDark
            ? const Color(0xFF1C1C1E)
            : theme.colorScheme.surfaceContainer,
        textTheme: CupertinoTextThemeData(
          dateTimePickerTextStyle: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          pickerTextStyle: TextStyle(
            fontSize: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      );

      final surfaceColor = isDark
          ? const Color(0xFF1C1C1E)
          : theme.colorScheme.surfaceContainerHigh;

      return CupertinoTheme(
        data: cupertinoTheme,
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.card),
              ),
              boxShadow: AppShadows.soft(
                baseColor: theme.colorScheme.primary,
                isDark: isDark,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(popupContext).pop(),
                        child: Text(materialLocalizations.cancelButtonLabel),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () =>
                            Navigator.of(popupContext).pop(currentSelection),
                        child: Text(materialLocalizations.okButtonLabel),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 240,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    backgroundColor: Colors.transparent,
                    use24hFormat: mediaQuery.alwaysUse24HourFormat,
                    initialDateTime: DateTime(
                      now.year,
                      now.month,
                      now.day,
                      initialTime.hour,
                      initialTime.minute,
                    ),
                    onDateTimeChanged: (dateTime) {
                      currentSelection = TimeOfDay(
                        hour: dateTime.hour,
                        minute: dateTime.minute,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
