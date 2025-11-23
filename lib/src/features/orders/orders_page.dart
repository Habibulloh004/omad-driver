import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../api/auth_api.dart';
import '../../core/design_tokens.dart';
import '../../localization/localization_ext.dart';
import '../../models/order.dart';
import '../../state/app_state.dart';
import '../auth/auth_guard.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pill_tabs.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with AutomaticKeepAliveClientMixin<OrdersPage> {
  int currentTab = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: currentTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCurrentTabWithController();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = context.watch<AppState>();
    final strings = context.strings;
    _drainUserRealtimeToasts(state);
    final isAuthenticated = state.isAuthenticated;
    if (!isAuthenticated) {
      return _GuestOrdersPlaceholder(
        message: strings.tr('loginToSeeOrders'),
        onLogin: () => ensureLoggedIn(context),
      );
    }
    final activeOrders = state.activeOrders;
    final historyOrders = state.historyOrders;
    const activeMoreThreshold = 20;
    const historyMoreThreshold = 20;
    bool _hasMoreFor({required List<AppOrder> orders, required bool isActive}) {
      final threshold = isActive ? activeMoreThreshold : historyMoreThreshold;
      // Only show "More" when we've reached the tab threshold and backend reports more pages.
      return orders.length >= threshold && state.hasMoreOrders;
    }

    final activeHasMore = _hasMoreFor(orders: activeOrders, isActive: true);
    final historyHasMore = _hasMoreFor(orders: historyOrders, isActive: false);
    final mediaPadding = MediaQuery.of(context).padding;
    final bottomSpacing =
        mediaPadding.bottom + AppSpacing.xxl * 2 + AppSpacing.lg;
    final theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (historyOrders.isNotEmpty)
          Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: IgnorePointer(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.cardRadius,
                  boxShadow: AppShadows.soft(
                    baseColor: theme.colorScheme.primary,
                    isDark: theme.brightness == Brightness.dark,
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md + mediaPadding.left,
            AppSpacing.lg + mediaPadding.top,
            AppSpacing.md + mediaPadding.right,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.tr('ordersTitle'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PillTabs(
                tabs: [strings.tr('activeTab'), strings.tr('historyTab')],
                current: currentTab,
                onChanged: _animateToTab,
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ClipRect(
                  clipper: const _OrdersViewportClipper(),
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.none,
                    onPageChanged: (index) {
                      if (currentTab == index) return;
                      setState(() => currentTab = index);
                    },
                    itemCount: 2,
                    itemBuilder: (context, index) {
                      final isActiveTab = index == 0;
                      final orders = isActiveTab ? activeOrders : historyOrders;
                      final hasMoreForTab = isActiveTab
                          ? activeHasMore
                          : historyHasMore;
                      final showTopMoreButton =
                          isActiveTab &&
                          hasMoreForTab; // keep top button only for active
                      final emptyText = isActiveTab
                          ? strings.tr('noActiveOrders')
                          : strings.tr('noHistory');

                      final isLoadingMore = state.isLoadingMoreOrders;
                      final showMoreButton = hasMoreForTab;
                      final showLoaderRow = isLoadingMore || showMoreButton;
                      final child = orders.isEmpty
                          ? (isLoadingMore
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : Center(
                                    key: ValueKey('empty-$index'),
                                    child: Text(
                                      emptyText,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ))
                          : ListView.separated(
                              key: PageStorageKey('orders-$index'),
                              physics: const BouncingScrollPhysics(),
                              clipBehavior: Clip.none,
                              padding: EdgeInsets.only(
                                top: AppSpacing.sm,
                                bottom: bottomSpacing,
                              ),
                              itemCount:
                                  orders.length +
                                  (showTopMoreButton ? 1 : 0) +
                                  (showLoaderRow ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, listIndex) {
                                // Leading "More" button at top for active tab.
                                if (showTopMoreButton && listIndex == 0) {
                                  return Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: () => context
                                          .read<AppState>()
                                          .loadMoreOrders(),
                                      child: Text(strings.tr('more')),
                                    ),
                                  );
                                }

                                final adjustedIndex =
                                    listIndex - (showTopMoreButton ? 1 : 0);
                                if (adjustedIndex >= orders.length) {
                                  if (isLoadingMore) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: AppSpacing.md,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  if (!showMoreButton) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.sm,
                                    ),
                                    child: Center(
                                      child: ElevatedButton(
                                        onPressed: () => context
                                            .read<AppState>()
                                            .loadMoreOrders(),
                                        child: Text(strings.tr('more')),
                                      ),
                                    ),
                                  );
                                }

                                final order = orders[adjustedIndex];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                  ),
                                  child: _OrderCard(
                                    order: order,
                                    onTap: () => _openDetails(context, order),
                                  ),
                                );
                              },
                            );

                      return _OrdersParallaxPage(
                        controller: _pageController,
                        index: index,
                        child: child,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openDetails(BuildContext sheetContext, AppOrder order) async {
    final strings = sheetContext.strings;
    final scaffoldContext = context;
    final dateLabel = DateFormat('dd MMMM, yyyy').format(order.date);
    final startTimeLabel = order.startTime.format(context);
    final dateTimeLabel = '$dateLabel • $startTimeLabel';

    await showModalBottomSheet(
      context: sheetContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        TextEditingController? cancelReasonCtrl;
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
                Row(
                  children: [
                    Text(
                      strings.tr('orderDetails'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: strings.tr('close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _DetailTile(
                  icon: Icons.map_rounded,
                  title: strings.tr('fromLocation'),
                  subtitle: '${order.fromRegion}, ${order.fromDistrict}',
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailTile(
                  icon: Icons.flag_rounded,
                  title: strings.tr('toLocation'),
                  subtitle: '${order.toRegion}, ${order.toDistrict}',
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailTile(
                  icon: Icons.calendar_today_rounded,
                  title: strings.tr('date'),
                  subtitle: dateTimeLabel,
                ),
                if (order.priceAvailable) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _DetailTile(
                    icon: Icons.attach_money_rounded,
                    title: strings.tr('price'),
                    subtitle: NumberFormat.currency(
                      symbol: 'so\'m ',
                      decimalDigits: 0,
                    ).format(order.price),
                  ),
                ],
                if (order.driverName != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _DetailTile(
                    icon: Icons.person_rounded,
                    title: order.driverName!,
                    subtitle: order.driverPhone ?? '',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DetailTile(
                    icon: Icons.directions_car_filled_rounded,
                    title: order.vehicle ?? '',
                    subtitle: order.vehiclePlate ?? '',
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (order.status == OrderStatus.pending ||
                    order.status == OrderStatus.active)
                  StatefulBuilder(
                    builder: (context, setSheetState) {
                      cancelReasonCtrl ??= TextEditingController();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: cancelReasonCtrl,
                            minLines: 2,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: strings.tr('cancelReason'),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              final reason = cancelReasonCtrl!.text.isEmpty
                                  ? strings.tr('cancelledByUser')
                                  : cancelReasonCtrl!.text;
                              final state = context.read<AppState>();
                              final messenger = ScaffoldMessenger.of(
                                scaffoldContext,
                              );
                              try {
                                await state.cancelOrder(order.id, reason);
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(strings.tr('orderCancelled')),
                                  ),
                                );
                              } on ApiException catch (error) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(content: Text(error.message)),
                                );
                              } catch (_) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      strings.tr('unexpectedError'),
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.cancel_schedule_send_rounded,
                            ),
                            label: Text(strings.tr('cancelOrder')),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.sm,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadii.rounded,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      strings.tr('status_${order.status.name}'),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  void _animateToTab(int index) {
    if (index == currentTab) return;
    setState(() => currentTab = index);
    _pageController.animateToPage(
      index,
      duration: AppDurations.long,
      curve: Curves.easeInOutCubic,
    );
  }

  void _syncCurrentTabWithController() {
    if (!mounted || !_pageController.hasClients) return;
    final page = _pageController.page ?? _pageController.initialPage.toDouble();
    final index = page.round();
    if (index != currentTab) {
      setState(() => currentTab = index);
    }
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
}

class _GuestOrdersPlaceholder extends StatelessWidget {
  const _GuestOrdersPlaceholder({required this.message, required this.onLogin});

  final String message;
  final Future<bool> Function() onLogin;

  @override
  Widget build(BuildContext context) {
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
                size: 42,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () => onLogin(),
                icon: const Icon(Icons.login_rounded),
                label: Text(context.strings.tr('loginTitle')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersViewportClipper extends CustomClipper<Rect> {
  const _OrdersViewportClipper();

  static const double _horizontalOverflowAllowance = 48;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      -_horizontalOverflowAllowance,
      0,
      size.width + _horizontalOverflowAllowance,
      size.height,
    );
  }

  @override
  bool shouldReclip(covariant _OrdersViewportClipper oldClipper) => false;
}

class _OrdersParallaxPage extends StatelessWidget {
  const _OrdersParallaxPage({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, widget) {
        final hasClients = controller.hasClients;
        final page = hasClients
            ? controller.page ?? controller.initialPage.toDouble()
            : controller.initialPage.toDouble();
        final delta = page - index;
        final translateX = -delta * 28;

        return Transform.translate(
          offset: Offset(translateX, 0),
          child: widget,
        );
      },
      child: child,
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final AppOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final statusColor = switch (order.status) {
      OrderStatus.pending => theme.colorScheme.primary,
      OrderStatus.active => const Color(0xFF0EA5E9),
      OrderStatus.completed => const Color(0xFF10B981),
      OrderStatus.cancelled => const Color(0xFFEF4444),
    };

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadii.rounded,
              color: statusColor.withValues(alpha: 0.12),
            ),
            child: Icon(
              order.isTaxi
                  ? Icons.local_taxi_rounded
                  : Icons.inventory_2_rounded,
              color: statusColor,
              size: 28,
            ),
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
                        order.isTaxi
                            ? strings.tr('taxiOrder')
                            : strings.tr('deliveryOrder'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${order.fromDistrict} → ${order.toDistrict}',
                  style: theme.textTheme.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _MetaField(
                      icon: Icons.schedule_rounded,
                      label: order.startTime.format(context),
                    ),
                    _MetaField(
                      icon: Icons.calendar_month_rounded,
                      label:
                          '${order.date.day.toString().padLeft(2, '0')}.${order.date.month.toString().padLeft(2, '0')}',
                    ),
                    _MetaField(
                      icon: Icons.people_alt_rounded,
                      label: '${order.passengers}',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: AppRadii.pillRadius,
                        color: statusColor.withValues(alpha: 0.12),
                      ),
                      child: Text(
                        strings.tr('status_${order.status.name}'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (order.priceAvailable)
                      Text(
                        NumberFormat.compactCurrency(
                          symbol: 'so\'m ',
                          decimalDigits: 0,
                        ).format(order.price),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaField extends StatelessWidget {
  const _MetaField({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadii.pillRadius,
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
