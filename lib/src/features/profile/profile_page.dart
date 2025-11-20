import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/auth_api.dart';
import '../../core/design_tokens.dart';
import '../../localization/app_localizations.dart';
import '../../localization/localization_ext.dart';
import '../../state/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/gradient_button.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = context.strings;
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
    final VoidCallback? driverButtonAction =
        (hasApprovedDriverAccess || (!pendingDriverReview && !user.isDriver))
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
                _ThemeToggleTile(
                  value: state.themeMode == ThemeMode.dark,
                  title: strings.tr('darkMode'),
                  subtitle: strings.tr('darkModeDescription'),
                  onChanged: () => context.read<AppState>().toggleTheme(),
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

  void _showEditProfile(BuildContext context) {
    final strings = context.strings;
    final state = context.read<AppState>();
    final nameCtrl = TextEditingController(text: state.currentUser.fullName);

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
                  decoration: InputDecoration(
                    labelText: strings.tr('fullName'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                GradientButton(
                  onPressed: () async {
                    try {
                      await state.updateProfile(name: nameCtrl.text);
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
    final state = context.read<AppState>();
    final user = state.currentUser;
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);

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

class _ThemeToggleTile extends StatelessWidget {
  const _ThemeToggleTile({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final String subtitle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseSurface = theme.colorScheme.surface.withValues(alpha: 0.12);
    final activeSurface = theme.colorScheme.primary.withValues(alpha: 0.18);
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
          Icon(
            value ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: theme.colorScheme.primary,
          ),
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
          Switch.adaptive(value: value, onChanged: (_) => onChanged()),
        ],
      ),
    );
  }
}
