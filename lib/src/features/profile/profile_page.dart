import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../localization/app_localizations.dart';
import '../../localization/localization_ext.dart';
import '../../state/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/gradient_button.dart';
import '../driver/driver_application_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.onOpenDriverDashboard});

  final VoidCallback onOpenDriverDashboard;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = context.strings;
    final user = state.currentUser;
    final mediaPadding = MediaQuery.of(context).padding;
    final theme = Theme.of(context);

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
          Text(
            strings.tr('profileTitle'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
                      backgroundImage: NetworkImage(user.avatarUrl),
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
                  onPressed: () => _handleDriverNavigation(context),
                  label: user.isDriver
                      ? (user.driverApproved
                            ? strings.tr('switchToDriver')
                            : strings.tr('applicationPending'))
                      : strings.tr('becomeDriver'),
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
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FilledButton.icon(
              onPressed: () => context.read<AppState>().logout(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(borderRadius: AppRadii.rounded),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: Text(strings.tr('logout')),
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
    final avatarCtrl = TextEditingController(text: state.currentUser.avatarUrl);

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
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: avatarCtrl,
                  decoration: InputDecoration(
                    labelText: strings.tr('avatarUrl'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                GradientButton(
                  onPressed: () {
                    state.updateProfile(
                      name: nameCtrl.text,
                      avatar: avatarCtrl.text,
                    );
                    Navigator.pop(context);
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
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(strings.tr('passwordUpdated'))),
                  );
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

  void _handleDriverNavigation(BuildContext context) {
    final state = context.read<AppState>();
    final user = state.currentUser;
    final strings = context.strings;

    if (!user.isDriver && !state.driverApplicationSubmitted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DriverApplicationPage()),
      );
      return;
    }

    if (!user.driverApproved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.tr('applicationPending'))));
      return;
    }

    state.switchToDriverMode();
    onOpenDriverDashboard();
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
