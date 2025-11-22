import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../api/auth_api.dart';
import '../../core/design_tokens.dart';
import '../../localization/localization_ext.dart';
import '../../models/order.dart';
import '../../state/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/gradient_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onOrderTaxi,
    required this.onSendDelivery,
    required this.onOpenNotifications,
  });

  final VoidCallback onOrderTaxi;
  final VoidCallback onSendDelivery;
  final VoidCallback onOpenNotifications;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ScrollController _activeOrdersController;

  @override
  void initState() {
    super.initState();
    _activeOrdersController = ScrollController();
  }

  @override
  void dispose() {
    _activeOrdersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _drainUserRealtimeToasts(state);
    final strings = context.strings;
    final user = state.currentUser;
    final activeOrders = state.activeOrders.take(20).toList();
    final historyOrders = state.historyOrders.take(5).toList();
    final hasUnreadNotifications = state.notifications.any(
      (notification) => !notification.isRead,
    );
    final notificationSignal = state.notificationSignal;
    final mediaPadding = MediaQuery.of(context).padding;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final localizations = MaterialLocalizations.of(context);
    final highlightWidth = (size.width * 0.78)
        .clamp(260.0, size.width - AppSpacing.md * 2)
        .toDouble();

    return Stack(
      children: [
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md + mediaPadding.left,
                AppSpacing.lg + mediaPadding.top,
                AppSpacing.md + mediaPadding.right,
                mediaPadding.bottom + AppSpacing.xxl * 2 + AppSpacing.lg,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            strings.tr('homeGreeting'),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _NotificationButton(
                          onTap: widget.onOpenNotifications,
                          hasUnread: hasUnreadNotifications,
                          activationToken: notificationSignal,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundImage: user.avatarUrl.isEmpty
                                    ? null
                                    : NetworkImage(user.avatarUrl),
                                child: user.avatarUrl.isEmpty
                                    ? Icon(
                                        Icons.person_rounded,
                                        size: 32,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
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
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone_rounded,
                                          size: 18,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Text(user.phoneNumber),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    if (user.isDriver)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.star_rounded,
                                            size: 18,
                                            color: theme.colorScheme.tertiary,
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          Text(
                                            strings
                                                .tr('ratingWithValue')
                                                .replaceFirst(
                                                  '{rating}',
                                                  user.rating.toStringAsFixed(
                                                    1,
                                                  ),
                                                ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _showChangePassword(context),
                                icon: const Icon(Icons.settings_rounded),
                                tooltip: strings.tr('changePassword'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              const double horizontalGap = AppSpacing.lg;
                              const double verticalGap = AppSpacing.md;
                              final taxiButton = GradientButton(
                                onPressed: widget.onOrderTaxi,
                                label: strings.tr('orderTaxi'),
                                icon: Icons.local_taxi_rounded,
                              );
                              final deliveryButton = GradientButton(
                                onPressed: widget.onSendDelivery,
                                label: strings.tr('sendDelivery'),
                                icon: Icons.delivery_dining_rounded,
                              );
                              if (constraints.maxWidth < 540) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    taxiButton,
                                    const SizedBox(height: verticalGap),
                                    deliveryButton,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: taxiButton),
                                  const SizedBox(width: horizontalGap),
                                  Expanded(child: deliveryButton),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.tr('activeOrders'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (activeOrders.isNotEmpty) ...[
                          _ActiveOrdersPagerButton(
                            icon: Icons.chevron_left_rounded,
                            tooltip: localizations.previousPageTooltip,
                            onPressed: () => _animateActiveOrdersScroll(
                              forward: false,
                              step: highlightWidth + AppSpacing.md,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _ActiveOrdersPagerButton(
                            icon: Icons.chevron_right_rounded,
                            tooltip: localizations.nextPageTooltip,
                            onPressed: () => _animateActiveOrdersScroll(
                              forward: true,
                              step: highlightWidth + AppSpacing.md,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SingleChildScrollView(
                      controller: _activeOrdersController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xxs,
                      ),
                      child: Row(
                        children: [
                          if (activeOrders.isEmpty)
                            _EmptyCard(
                              width: highlightWidth,
                              message: strings.tr('noActiveOrders'),
                            )
                          else
                            for (var i = 0; i < activeOrders.length; i++) ...[
                              if (i != 0) const SizedBox(width: AppSpacing.md),
                              _OrderHighlightCard(
                                order: activeOrders[i],
                                width: highlightWidth,
                              ),
                            ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: _SectionDivider(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      strings.tr('recentOrders'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (historyOrders.isEmpty)
                      _EmptyCard(
                        width: double.infinity,
                        message: strings.tr('noHistory'),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < historyOrders.length; i++) ...[
                            _OrderListTile(order: historyOrders[i]),
                            if (i != historyOrders.length - 1)
                              const SizedBox(height: AppSpacing.sm),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _animateActiveOrdersScroll({
    required bool forward,
    required double step,
  }) {
    final controller = _activeOrdersController;
    if (!controller.hasClients) return;
    final minExtent = controller.position.minScrollExtent;
    final maxExtent = controller.position.maxScrollExtent;
    final target = (controller.offset + (forward ? step : -step)).clamp(
      minExtent,
      maxExtent,
    );
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _drainUserRealtimeToasts(AppState state) {
    final pending = <({String title, String message})>[];
    while (true) {
      final toast = state.takeNextUserRealtimeMessage();
      if (toast == null) break;
      pending.add(toast);
    }
    if (pending.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      for (final toast in pending) {
        final text = toast.title.isEmpty
            ? toast.message
            : '${toast.title}: ${toast.message}';
        messenger.showSnackBar(SnackBar(content: Text(text)));
      }
    });
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
                icon: Icons.lock_reset_rounded,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationButton extends StatefulWidget {
  const _NotificationButton({
    required this.onTap,
    required this.hasUnread,
    required this.activationToken,
  });

  final VoidCallback onTap;
  final bool hasUnread;
  final int activationToken;

  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    if (widget.hasUnread) {
      _startAlarmCycle(force: true);
    }
  }

  @override
  void didUpdateWidget(covariant _NotificationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.hasUnread) {
      if (oldWidget.hasUnread) {
        _controller
          ..stop()
          ..reset();
      }
      return;
    }
    final tokenChanged = widget.activationToken != oldWidget.activationToken;
    final becameUnread = widget.hasUnread && !oldWidget.hasUnread;
    if (tokenChanged || becameUnread) {
      _startAlarmCycle(force: true);
    } else if (!_controller.isAnimating) {
      _startAlarmCycle(force: false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = LinearGradient(
      colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: AppRadii.buttonRadius,
        boxShadow: AppShadows.soft(
          baseColor: theme.colorScheme.primary,
          isDark: theme.brightness == Brightness.dark,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.buttonRadius,
          onTap: widget.onTap,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = widget.hasUnread ? _controller.value : 0.0;
                final angle = _alarmAngle(t);
                return Stack(
                  alignment: Alignment.center,
                  children: [Transform.rotate(angle: angle, child: child)],
                );
              },
              child: Icon(
                Icons.notifications_active_rounded,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startAlarmCycle({required bool force}) {
    if (!widget.hasUnread) return;
    if (_controller.isAnimating || _controller.value != 0) {
      _controller
        ..stop()
        ..reset();
    }
    _controller.repeat();
  }

  double _alarmAngle(double t) {
    if (t <= 0) return 0;
    const ringPortion = 0.35; // ~1s of shaking, then ~2s rest
    final local = t % 1;
    if (local >= ringPortion) return 0;

    final progress = (local / ringPortion).clamp(0.0, 1.0);
    final oscillations = 6.0;
    final envelope = Curves.easeOutQuad.transform(1 - progress);
    final maxTilt = 0.42;
    final minTilt = 0.18;
    final tilt = maxTilt - (maxTilt - minTilt) * progress;
    return math.sin(progress * oscillations * math.pi * 2) * tilt * envelope;
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.outlineVariant.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.22 : 0.35,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [base.withValues(alpha: 0), base, base.withValues(alpha: 0)],
        ),
      ),
      child: const SizedBox(height: 1),
    );
  }
}

class _ActiveOrdersPagerButton extends StatelessWidget {
  const _ActiveOrdersPagerButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

class _OrderHighlightCard extends StatelessWidget {
  const _OrderHighlightCard({required this.order, required this.width});

  final AppOrder order;
  final double width;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final dateFormatter = DateFormat('dd MMM, HH:mm');

    return SizedBox(
      width: width,
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.pillRadius,
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        order.isTaxi
                            ? Icons.local_taxi_rounded
                            : Icons.delivery_dining_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        order.isTaxi
                            ? strings.tr('taxiOrder')
                            : strings.tr('deliveryOrder'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.my_location_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${order.fromRegion}, ${order.fromDistrict}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: theme.colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${order.toRegion}, ${order.toDistrict}',
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                _MetaInfo(
                  icon: Icons.schedule_rounded,
                  value: dateFormatter.format(order.date),
                ),
                _MetaInfo(
                  icon: Icons.people_alt_rounded,
                  value: '${order.passengers}',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (order.priceAvailable)
                  Text(
                    NumberFormat.currency(
                      locale: 'uz_UZ',
                      symbol: 'so\'m ',
                      decimalDigits: 0,
                    ).format(order.price),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const Spacer(),
                _StatusChip(status: order.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaInfo extends StatelessWidget {
  const _MetaInfo({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = theme.colorScheme.surface.withValues(
      alpha: isDark ? 0.26 : 0.12,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadii.pillRadius,
        color: background,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.85,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderListTile extends StatelessWidget {
  const _OrderListTile({required this.order});

  final AppOrder order;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              order.isTaxi
                  ? Icons.local_taxi_rounded
                  : Icons.inventory_2_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.fromDistrict} → ${order.toDistrict}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _StatusChip(status: order.status),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.width, required this.message});

  final double width;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GlassCard(
        child: Center(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    Color background;
    Color foreground;
    switch (status) {
      case OrderStatus.pending:
        background = theme.colorScheme.primary.withValues(alpha: 0.12);
        foreground = theme.colorScheme.primary;
        break;
      case OrderStatus.active:
        background = const Color(0xFF1ABC9C).withValues(alpha: 0.12);
        foreground = const Color(0xFF1ABC9C);
        break;
      case OrderStatus.completed:
        background = const Color(0xFF10B981).withValues(alpha: 0.12);
        foreground = const Color(0xFF059669);
        break;
      case OrderStatus.cancelled:
        background = const Color(0xFFEF4444).withValues(alpha: 0.12);
        foreground = const Color(0xFFB91C1C);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: background,
      ),
      child: Text(
        strings.tr('status_${status.name}'),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
