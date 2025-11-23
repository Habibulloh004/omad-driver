import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../localization/localization_ext.dart';
import '../../models/app_notification.dart';
import '../../state/app_state.dart';
import '../../widgets/glass_card.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().refreshNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = context.strings;
    final notifications = state.notifications;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('notifications')),
        actions: [
          TextButton(
            onPressed: () => context.read<AppState>().markNotificationsRead(),
            child: Text(strings.tr('markAllRead')),
          ),
        ],
      ),
      body: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return _NotificationTile(notification: notification);
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (notification.category) {
      NotificationCategory.orderUpdate => theme.colorScheme.primary,
      NotificationCategory.promotion => const Color(0xFFEC4899),
      NotificationCategory.system => const Color(0xFF22D3EE),
    };

    final isRead = notification.isRead;

    return AnimatedOpacity(
      duration: AppDurations.medium,
      opacity: isRead ? 0.65 : 1,
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap: () =>
            context.read<AppState>().toggleNotificationRead(notification.id),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.16),
              ),
              child: Icon(switch (notification.category) {
                NotificationCategory.orderUpdate =>
                  Icons.notifications_active_rounded,
                NotificationCategory.promotion => Icons.local_offer_rounded,
                NotificationCategory.system => Icons.settings_suggest_rounded,
              }, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: AppDurations.short,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: isRead
                            ? const SizedBox(
                                key: ValueKey('read'),
                                width: 10,
                                height: 10,
                              )
                            : Container(
                                key: const ValueKey('unread'),
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    notification.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.9,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        DateFormat(
                          'dd MMM, HH:mm',
                        ).format(notification.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}