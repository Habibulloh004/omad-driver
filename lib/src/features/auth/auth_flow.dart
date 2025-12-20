// lib/src/features/auth/auth_flow.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/auth_api.dart';
import '../../core/design_tokens.dart';
import '../../localization/app_localizations.dart';
import '../../localization/localization_ext.dart';
import '../../state/app_state.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/pill_tabs.dart';

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> with TickerProviderStateMixin {
  // --- Controllers & State ---
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

  int _currentFormIndex = 0;
  bool loginPasswordVisible = false;
  bool registerPasswordVisible = false;
  bool registerConfirmVisible = false;
  bool loading = false;
  final FocusNode loginPhoneFocus = FocusNode();
  final FocusNode loginPasswordFocus = FocusNode();
  final FocusNode registerPhoneFocus = FocusNode();
  final FocusNode registerNameFocus = FocusNode();
  final FocusNode registerPasswordFocus = FocusNode();
  final FocusNode registerConfirmFocus = FocusNode();

  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  int _slideDirection = 1;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    loginPhoneCtrl.dispose();
    loginPasswordCtrl.dispose();
    registerPhoneCtrl.dispose();
    registerNameCtrl.dispose();
    registerPasswordCtrl.dispose();
    registerConfirmCtrl.dispose();
    loginPhoneFocus.dispose();
    loginPasswordFocus.dispose();
    registerPhoneFocus.dispose();
    registerNameFocus.dispose();
    registerPasswordFocus.dispose();
    registerConfirmFocus.dispose();
    _logoController.dispose();
    super.dispose();
  }

  // --- Actions ---
  Future<void> _handleLogin() async {
    final strings = context.strings;
    final phone = loginPhoneCtrl.text.trim();
    final password = loginPasswordCtrl.text;
    if (phone.isEmpty || password.isEmpty) {
      _showSnack(strings.tr('fillAllFields'));
      return;
    }
    _unfocusAll();
    FocusScope.of(context).unfocus();
    setState(() => loading = true);
    try {
      await context.read<AppState>().login(phone: phone, password: password);
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnack(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack(context.strings.tr('unexpectedError'));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _handleRegister() async {
    final strings = context.strings;
    final phone = registerPhoneCtrl.text.trim();
    final fullName = registerNameCtrl.text.trim();
    final password = registerPasswordCtrl.text;
    final confirm = registerConfirmCtrl.text;

    if (phone.isEmpty ||
        fullName.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty) {
      _showSnack(strings.tr('fillAllFields'));
      return;
    }

    if (password != confirm) {
      _showSnack(strings.tr('passwordMismatch'));
      return;
    }

    _unfocusAll();
    FocusScope.of(context).unfocus();
    setState(() => loading = true);
    try {
      await context.read<AppState>().register(
        fullName: fullName,
        phone: phone,
        password: password,
        confirmPassword: confirm,
      );
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnack(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack(context.strings.tr('unexpectedError'));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  bool get _isLogin => _currentFormIndex == 0;

  void _switchForm(int index) {
    if (_currentFormIndex == index) return;
    _unfocusAll();
    FocusScope.of(context).unfocus();
    setState(() {
      _slideDirection = index > _currentFormIndex ? 1 : -1;
      _currentFormIndex = index;
    });
  }

  void _toggleForm() => _switchForm(_isLogin ? 1 : 0);

  void _unfocusAll() {
    for (final node in [
      loginPhoneFocus,
      loginPasswordFocus,
      registerPhoneFocus,
      registerNameFocus,
      registerPasswordFocus,
      registerConfirmFocus,
    ]) {
      node.unfocus();
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = context.strings;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth.clamp(360.0, 720.0);
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final contentPadding = EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl + bottomInset, // keep form above the on-screen keyboard
            );
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: contentPadding,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Header / Logo ----
                      ScaleTransition(
                        scale: _logoScale,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.secondary,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.16,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Icon(
                              Icons.local_taxi_rounded,
                              color: theme.colorScheme.onPrimary,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        strings.tr('authTitle'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        strings.tr('authSubtitle'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ---- Card with Forms ----
                      _FrostCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Toggle
                            PillTabs(
                              tabs: [
                                strings.tr('loginTitle'),
                                strings.tr('registerTitle'),
                              ],
                              current: _currentFormIndex,
                              onChanged: (index) {
                                if (!loading) _switchForm(index);
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            AnimatedSize(
                              duration: AppDurations.medium,
                              curve: Curves.easeInOutCubic,
                              alignment: Alignment.topCenter,
                              clipBehavior: Clip.none,
                              child: AnimatedSwitcher(
                                duration: AppDurations.medium,
                                layoutBuilder: (currentChild, previous) {
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.topCenter,
                                    children: [
                                      ...previous,
                                      if (currentChild != null) currentChild,
                                    ],
                                  );
                                },
                                transitionBuilder: (child, animation) {
                                  final curved = CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeInOutCubic,
                                  );
                                  final isEntering =
                                      animation.status !=
                                      AnimationStatus.reverse;
                                  final offsetTween = Tween<Offset>(
                                    begin: isEntering
                                        ? Offset(0.18 * _slideDirection, 0)
                                        : Offset.zero,
                                    end: isEntering
                                        ? Offset.zero
                                        : Offset(
                                            -0.18 * _slideDirection,
                                            0,
                                          ),
                                  );
                                  final slideAnimation = curved.drive(
                                    offsetTween,
                                  );
                                  return FadeTransition(
                                    opacity: curved,
                                    child: SlideTransition(
                                      position: slideAnimation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: KeyedSubtree(
                                  key: ValueKey(_currentFormIndex),
                                  child: _isLogin
                                      ? _buildLoginForm(strings, theme)
                                      : _buildRegisterForm(strings, theme),
                                ),
                              ),
                            ),

                            const SizedBox(height: AppSpacing.lg),
                            Center(
                              child: TextButton(
                                onPressed: loading ? null : _toggleForm,
                                child: RichText(
                                  text: TextSpan(
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.primary,
                                        ),
                                    children: [
                                      TextSpan(
                                        text: _isLogin
                                            ? strings.tr('needAccount')
                                            : strings.tr('haveAccount'),
                                      ),
                                      TextSpan(
                                        text:
                                            ' ${_isLogin ? strings.tr('registerNow') : strings.tr('loginInstead')}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // ---- Language chips footer ----
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        alignment: WrapAlignment.center,
                        children: AppLocale.values.map((locale) {
                          final selected = state.locale == locale.locale;
                          final labelStyle = theme.textTheme.labelMedium
                              ?.copyWith(
                                color: selected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.8,
                                      ),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              );
                          return ChoiceChip(
                            label: Text(locale.label),
                            selected: selected,
                            showCheckmark: false,
                            onSelected: (_) =>
                                context.read<AppState>().switchLocale(locale),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: theme.colorScheme.surface
                                .withValues(
                                  alpha: theme.brightness == Brightness.dark
                                      ? 0.26
                                      : 0.12,
                                ),
                            selectedColor: theme.colorScheme.primary,
                            side: BorderSide(
                              color: selected
                                  ? Colors.transparent
                                  : theme.colorScheme.outline.withValues(
                                      alpha: 0.16,
                                    ),
                            ),
                            labelStyle: labelStyle,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- Widgets ---
  Widget _buildLoginForm(AppLocalizations strings, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          key: const ValueKey('loginPhoneField'),
          controller: loginPhoneCtrl,
          label: strings.tr('phoneNumber'),
          focusNode: loginPhoneFocus,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          key: const ValueKey('loginPasswordField'),
          controller: loginPasswordCtrl,
          label: strings.tr('password'),
          obscureText: !loginPasswordVisible,
          focusNode: loginPasswordFocus,
          prefixIcon: Icons.lock_rounded,
          suffix: IconButton(
            icon: Icon(
              loginPasswordVisible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
            onPressed: () =>
                setState(() => loginPasswordVisible = !loginPasswordVisible),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Align(
        //   alignment: Alignment.centerRight,
        //   child: TextButton(
        //     onPressed: () => _showSnack(strings.tr('passwordRecoveryMock')),
        //     child: Text(strings.tr('forgotPassword')),
        //   ),
        // ),
        const SizedBox(height: AppSpacing.md),
        GradientButton(
          onPressed: loading ? null : _handleLogin,
          label: strings.tr('loginTitle'),
          icon: Icons.login_rounded,
          loading: loading,
        ),
      ],
    );
  }

  Widget _buildRegisterForm(AppLocalizations strings, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          key: const ValueKey('registerPhoneField'),
          controller: registerPhoneCtrl,
          label: strings.tr('phoneNumber'),
          focusNode: registerPhoneFocus,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          key: const ValueKey('registerNameField'),
          controller: registerNameCtrl,
          label: strings.tr('fullName'),
          focusNode: registerNameFocus,
          prefixIcon: Icons.person_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          key: const ValueKey('registerPasswordField'),
          controller: registerPasswordCtrl,
          label: strings.tr('password'),
          obscureText: !registerPasswordVisible,
          focusNode: registerPasswordFocus,
          prefixIcon: Icons.lock_rounded,
          suffix: IconButton(
            icon: Icon(
              registerPasswordVisible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
            onPressed: () => setState(
              () => registerPasswordVisible = !registerPasswordVisible,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          key: const ValueKey('registerConfirmField'),
          controller: registerConfirmCtrl,
          label: strings.tr('confirmPassword'),
          obscureText: !registerConfirmVisible,
          focusNode: registerConfirmFocus,
          prefixIcon: Icons.lock_reset_rounded,
          suffix: IconButton(
            icon: Icon(
              registerConfirmVisible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
            onPressed: () => setState(
              () => registerConfirmVisible = !registerConfirmVisible,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GradientButton(
          onPressed: loading ? null : _handleRegister,
          label: strings.tr('createAccount'),
          icon: Icons.person_add_alt_1_rounded,
          loading: loading,
        ),
      ],
    );
  }
}

/// Lightweight self-contained glass card (no dependency on your GlassCard)
class _FrostCard extends StatelessWidget {
  const _FrostCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const radius = BorderRadius.all(Radius.circular(16));
    final bg = theme.colorScheme.surface.withValues(alpha: 0.6);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(color: bg, borderRadius: radius),
              ),
            ),
          ),
        ),
        Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Colors.transparent,
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}
