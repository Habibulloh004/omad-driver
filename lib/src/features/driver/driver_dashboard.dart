import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../api/auth_api.dart';
import '../../localization/localization_ext.dart';
import '../../models/order.dart';
import '../../state/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';

const Duration _kDriverAcceptWindow = Duration(minutes: 5);

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  static const Duration _autoRefreshInterval = Duration(minutes: 10);
  Timer? _profileRefreshTimer;
  bool _isProfileRefreshing = false;

  @override
  void initState() {
    super.initState();
    _scheduleAutoRefresh();
  }

  @override
  void dispose() {
    _profileRefreshTimer?.cancel();
    super.dispose();
  }

  void _scheduleAutoRefresh() {
    _profileRefreshTimer?.cancel();
    _profileRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (!mounted) return;
      _refreshDriverData(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = context.strings;
    _drainDriverRealtimeToasts(state);
    final user = state.currentUser;
    final stats = state.driverStats;
    final pendingOrders = state.driverAvailableOrders;
    final activeOrders = state.driverActiveOrders;
    final loading = state.isDriverContextLoading;
    final totalToday = stats?.dailyRevenue ?? 0;
    final todayCount = stats?.dailyOrders ?? 0;
    final totalMonth = stats?.monthlyRevenue ?? 0;
    final monthCount = stats?.monthlyOrders ?? 0;
    final balance = stats?.currentBalance ?? user.balance;

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
        actions: [
          IconButton(
            tooltip: strings.tr('refresh'),
            onPressed: _isProfileRefreshing ? null : () => _refreshDriverData(),
            icon: SizedBox.square(
              dimension: 24,
              child: _isProfileRefreshing
                  ? const Padding(
                      padding: EdgeInsets.all(2),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
            ],
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
                            symbol: 'so\'m ',
                            decimalDigits: 0,
                          ).format(balance),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
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
                              .replaceFirst('{count}', todayCount.toString()),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          NumberFormat.currency(
                            symbol: 'so\'m ',
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
                              .replaceFirst('{count}', monthCount.toString()),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          NumberFormat.currency(
                            symbol: 'so\'m ',
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
                        child: _PendingOrderTile(
                          key: ValueKey(order.id),
                          order: order,
                        ),
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
                        child: _ActiveOrderTile(
                          key: ValueKey(order.id),
                          order: order,
                        ),
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

  Future<void> _refreshDriverData({bool silent = false}) async {
    if (_isProfileRefreshing) return;
    if (silent) {
      _isProfileRefreshing = true;
    } else {
      setState(() => _isProfileRefreshing = true);
    }
    final state = context.read<AppState>();
    try {
      await Future.wait([
        state.refreshProfile(),
        state.refreshDriverStatus(loadDashboard: true),
      ]);
    } on ApiException catch (error) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (!silent && mounted) {
        final strings = context.strings;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.tr('unexpectedError'))));
      }
    } finally {
      if (silent) {
        _isProfileRefreshing = false;
      } else if (mounted) {
        setState(() => _isProfileRefreshing = false);
      } else {
        _isProfileRefreshing = false;
      }
    }
  }

  void _showHistory(BuildContext context) {
    final strings = context.strings;
    final state = context.read<AppState>();
    final completed = state.driverCompletedOrders;

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
                if (completed.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text(strings.tr('noHistory'))),
                  )
                else
                  ...completed.map(
                    (order) => ListTile(
                      leading: Icon(
                        order.isTaxi
                            ? Icons.local_taxi_rounded
                            : Icons.inventory_2_rounded,
                      ),
                      title: Text(
                        '${order.fromDistrict} → ${order.toDistrict}',
                      ),
                      subtitle: order.priceAvailable
                          ? Text(
                              NumberFormat.currency(
                                symbol: 'so\'m ',
                                decimalDigits: 0,
                              ).format(order.price),
                            )
                          : null,
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
    final items = state.driverAvailableOrders
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
                      subtitle: order.priceAvailable
                          ? Text(
                              NumberFormat.currency(
                                symbol: 'so\'m ',
                                decimalDigits: 0,
                              ).format(order.price),
                            )
                          : null,
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
    final items = state.driverActiveOrders;

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
                      subtitle: order.priceAvailable
                          ? Text(
                              NumberFormat.currency(
                                symbol: 'so\'m ',
                                decimalDigits: 0,
                              ).format(order.price),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _drainDriverRealtimeToasts(AppState state) {
    final pending = <({String title, String message})>[];
    while (true) {
      final toast = state.takeNextDriverRealtimeMessage();
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

class _PendingOrderTile extends StatefulWidget {
  const _PendingOrderTile({super.key, required this.order});

  final AppOrder order;

  @override
  State<_PendingOrderTile> createState() => _PendingOrderTileState();
}

class _PendingOrderTileState extends State<_PendingOrderTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: _kDriverAcceptWindow,
    );
    _restartCountdown();
  }

  @override
  void didUpdateWidget(covariant _PendingOrderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.createdAt != widget.order.createdAt) {
      _restartCountdown();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final order = widget.order;
    final startTimeLabel = order.startTime.format(context);
    final endTimeLabel = order.endTime.format(context);
    final timeLabel = startTimeLabel == endTimeLabel
        ? startTimeLabel
        : '$startTimeLabel - $endTimeLabel';
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                avatar: Icon(
                  order.isTaxi
                      ? Icons.local_taxi_rounded
                      : Icons.inventory_2_rounded,
                ),
                label: Text(
                  order.isTaxi
                      ? strings.tr('taxiOrder')
                      : strings.tr('deliveryOrder'),
                ),
              ),
              const Spacer(),
              Text(order.id),
            ],
          ),
          const SizedBox(height: 12),
          Text('${order.fromDistrict} → ${order.toDistrict}'),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final totalSeconds = controller.duration?.inSeconds ?? 0;
              final remainingSeconds = ((totalSeconds) * (1 - controller.value))
                  .round();
              final remaining = Duration(seconds: remainingSeconds);
              final minutes = remaining.inMinutes.toString().padLeft(2, '0');
              final seconds = (remaining.inSeconds % 60).toString().padLeft(
                2,
                '0',
              );
              final expired = controller.value >= 0.999;
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
                  const SizedBox(height: 12),
                  GradientButton(
                    onPressed: _processing || expired
                        ? null
                        : () => _acceptOrder(context),
                    label: expired
                        ? strings.tr('orderExpired')
                        : strings.tr('acceptOrder'),
                    icon: expired
                        ? Icons.lock_clock_rounded
                        : Icons.check_circle_rounded,
                    loading: _processing,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _restartCountdown() {
    controller.stop();
    final createdAt = widget.order.createdAt;
    var elapsed = createdAt == null
        ? Duration.zero
        : DateTime.now().difference(createdAt);
    if (elapsed.isNegative) {
      elapsed = Duration.zero;
    }
    final totalMs = _kDriverAcceptWindow.inMilliseconds;
    final ratio = totalMs == 0 ? 1.0 : elapsed.inMilliseconds / totalMs;
    final initialValue = ratio.clamp(0.0, 1.0).toDouble();
    controller.value = initialValue;
    if (initialValue < 1.0) {
      controller.forward(from: initialValue);
    }
  }

  Future<void> _acceptOrder(BuildContext context) async {
    final strings = context.strings;
    setState(() => _processing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppState>().acceptDriverOrder(widget.order);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(strings.tr('orderAccepted'))),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(strings.tr('unexpectedError'))),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }
}

class _ActiveOrderTile extends StatefulWidget {
  const _ActiveOrderTile({super.key, required this.order});

  final AppOrder order;

  @override
  State<_ActiveOrderTile> createState() => _ActiveOrderTileState();
}

class _ActiveOrderTileState extends State<_ActiveOrderTile> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final order = widget.order;
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
          const SizedBox(height: 12),
          GradientButton(
            onPressed: _processing ? null : () => _completeOrder(context),
            label: strings.tr('completeOrder'),
            icon: Icons.done_all_rounded,
            loading: _processing,
          ),
        ],
      ),
    );
  }

  Future<void> _completeOrder(BuildContext context) async {
    final strings = context.strings;
    setState(() => _processing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppState>().completeDriverOrder(widget.order);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(strings.tr('orderCompleted'))),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(strings.tr('unexpectedError'))),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }
}
