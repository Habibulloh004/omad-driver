import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../localization/localization_ext.dart';
import '../../models/order.dart';
import '../../state/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/gradient_button.dart';

class HomePage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = context.strings;
    final user = state.currentUser;
    final activeOrders = state.activeOrders;
    final historyOrders = state.historyOrders.take(6).toList();
    final mediaPadding = MediaQuery.of(context).padding;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final highlightWidth = (size.width * 0.78)
        .clamp(260.0, size.width - AppSpacing.md * 2)
        .toDouble();
    final highlightHeight = (size.height * 0.34).clamp(240.0, 320.0).toDouble();

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
                    Text(
                      strings.tr('homeGreeting'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundImage: NetworkImage(user.avatarUrl),
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
                              const double horizontalGap = AppSpacing.md;
                              const double verticalGap = AppSpacing.sm;
                              final taxiButton = GradientButton(
                                onPressed: onOrderTaxi,
                                label: strings.tr('orderTaxi'),
                                icon: Icons.local_taxi_rounded,
                              );
                              final deliveryButton = GradientButton(
                                onPressed: onSendDelivery,
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
                    Text(
                      strings.tr('activeOrders'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: highlightHeight,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: activeOrders.isEmpty
                            ? 1
                            : activeOrders.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.md),
                        itemBuilder: (context, index) {
                          if (activeOrders.isEmpty) {
                            return _EmptyCard(
                              width: highlightWidth,
                              message: strings.tr('noActiveOrders'),
                            );
                          }
                          final order = activeOrders[index];
                          return _OrderHighlightCard(
                            order: order,
                            width: highlightWidth,
                          );
                        },
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
        Positioned(
          bottom: AppSpacing.lg + mediaPadding.bottom,
          right: AppSpacing.md + mediaPadding.right,
          child: FloatingActionButton.extended(
            heroTag: 'notifications-fab',
            backgroundColor: theme.colorScheme.primary,
            icon: const Icon(Icons.notifications_active_rounded),
            label: Text(strings.tr('notifications')),
            onPressed: onOpenNotifications,
          ),
        ),
      ],
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
                icon: Icons.lock_reset_rounded,
              ),
            ],
          ),
        );
      },
    );
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
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                const SizedBox(width: AppSpacing.md),
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
                const SizedBox(width: AppSpacing.md),
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
                  icon: Icons.timelapse_rounded,
                  value:
                      '${order.startTime.format(context)} - ${order.endTime.format(context)}',
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
                Text(
                  NumberFormat.currency(
                    locale: 'uz_UZ',
                    symbol: 'so\'m',
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
    final time =
        '${order.startTime.format(context)} - ${order.endTime.format(context)}';

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
                const SizedBox(height: AppSpacing.xs),
                Text(time, style: Theme.of(context).textTheme.bodyMedium),
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
