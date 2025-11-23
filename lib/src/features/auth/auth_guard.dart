import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../localization/localization_ext.dart';
import '../../state/app_state.dart';
import 'auth_flow.dart';

Future<bool> ensureLoggedIn(
  BuildContext context, {
  bool showMessage = true,
}) async {
  final state = context.read<AppState>();
  if (state.isAuthenticated) return true;

  if (showMessage) {
    final strings = context.strings;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.tr('loginRequired'))));
  }

  final result = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => const AuthFlow()));
  return result == true || state.isAuthenticated;
}
