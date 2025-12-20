import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/auth_api.dart';
import '../../core/design_tokens.dart';
import '../../localization/app_localizations.dart';
import '../../localization/localization_ext.dart';
import '../../state/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/gradient_button.dart';
import '../auth/auth_guard.dart';
import '../driver/driver_application_page.dart';
import 'edit_profile_photo_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.onOpenDriverDashboard});

  final VoidCallback onOpenDriverDashboard;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _refreshingProfile = false;
  bool _openingDriver = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = context.strings;
    final isAuthenticated = state.isAuthenticated;
    if (!isAuthenticated) {
      return _ProfileLoginGate(onLogin: () => ensureLoggedIn(context));
    }
    final user = state.currentUser;
    final mediaPadding = MediaQuery.of(context).padding;
    final theme = Theme.of(context);
    final hasApprovedDriverAccess = user.isDriver && user.driverApproved;
    final pendingDriverReview =
        (!user.isDriver && state.driverApplicationSubmitted) ||
        (user.isDriver && !user.driverApproved);
    final driverButtonLabel = hasApprovedDriverAccess
        ? strings.tr('switchToDriver')
        : pendingDriverReview
        ? strings.tr('applicationPending')
        : strings.tr('becomeDriver');
    final VoidCallback? driverButtonAction = _openingDriver
        ? null
        : (hasApprovedDriverAccess || (!pendingDriverReview && !user.isDriver))
        ? () => _handleDriverNavigation(context)
        : null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md + mediaPadding.left,
        AppSpacing.lg + mediaPadding.top,
        AppSpacing.md + mediaPadding.right,
        mediaPadding.bottom + AppSpacing.xxl * 2 + AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.tr('profile'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _callUserPhone(context, '1829'),
                icon: const Icon(Icons.phone_rounded),
                tooltip: '1829',
              ),
              const SizedBox(width: AppSpacing.xs),
              if (user.isDriver || pendingDriverReview) ...[
                IconButton(
                  onPressed: _openingDriver
                      ? null
                      : () => _handleDriverNavigation(context),
                  icon: const Icon(Icons.directions_car_filled_rounded),
                  tooltip: strings.tr('switchToDriver'),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              IconButton(
                onPressed: () => context.read<AppState>().logout(),
                icon: const Icon(Icons.logout_rounded),
                tooltip: strings.tr('logout'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: user.avatarUrl.isEmpty
                          ? null
                          : NetworkImage(user.avatarUrl),
                      child: user.avatarUrl.isEmpty
                          ? Icon(
                              Icons.person_rounded,
                              size: 36,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${strings.tr('phoneNumberShort')}: ${user.phoneNumber}',
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${strings.tr('userIdLabel')}: ${user.id}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                iconSize: 20,
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _copyUserId(context, user.id),
                                icon: const Icon(Icons.copy_rounded),
                                tooltip: strings.tr('copy'),
                              ),
                            ],
                          ),
                          if (user.isDriver) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 18,
                                  color: theme.colorScheme.tertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  strings
                                      .tr('ratingWithValue')
                                      .replaceFirst(
                                        '{rating}',
                                        user.rating.toStringAsFixed(1),
                                      ),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showEditProfile(context),
                      icon: const Icon(Icons.edit_rounded),
                      tooltip: strings.tr('editProfile'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _refreshingProfile
                        ? null
                        : () => _refreshProfileData(context),
                    icon: _refreshingProfile
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(strings.tr('refreshProfile')),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const EditProfilePhotoPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text(strings.tr('changePhoto')),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                GradientButton(
                  onPressed: () => _showChangePassword(context),
                  label: strings.tr('changePassword'),
                  icon: Icons.lock_reset_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.tr('language'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  runSpacing: AppSpacing.xs,
                  children: AppLocale.values.map((locale) {
                    final selected = state.locale == locale.locale;
                    return ChoiceChip(
                      label: Text(locale.label),
                      selected: selected,
                      onSelected: (_) =>
                          context.read<AppState>().switchLocale(locale),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xl),
                _SettingsToggleTile(
                  value: state.themeMode == ThemeMode.dark,
                  title: strings.tr('darkMode'),
                  subtitle: strings.tr('darkModeDescription'),
                  icon: Icons.light_mode_rounded,
                  activeIcon: Icons.dark_mode_rounded,
                  onChanged: (_) => context.read<AppState>().toggleTheme(),
                ),
                if (hasApprovedDriverAccess) ...[
                  const SizedBox(height: AppSpacing.md),
                  _SettingsToggleTile(
                    value: state.driverIncomingSoundEnabled,
                    title: strings.tr('driverIncomingSound'),
                    subtitle: strings.tr('driverIncomingSoundDescription'),
                    icon: Icons.volume_off_rounded,
                    activeIcon: Icons.volume_up_rounded,
                    onChanged: (enabled) => context
                        .read<AppState>()
                        .setDriverIncomingSoundEnabled(enabled),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SettingsToggleTile(
                    value: state.driverIncomingOrdersEnabled,
                    title: strings.tr('driverIncomingOrders'),
                    subtitle: strings.tr('driverIncomingOrdersDescription'),
                    icon: Icons.sync_disabled_rounded,
                    activeIcon: Icons.sync_rounded,
                    onChanged: (enabled) => context
                        .read<AppState>()
                        .setDriverIncomingOrdersEnabled(enabled),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.tr('driverMode'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  strings.tr('driverModeDescription'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                GradientButton(
                  onPressed: driverButtonAction,
                  label: driverButtonLabel,
                  icon: Icons.drive_eta_rounded,
                  loading: _openingDriver,
                ),
                if (user.isDriver && user.driverApproved) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    strings
                        .tr('driverBalance')
                        .replaceFirst(
                          '{balance}',
                          user.balance.toStringAsFixed(0),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callUserPhone(BuildContext context, String phone) async {
    if (phone.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final telUri = Uri(scheme: 'tel', path: phone);
    try {
      final launched = await launchUrl(telUri);
      if (!launched) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.strings.tr('unexpectedError'))),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.strings.tr('unexpectedError'))),
      );
    }
  }

  void _showEditProfile(BuildContext context) {
    final strings = context.strings;
    final state = context.read<AppState>();
    final nameCtrl = TextEditingController(text: state.currentUser.fullName);
    final phoneCtrl = TextEditingController(
      text: state.currentUser.phoneNumber,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
          ),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.tr('editProfile'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: strings.tr('fullName'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: strings.tr('phoneNumber'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                GradientButton(
                  onPressed: () async {
                    try {
                      await state.updateProfile(
                        name: nameCtrl.text,
                        phoneNumber: phoneCtrl.text,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } on ApiException catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.message)));
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(strings.tr('unexpectedError'))),
                      );
                    }
                  },
                  label: strings.tr('save'),
                  icon: Icons.save_rounded,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showChangePassword(BuildContext context) async {
    final strings = context.strings;
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    await showGlassDialog(
      context: context,
      barrierLabel: strings.tr('close'),
      builder: (dialogContext) {
        return GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.tr('changePassword'),
                style: Theme.of(
                  dialogContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: oldCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: strings.tr('oldPassword'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: strings.tr('newPassword'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: strings.tr('confirmNewPassword'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              GradientButton(
                onPressed: () async {
                  if (newCtrl.text != confirmCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.tr('passwordMismatch'))),
                    );
                    return;
                  }
                  final state = context.read<AppState>();
                  try {
                    await state.changePassword(
                      oldPassword: oldCtrl.text,
                      newPassword: newCtrl.text,
                      confirmPassword: confirmCtrl.text,
                    );
                    if (!context.mounted) return;
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.tr('passwordUpdated'))),
                    );
                  } on ApiException catch (error) {
                    if (!context.mounted) return;
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.message)));
                  } catch (_) {
                    if (!context.mounted) return;
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.tr('unexpectedError'))),
                    );
                  }
                },
                label: strings.tr('save'),
                icon: Icons.check_rounded,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleDriverNavigation(BuildContext context) async {
    if (_openingDriver) return;
    setState(() => _openingDriver = true);
    final state = context.read<AppState>();
    final user = state.currentUser;
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (!user.isDriver && !state.driverApplicationSubmitted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverApplicationPage()),
        );
        return;
      }

      if (!user.driverApproved) {
        messenger.showSnackBar(
          SnackBar(content: Text(strings.tr('applicationPending'))),
        );
        return;
      }

      try {
        await state.refreshDriverStatus(loadDashboard: true);
      } on ApiException catch (error) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(content: Text(strings.tr('unexpectedError'))),
        );
      }

      state.switchToDriverMode();
      widget.onOpenDriverDashboard();
    } finally {
      if (mounted) {
        setState(() => _openingDriver = false);
      } else {
        _openingDriver = false;
      }
    }
  }

  Future<void> _copyUserId(BuildContext context, String userId) async {
    await Clipboard.setData(ClipboardData(text: userId));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.strings.tr('copied'))));
  }

  Future<void> _refreshProfileData(BuildContext context) async {
    if (_refreshingProfile) return;
    setState(() => _refreshingProfile = true);
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<AppState>();
    try {
      await Future.wait([
        state.refreshProfile(),
        state.refreshDriverStatus(loadDashboard: true),
      ]);
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.tr('unexpectedError'))),
      );
    } finally {
      if (mounted) {
        setState(() => _refreshingProfile = false);
      }
    }
  }
}

class _ProfileLoginGate extends StatelessWidget {
  const _ProfileLoginGate({required this.onLogin});

  final Future<bool> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final mediaPadding = MediaQuery.of(context).padding;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md + mediaPadding.left,
        AppSpacing.lg + mediaPadding.top,
        AppSpacing.md + mediaPadding.right,
        mediaPadding.bottom + AppSpacing.xxl,
      ),
      child: Center(
        child: GlassCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                strings.tr('loginRequired'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () => onLogin(),
                icon: const Icon(Icons.login_rounded),
                label: Text(strings.tr('loginTitle')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  const _SettingsToggleTile({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.activeIcon,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData? activeIcon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseSurface = theme.colorScheme.surface.withValues(alpha: 0.12);
    final activeSurface = theme.colorScheme.primary.withValues(alpha: 0.18);
    final leadingIcon = value && activeIcon != null ? activeIcon! : icon;
    return AnimatedContainer(
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadii.rounded,
        color: Color.lerp(baseSurface, activeSurface, value ? 1 : 0),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(leadingIcon, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
