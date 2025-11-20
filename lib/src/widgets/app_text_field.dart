import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.hintText,
    this.showLabel = true,
    this.floatingLabelBehavior,
  });

  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final VoidCallback? onTap;
  final bool readOnly;
  final int? minLines;
  final int maxLines;
  final IconData? prefixIcon;
  final String? hintText;
  final bool showLabel;
  final FloatingLabelBehavior? floatingLabelBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMultiline = (minLines ?? maxLines) > 1 || maxLines > 1;
    final hasLabel = showLabel && label.isNotEmpty;
    final resolvedHint = hintText ?? (hasLabel ? null : label);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onTap: onTap,
      readOnly: readOnly,
      minLines: minLines,
      maxLines: maxLines,
      textAlignVertical:
          isMultiline ? TextAlignVertical.top : TextAlignVertical.center,
      decoration: InputDecoration(
        labelText: hasLabel ? label : null,
        hintText: resolvedHint,
        floatingLabelBehavior: floatingLabelBehavior ??
            (hasLabel ? FloatingLabelBehavior.auto : FloatingLabelBehavior.never),
        alignLabelWithHint: isMultiline,
        contentPadding: isMultiline
            ? const EdgeInsets.fromLTRB(16, 18, 16, 18)
            : const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: theme.colorScheme.primary)
            : null,
        suffixIcon: suffix,
      ),
    );
  }
}
