import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/auth_flow.dart';
import '../features/main_shell/main_shell.dart';
import '../state/app_state.dart';

class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (!state.isAuthenticated) {
          return const AuthFlow();
        }
        return const MainShell();
      },
    );
  }
}
