import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../localization/app_localizations.dart';
import '../../localization/localization_ext.dart';
import '../../state/app_state.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/glass_card.dart';

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> with TickerProviderStateMixin {
  final TextEditingController loginPhoneCtrl = TextEditingController(
    text: '+998',
  );
  final TextEditingController loginPasswordCtrl = TextEditingController();

  final TextEditingController registerPhoneCtrl = TextEditingController(
    text: '+998',
  );
  final TextEditingController registerNameCtrl = TextEditingController();
  final TextEditingController registerPasswordCtrl = TextEditingController();
  final TextEditingController registerConfirmCtrl = TextEditingController();

  bool showLogin = true;
  bool loginPasswordVisible = false;
  bool registerPasswordVisible = false;
  bool registerConfirmVisible = false;
  bool loading = false;

  late final AnimationController _logoController;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    loginPhoneCtrl.dispose();
    loginPasswordCtrl.dispose();
    registerPhoneCtrl.dispose();
    registerNameCtrl.dispose();
    registerPasswordCtrl.dispose();
    registerConfirmCtrl.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => loading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    context.read<AppState>().login(
      phone: loginPhoneCtrl.text,
      password: loginPasswordCtrl.text,
    );
    setState(() => loading = false);
  }

  Future<void> _handleRegister() async {
    if (registerPasswordCtrl.text != registerConfirmCtrl.text) {
      _showSnack(context.strings.tr('passwordMismatch'));
      return;
    }

    setState(() => loading = true);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    context.read<AppState>().register(
      phone: registerPhoneCtrl.text,
      fullName: registerNameCtrl.text,
      password: registerPasswordCtrl.text,
    );
    setState(() => loading = false);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _toggleForm() {
    setState(() => showLogin = !showLogin);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final media = MediaQuery.of(context);

    return Scaffold(
      body: Stack(
        children: [
          _GradientBackground(controller: _logoController),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: media.size.width < 480
                    ? 24
                    : media.size.width * 0.2,
                vertical: 48,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: Tween(begin: 0.95, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _logoController,
                        curve: const Interval(0, 0.3, curve: Curves.easeInOut),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        Hero(
                          tag: 'app-logo',
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.22),
                                  blurRadius: 30,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.local_taxi_rounded,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          strings.tr('authTitle'),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.tr('authSubtitle'),
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(showLogin ? 0.1 : -0.1, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: GlassCard(
                      key: ValueKey(showLogin),
                      margin: EdgeInsets.zero,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            showLogin
                                ? strings.tr('loginTitle')
                                : strings.tr('registerTitle'),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 20),
                          if (showLogin) ...[
                            AppTextField(
                              controller: loginPhoneCtrl,
                              label: strings.tr('phoneNumber'),
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_rounded,
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: loginPasswordCtrl,
                              label: strings.tr('password'),
                              obscureText: !loginPasswordVisible,
                              prefixIcon: Icons.lock_rounded,
                              suffix: IconButton(
                                icon: Icon(
                                  loginPasswordVisible
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                                onPressed: () => setState(
                                  () => loginPasswordVisible =
                                      !loginPasswordVisible,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _showSnack(
                                  strings.tr('passwordRecoveryMock'),
                                ),
                                child: Text(strings.tr('forgotPassword')),
                              ),
                            ),
                            const SizedBox(height: 12),
                            GradientButton(
                              onPressed: loading ? null : _handleLogin,
                              label: strings.tr('continue'),
                              icon: Icons.arrow_forward_rounded,
                              loading: loading,
                            ),
                          ] else ...[
                            AppTextField(
                              controller: registerNameCtrl,
                              label: strings.tr('fullName'),
                              keyboardType: TextInputType.name,
                              prefixIcon: Icons.person_rounded,
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: registerPhoneCtrl,
                              label: strings.tr('phoneNumber'),
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_rounded,
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: registerPasswordCtrl,
                              label: strings.tr('password'),
                              obscureText: !registerPasswordVisible,
                              prefixIcon: Icons.lock_rounded,
                              suffix: IconButton(
                                icon: Icon(
                                  registerPasswordVisible
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                                onPressed: () => setState(
                                  () => registerPasswordVisible =
                                      !registerPasswordVisible,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: registerConfirmCtrl,
                              label: strings.tr('confirmPassword'),
                              obscureText: !registerConfirmVisible,
                              prefixIcon: Icons.lock_outline_rounded,
                              suffix: IconButton(
                                icon: Icon(
                                  registerConfirmVisible
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                                onPressed: () => setState(
                                  () => registerConfirmVisible =
                                      !registerConfirmVisible,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            GradientButton(
                              onPressed: loading ? null : _handleRegister,
                              label: strings.tr('createAccount'),
                              icon: Icons.check_circle_rounded,
                              loading: loading,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: loading ? null : _toggleForm,
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                        children: [
                          TextSpan(
                            text: showLogin
                                ? strings.tr('needAccount')
                                : strings.tr('haveAccount'),
                          ),
                          TextSpan(
                            text: showLogin
                                ? strings.tr('registerNow')
                                : strings.tr('loginInstead'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _LanguageSelector(),
    );
  }
}

class _GradientBackground extends StatelessWidget {
  const _GradientBackground({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final animationValue = controller.value;
        final rotation = animationValue * 2 * 3.1415;
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0F172A),
                    Theme.of(context).colorScheme.primary,
                    const Color(0xFF111B2E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -120,
              right: -120,
              child: Transform.rotate(
                angle: rotation,
                child: _BlurCircle(
                  size: 280,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -40,
              child: Transform.rotate(
                angle: -rotation,
                child: _BlurCircle(
                  size: 240,
                  colors: [
                    Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: AppLocale.values.map((locale) {
            final selected = state.locale == locale.locale;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: selected ? 0.4 : 0.18,
                    ),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => context.read<AppState>().switchLocale(locale),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      locale.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
