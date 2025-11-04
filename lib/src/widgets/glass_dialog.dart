import 'package:flutter/material.dart';

import '../core/design_tokens.dart';

/// Presents content inside a centered glassmorphic dialog with scale + fade
/// transitions. The [builder] should return the dialog body, typically a
/// [GlassCard] widget.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? barrierLabel,
  bool barrierDismissible = true,
}) {
  final localization = MaterialLocalizations.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel ?? localization.modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    transitionDuration: AppDurations.long,
    pageBuilder: (dialogContext, _, __) {
      final media = MediaQuery.of(dialogContext);
      final content = builder(dialogContext);
      return Align(
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md + media.padding.left,
            AppSpacing.lg + media.padding.top,
            AppSpacing.md + media.padding.right,
            AppSpacing.lg + media.padding.bottom + media.viewInsets.bottom,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(child: content),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
