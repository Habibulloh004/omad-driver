import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../localization/localization_ext.dart';
import '../../models/order.dart';
import '../../state/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = context.strings;
    final user = state.currentUser;
    final pendingOrders = state.pendingOrders;
    final activeOrders = state.activeOrders;
    final completedToday = state.historyOrders
        .where(
          (order) =>
              order.status == OrderStatus.completed &&
              order.date.day == DateTime.now().day,
        )
        .toList();
    final totalToday = completedToday.fold<double>(
      0,
      (total, order) => total + order.price,
    );
    final completedMonth = state.historyOrders
        .where(
          (order) =>
              order.status == OrderStatus.completed &&
              order.date.month == DateTime.now().month,
        )
        .toList();
    final totalMonth = completedMonth.fold<double>(
      0,
      (total, order) => total + order.price,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            context.read<AppState>().switchToPassengerMode();
            Navigator.pop(context);
          },
        ),
        title: Text(strings.tr('driverDashboard')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(strings.tr('currentBalance')),
                        Text(
                          NumberFormat.currency(
                            symbol: 'so\'m',
                            decimalDigits: 0,
                          ).format(user.balance),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  GradientButton(
                    onPressed: () => _showWithdrawDialog(context),
                    label: strings.tr('withdraw'),
                    icon: Icons.payments_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(strings.tr('todayStats')),
                        const SizedBox(height: 12),
                        Text(
                          strings
                              .tr('ordersCount')
                              .replaceFirst(
                                '{count}',
                                completedToday.length.toString(),
                              ),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          NumberFormat.currency(
                            symbol: 'so\'m',
                            decimalDigits: 0,
                          ).format(totalToday),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(strings.tr('monthStats')),
                        const SizedBox(height: 12),
                        Text(
                          strings
                              .tr('ordersCount')
                              .replaceFirst(
                                '{count}',
                                completedMonth.length.toString(),
                              ),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          NumberFormat.currency(
                            symbol: 'so\'m',
                            decimalDigits: 0,
                          ).format(totalMonth),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.local_taxi_rounded),
                  label: Text(strings.tr('newTaxiOrders')),
                  onPressed: () => _showPendingByType(context, OrderType.taxi),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.inventory_2_rounded),
                  label: Text(strings.tr('newDeliveryOrders')),
                  onPressed: () =>
                      _showPendingByType(context, OrderType.delivery),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.directions_car_filled_rounded),
                  label: Text(strings.tr('activeOrders')),
                  onPressed: () => _showActive(context),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.history_rounded),
                  label: Text(strings.tr('orderHistory')),
                  onPressed: () => _showHistory(context),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              strings.tr('incomingOrders'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (pendingOrders.isEmpty)
              GlassCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(strings.tr('noPendingOrders')),
                  ),
                ),
              )
            else
              Column(
                children: pendingOrders
                    .map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PendingOrderTile(order: order),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 32),
            Text(
              strings.tr('activeOrders'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (activeOrders.isEmpty)
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(strings.tr('noActiveDriverOrders')),
                  ),
                ),
              )
            else
              Column(
                children: activeOrders
                    .map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ActiveOrderTile(order: order),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context) {
    final strings = context.strings;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(strings.tr('withdraw')),
          content: Text(strings.tr('withdrawMock')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.tr('close')),
            ),
          ],
        );
      },
    );
  }

  void _showHistory(BuildContext context) {
    final strings = context.strings;
    final state = context.read<AppState>();
    final completed = state.historyOrders
        .where((order) => order.status == OrderStatus.completed)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.tr('completedOrders'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ...completed.map(
                  (order) => ListTile(
                    leading: Icon(
                      order.isTaxi
                          ? Icons.local_taxi_rounded
                          : Icons.inventory_2_rounded,
                    ),
                    title: Text('${order.fromDistrict} → ${order.toDistrict}'),
                    subtitle: Text(
                      NumberFormat.currency(
                        symbol: 'so\'m',
                        decimalDigits: 0,
                      ).format(order.price),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPendingByType(BuildContext context, OrderType type) {
    final strings = context.strings;
    final state = context.read<AppState>();
    final items = state.pendingOrders
        .where((order) => order.type == type)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type == OrderType.taxi
                      ? strings.tr('newTaxiOrders')
                      : strings.tr('newDeliveryOrders'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text(strings.tr('noPendingOrders'))),
                  )
                else
                  ...items.map(
                    (order) => ListTile(
                      leading: Icon(
                        order.isTaxi
                            ? Icons.local_taxi_rounded
                            : Icons.inventory_2_rounded,
                      ),
                      title: Text(
                        '${order.fromDistrict} → ${order.toDistrict}',
                      ),
                      subtitle: Text(
                        NumberFormat.currency(
                          symbol: 'so\'m',
                          decimalDigits: 0,
                        ).format(order.price),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showActive(BuildContext context) {
    final strings = context.strings;
    final state = context.read<AppState>();
    final items = state.activeOrders;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.tr('activeOrders'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(strings.tr('noActiveDriverOrders')),
                    ),
                  )
                else
                  ...items.map(
                    (order) => ListTile(
                      leading: Icon(
                        order.isTaxi
                            ? Icons.local_taxi_rounded
                            : Icons.inventory_2_rounded,
                      ),
                      title: Text(
                        '${order.fromDistrict} → ${order.toDistrict}',
                      ),
                      subtitle: Text(
                        NumberFormat.currency(
                          symbol: 'so\'m',
                          decimalDigits: 0,
                        ).format(order.price),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PendingOrderTile extends StatefulWidget {
  const _PendingOrderTile({required this.order});

  final AppOrder order;

  @override
  State<_PendingOrderTile> createState() => _PendingOrderTileState();
}

class _PendingOrderTileState extends State<_PendingOrderTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 5),
    )..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                avatar: Icon(
                  widget.order.isTaxi
                      ? Icons.local_taxi_rounded
                      : Icons.inventory_2_rounded,
                ),
                label: Text(
                  widget.order.isTaxi
                      ? strings.tr('taxiOrder')
                      : strings.tr('deliveryOrder'),
                ),
              ),
              const Spacer(),
              Text(widget.order.id),
            ],
          ),
          const SizedBox(height: 12),
          Text('${widget.order.fromDistrict} → ${widget.order.toDistrict}'),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final remaining = Duration(
                seconds:
                    ((controller.duration?.inSeconds ?? 0) *
                            (1 - controller.value))
                        .round(),
              );
              final minutes = (remaining.inMinutes).toString().padLeft(2, '0');
              final seconds = (remaining.inSeconds % 60).toString().padLeft(
                2,
                '0',
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: 1 - controller.value),
                  const SizedBox(height: 6),
                  Text(
                    strings
                        .tr('acceptTimer')
                        .replaceFirst('{time}', '$minutes:$seconds'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          GradientButton(
            onPressed: () {
              context.read<AppState>().acceptOrder(widget.order.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(strings.tr('orderAccepted'))),
              );
            },
            label: strings.tr('acceptOrder'),
            icon: Icons.check_circle_rounded,
          ),
        ],
      ),
    );
  }
}

class _ActiveOrderTile extends StatelessWidget {
  const _ActiveOrderTile({required this.order});

  final AppOrder order;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${order.fromDistrict} → ${order.toDistrict}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(order.id),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.startTime.format(context)} - ${order.endTime.format(context)}',
          ),
          const SizedBox(height: 12),
          GradientButton(
            onPressed: () {
              context.read<AppState>().completeOrder(order.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(strings.tr('orderCompleted'))),
              );
            },
            label: strings.tr('completeOrder'),
            icon: Icons.done_all_rounded,
          ),
        ],
      ),
    );
  }
}
