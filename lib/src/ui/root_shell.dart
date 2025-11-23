// lib/src/ui/root_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/main_shell/main_shell.dart';
import '../core/design_tokens.dart';
import '../state/app_state.dart';

class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.isBootstrapping) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const AnimatedSwitcher(
          duration: AppDurations.medium,
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          child: MainShell(key: ValueKey('main-shell')),
        );
      },
    );
  }
}
