import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/auth_api.dart';
import '../../localization/localization_ext.dart';
import '../../models/order.dart';
import '../../state/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';

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
    final pendingOrders = state.driverAvailableOrders.where((order) {
      final viewers = state.driverOrderViewerCount(order.id);
      final holdActive = state.isDriverOrderPreviewActive(order.id);
      return viewers == 0 || holdActive;
    }).toList();
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
    final items = state.driverAvailableOrders.where((order) {
      if (order.type != type) return false;
      final viewers = state.driverOrderViewerCount(order.id);
      final holdActive = state.isDriverOrderPreviewActive(order.id);
      return viewers == 0 || holdActive;
    }).toList();

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

class _PendingOrderTile extends StatelessWidget {
  const _PendingOrderTile({super.key, required this.order});

  final AppOrder order;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final startTimeLabel = order.startTime.format(context);
    final endTimeLabel = order.endTime.format(context);
    final timeLabel = startTimeLabel == endTimeLabel
        ? startTimeLabel
        : '$startTimeLabel - $endTimeLabel';
    final viewerCount = state.driverOrderViewerCount(order.id);
    final expiresAt = state.driverOrderPreviewExpiresAt(order.id);
    final holdActive = state.isDriverOrderPreviewActive(order.id);
    final String? holdLabel = holdActive && expiresAt != null
        ? DateFormat.Hm().format(expiresAt)
        : null;
    final passengersLabel = strings
        .tr('passengersCount')
        .replaceFirst('{count}', order.passengers.toString());
    final priceLabel = order.priceAvailable
        ? NumberFormat.currency(
            symbol: 'so\'m ',
            decimalDigits: 0,
          ).format(order.price)
        : strings.tr('priceUnspecified');

    return GlassCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showDetails(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                Text(
                  '${order.fromDistrict} → ${order.toDistrict}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(timeLabel),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.group_rounded,
                      label: passengersLabel,
                    ),
                    _InfoChip(icon: Icons.payments_rounded, label: priceLabel),
                    if (holdLabel != null)
                      _InfoChip(
                        icon: Icons.lock_clock_rounded,
                        label: strings
                            .tr('reservedUntil')
                            .replaceFirst('{time}', holdLabel),
                      ),
                    if (viewerCount > 0)
                      _InfoChip(
                        icon: Icons.visibility_rounded,
                        label: strings
                            .tr('driversViewingCount')
                            .replaceFirst('{count}', '$viewerCount'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showDetails(context),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(strings.tr('viewOrderDetails')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final padding = MediaQuery.of(context).padding;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, padding.bottom + 24),
          child: _DriverOrderDetailSheet(order: order),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _ActiveOrderTile extends StatefulWidget {
  const _ActiveOrderTile({super.key, required this.order});

  final AppOrder order;

  @override
  State<_ActiveOrderTile> createState() => _ActiveOrderTileState();
}

class _ActiveOrderTileState extends State<_ActiveOrderTile> {
  bool _confirming = false;
  bool _completing = false;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final order = widget.order;
    final confirmed = order.isConfirmed;
    final confirmationInfo = confirmed
        ? strings.tr('orderConfirmed')
        : strings.tr('orderConfirmRequired');
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
          Row(
            children: [
              Icon(
                confirmed ? Icons.verified_rounded : Icons.info_outline_rounded,
                color: confirmed ? const Color(0xFF10B981) : Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  confirmationInfo,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: confirmed ? const Color(0xFF10B981) : Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!confirmed) ...[
            GradientButton(
              onPressed: _confirming ? null : () => _confirmOrder(context),
              label: strings.tr('confirmOrder'),
              icon: Icons.verified_user_rounded,
              loading: _confirming,
            ),
            const SizedBox(height: 8),
          ],
          GradientButton(
            onPressed: _completing || !confirmed
                ? null
                : () => _completeOrder(context),
            label: strings.tr('completeOrder'),
            icon: Icons.done_all_rounded,
            loading: _completing,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmOrder(BuildContext context) async {
    final strings = context.strings;
    setState(() => _confirming = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppState>().confirmDriverOrder(widget.order);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(strings.tr('orderConfirmed'))),
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
        setState(() => _confirming = false);
      }
    }
  }

  Future<void> _completeOrder(BuildContext context) async {
    final strings = context.strings;
    setState(() => _completing = true);
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
        setState(() => _completing = false);
      }
    }
  }
}

class _DriverOrderDetailSheet extends StatefulWidget {
  const _DriverOrderDetailSheet({required this.order});

  final AppOrder order;

  @override
  State<_DriverOrderDetailSheet> createState() =>
      _DriverOrderDetailSheetState();
}

class _DriverOrderDetailSheetState extends State<_DriverOrderDetailSheet> {
  Timer? _timer;
  Duration? _remaining;
  bool _expired = false;
  bool _accepting = false;
  bool _releasing = false;
  bool _stopSent = false;
  bool _holdReleased = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    state.beginDriverOrderPreview(widget.order);
    _remaining = _remainingFrom(
      state.driverOrderPreviewExpiresAt(widget.order.id),
    );
    _expired = _remaining == Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_stopSent) {
      context.read<AppState>().endDriverOrderPreview(widget.order);
      _stopSent = true;
    }
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final state = context.read<AppState>();
    final remaining = _remainingFrom(
      state.driverOrderPreviewExpiresAt(widget.order.id),
    );
    final expired = remaining <= Duration.zero;
    if (expired && !_holdReleased) {
      _sendStopViewing(releaseHold: true, reason: 'expired');
      _holdReleased = true;
    }
    setState(() {
      _remaining = remaining;
      _expired = expired;
    });
    if (expired) {
      _timer?.cancel();
    }
  }

  Duration _remainingFrom(DateTime? expiresAt) {
    if (expiresAt == null) return Duration.zero;
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _sendStopViewing({bool releaseHold = false, String? reason}) {
    context.read<AppState>().endDriverOrderPreview(
      widget.order,
      releaseHold: releaseHold,
      reason: reason,
    );
    _stopSent = true;
    if (releaseHold) {
      _holdReleased = true;
    }
  }

  Future<void> _acceptOrder(BuildContext context) async {
    if (_accepting || _expired) return;
    final strings = context.strings;
    setState(() => _accepting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final state = context.read<AppState>();
      await state.acceptDriverOrder(widget.order);
      if (!mounted) return;
      _stopSent = true;
      _holdReleased = true;
      messenger.showSnackBar(
        SnackBar(content: Text(strings.tr('orderAccepted'))),
      );
      navigator.pop();
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
        setState(() => _accepting = false);
      }
    }
  }

  Future<void> _releaseOrder(BuildContext context) async {
    if (_releasing || _holdReleased) return;
    setState(() => _releasing = true);
    _sendStopViewing(releaseHold: true, reason: 'driver_cancelled');
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(strings.tr('orderReleaseSuccess'))),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _callPassenger(BuildContext context) async {
    if (_expired || _holdReleased) return;
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    final phone = widget.order.customerPhone?.trim() ?? '';
    if (phone.isEmpty) return;
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: normalized);
    try {
      final success = await launchUrl(uri);
      if (!success) {
        messenger.showSnackBar(
          SnackBar(content: Text(strings.tr('unexpectedError'))),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.tr('unexpectedError'))),
      );
    }
  }

  String _formatRemaining() {
    final remaining = _remaining ?? Duration.zero;
    final minutes = remaining.inMinutes
        .remainder(60)
        .abs()
        .toString()
        .padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).abs().toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final viewerCount = state.driverOrderViewerCount(widget.order.id);
    final expiresAt = state.driverOrderPreviewExpiresAt(widget.order.id);
    final holdWindow = state.driverOrderPreviewWindow;
    final totalSeconds = holdWindow.inSeconds;
    final rawSeconds = (_remaining ?? Duration.zero).inSeconds;
    final clampedSeconds = totalSeconds == 0
        ? 0
        : rawSeconds.clamp(0, totalSeconds);
    final progress = totalSeconds == 0
        ? 1.0
        : 1 - (clampedSeconds.toDouble() / totalSeconds.toDouble());
    final startLabel = widget.order.startTime.format(context);
    final endLabel = widget.order.endTime.format(context);
    final timeLabel = startLabel == endLabel
        ? startLabel
        : '$startLabel - $endLabel';
    final hasExplicitTime =
        !(widget.order.startTime.hour == 0 &&
            widget.order.startTime.minute == 0 &&
            widget.order.endTime == widget.order.startTime);
    final String? scheduleLabel = hasExplicitTime ? timeLabel : null;
    final priceLabel = widget.order.priceAvailable
        ? NumberFormat.currency(
            symbol: 'so\'m ',
            decimalDigits: 0,
          ).format(widget.order.price)
        : strings.tr('priceUnspecified');
    final passengersLabel = strings
        .tr('passengersCount')
        .replaceFirst('{count}', widget.order.passengers.toString());
    final reservedLabel = !_expired && expiresAt != null
        ? strings
              .tr('reservedUntil')
              .replaceFirst('{time}', DateFormat.Hm().format(expiresAt))
        : strings.tr('orderHoldExpiredInfo');
    final note = widget.order.note?.trim();
    final phone = widget.order.customerPhone?.trim() ?? '';
    final hasPhone = phone.isNotEmpty;
    final canCall = hasPhone && !_expired && !_holdReleased;

    return SafeArea(
      child: SingleChildScrollView(
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.order.isTaxi
                            ? strings.tr('taxiOrder')
                            : strings.tr('deliveryOrder'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.order.fromDistrict} → ${widget.order.toDistrict}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (scheduleLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(scheduleLabel, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 12),
                Text(
                  strings.tr('orderHoldMessage'),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  reservedLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (viewerCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    strings
                        .tr('driversViewingCount')
                        .replaceFirst('{count}', '$viewerCount'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                _buildInfoRow(
                  context,
                  icon: Icons.calendar_today_rounded,
                  label: strings.tr('date'),
                  value: DateFormat.yMMMMd().format(widget.order.date),
                ),
                if (scheduleLabel != null)
                  _buildInfoRow(
                    context,
                    icon: Icons.schedule_rounded,
                    label: strings.tr('scheduledTime'),
                    value: scheduleLabel,
                  ),
                _buildInfoRow(
                  context,
                  icon: Icons.group_rounded,
                  label: strings.tr('passengers'),
                  value: passengersLabel,
                ),
                _buildInfoRow(
                  context,
                  icon: Icons.payments_rounded,
                  label: strings.tr('price'),
                  value: priceLabel,
                ),
                _buildInfoRow(
                  context,
                  icon: Icons.note_alt_rounded,
                  label: strings.tr('note'),
                  value: (note == null || note.isEmpty)
                      ? strings.tr('noNote')
                      : note,
                ),
                const SizedBox(height: 16),
                Text(
                  strings.tr('callPassenger'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.tr('callPassengerHint'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.phone_in_talk_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: hasPhone
                                ? SelectableText(
                                    phone,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  )
                                : Text(
                                    strings.tr('callPassengerUnavailable'),
                                    style: theme.textTheme.bodyLarge,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: canCall
                            ? () => _callPassenger(context)
                            : null,
                        icon: const Icon(Icons.call_rounded),
                        label: Text(strings.tr('callPassenger')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
                const SizedBox(height: 6),
                Text(
                  strings
                      .tr('acceptTimer')
                      .replaceFirst('{time}', _formatRemaining()),
                ),
                if (_expired) ...[
                  const SizedBox(height: 6),
                  Text(
                    strings.tr('orderHoldExpiredInfo'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                GradientButton(
                  onPressed: _expired || _holdReleased
                      ? null
                      : () => _acceptOrder(context),
                  label: strings.tr('acceptOrder'),
                  icon: Icons.check_circle_rounded,
                  loading: _accepting,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _releasing || _holdReleased
                      ? null
                      : () => _releaseOrder(context),
                  icon: const Icon(Icons.cancel_schedule_send_rounded),
                  label: Text(strings.tr('releaseOrder')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(strings.tr('close')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
