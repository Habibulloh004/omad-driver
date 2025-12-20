import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/auth_api.dart';
import '../../localization/localization_ext.dart';
import '../../models/order.dart';
import '../../state/app_state.dart';
import 'driver_order_history_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../core/design_tokens.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  static const Duration _autoRefreshInterval = Duration(minutes: 10);
  Timer? _profileRefreshTimer;
  bool _isProfileRefreshing = false;
  bool _isPagingOrders = false;

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final onTint = colorScheme.onPrimary;
    final onTintMuted = onTint.withValues(alpha: 0.78);
    final balanceGradient = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFA855F7), // Violet
    ];
    final statGradient = [
      const Color(0xFF10B981), // Emerald
      const Color(0xFF059669), // Green
    ];
    final statAltGradient = [
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
    ];
    _drainDriverRealtimeToasts(state);
    final user = state.currentUser;
    final stats = state.driverStats;
    final activeOrders = state.driverActiveOrders
        .where((order) => order.status == OrderStatus.active)
        .toList();
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
            _tintedCard(
              gradient: balanceGradient,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: onTint.withValues(alpha: isDark ? 0.12 : 0.1),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 28,
                      color: onTint,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.tr('currentBalance'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: onTintMuted,
                          ),
                        ),
                        Text(
                          NumberFormat.currency(
                            symbol: 'so\'m ',
                            decimalDigits: 0,
                          ).format(balance),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onTint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _tintedCard(
                    gradient: statGradient,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.tr('todayStats'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: onTintMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings
                              .tr('ordersCount')
                              .replaceFirst('{count}', todayCount.toString()),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onTint,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          NumberFormat.currency(
                            symbol: 'so\'m ',
                            decimalDigits: 0,
                          ).format(totalToday),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: onTint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tintedCard(
                    gradient: statAltGradient,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.tr('monthStats'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: onTintMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings
                              .tr('ordersCount')
                              .replaceFirst('{count}', monthCount.toString()),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onTint,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          NumberFormat.currency(
                            symbol: 'so\'m ',
                            decimalDigits: 0,
                          ).format(totalMonth),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: onTint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.move_to_inbox_rounded),
                    label: Text(strings.tr('incomingOrders')),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DriverIncomingOrdersPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.history_rounded),
                    label: Text(strings.tr('orderHistory')),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DriverOrderHistoryPage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              strings.tr('activeOrders'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (state.driverActiveOrders.length >= 20 ||
                state.driverActiveHasMore)
              Center(
                child: ElevatedButton(
                  onPressed: _loadMoreDriverOrders,
                  child: Text(strings.tr('more')),
                ),
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
            if (state.isLoadingMoreDriverActive)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
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

  Widget _tintedCard({
    required List<Color> gradient,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(14),
  }) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadii.cardRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          border: Border.all(
            color: gradient.first.withValues(alpha: 0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -32,
              top: -24,
              child: _tintBlob(
                color: gradient.last.withValues(alpha: 0.22),
                size: 140,
              ),
            ),
            Positioned(
              left: -18,
              bottom: -18,
              child: _tintBlob(
                color: gradient.first.withValues(alpha: 0.2),
                size: 120,
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }

  Widget _tintBlob({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: size * 0.24,
            spreadRadius: size * 0.05,
          ),
        ],
      ),
    );
  }

  Future<void> _loadMoreDriverOrders() async {
    if (_isPagingOrders) return;
    final state = context.read<AppState>();
    final loading = state.isLoadingMoreDriverActive;
    final hasMore = state.driverActiveHasMore;
    if (!hasMore || loading) return;
    _isPagingOrders = true;
    try {
      await state.loadMoreDriverActiveOrders();
    } finally {
      _isPagingOrders = false;
    }
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

class DriverIncomingOrdersPage extends StatefulWidget {
  const DriverIncomingOrdersPage({super.key});

  @override
  State<DriverIncomingOrdersPage> createState() =>
      _DriverIncomingOrdersPageState();
}

class _DriverIncomingOrdersPageState extends State<DriverIncomingOrdersPage> {
  bool _bootstrapped = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await _refreshOrders();
  }

  Future<void> _refreshOrders() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await context.read<AppState>().refreshDriverDashboard(force: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      final strings = context.strings;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.tr('unexpectedError'))));
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _loadMoreOrders() async {
    final state = context.read<AppState>();
    if (state.isLoadingMoreDriverAvailable || !state.driverAvailableHasMore) {
      return;
    }
    await state.loadMoreDriverAvailableOrders();
  }

  Future<void> _onOrderTypeFilterChanged(OrderType? value) async {
    final state = context.read<AppState>();
    await _applyFilters(
      orderType: value,
      fromRegionId: state.driverIncomingFromRegionFilter,
      toRegionId: state.driverIncomingToRegionFilter,
    );
  }

  Future<void> _onFromRegionChanged(int? regionId) async {
    final state = context.read<AppState>();
    var toRegionId = state.driverIncomingToRegionFilter;
    if (regionId != null && toRegionId == regionId) {
      toRegionId = null;
    }
    await _applyFilters(
      orderType: state.driverIncomingTypeFilter,
      fromRegionId: regionId,
      toRegionId: toRegionId,
    );
  }

  Future<void> _onToRegionChanged(int? regionId) async {
    final state = context.read<AppState>();
    var fromRegionId = state.driverIncomingFromRegionFilter;
    if (regionId != null && fromRegionId == regionId) {
      fromRegionId = null;
    }
    await _applyFilters(
      orderType: state.driverIncomingTypeFilter,
      fromRegionId: fromRegionId,
      toRegionId: regionId,
    );
  }

  Future<void> _applyFilters({
    OrderType? orderType,
    int? fromRegionId,
    int? toRegionId,
  }) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await context.read<AppState>().updateDriverIncomingFilters(
        orderType: orderType,
        fromRegionId: fromRegionId,
        toRegionId: toRegionId,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      final strings = context.strings;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.tr('unexpectedError'))));
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final pendingOrders = state.driverAvailableOrders.where((order) {
      final viewers = state.driverOrderViewerCount(order.id);
      final holdActive = state.isDriverOrderPreviewActive(order.id);
      return viewers == 0 || holdActive;
    }).toList();
    final orderTypeFilter = state.driverIncomingTypeFilter;
    final fromRegionFilter = state.driverIncomingFromRegionFilter;
    final toRegionFilter = state.driverIncomingToRegionFilter;
    final regionOptions = state.regionOptions;
    final fromRegionOptions = regionOptions
        .where((region) => region.id != toRegionFilter)
        .toList(growable: false);
    final toRegionOptions = regionOptions
        .where((region) => region.id != fromRegionFilter)
        .toList(growable: false);
    final hasMore = state.driverAvailableHasMore;
    final isLoadingMore = state.isLoadingMoreDriverAvailable;
    final showLoadingBar = state.isDriverContextLoading || _refreshing;

    final children = <Widget>[
      if (showLoadingBar)
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: LinearProgressIndicator(),
        ),
      GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.tr('filters'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: fromRegionFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: strings.tr('fromRegionFilter'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(strings.tr('allRegions')),
                      ),
                      ...fromRegionOptions.map(
                        (region) => DropdownMenuItem<int?>(
                          value: region.id,
                          child: Text(state.regionLabel(region)),
                        ),
                      ),
                    ],
                    onChanged: (value) => _onFromRegionChanged(value),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: toRegionFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: strings.tr('toRegionFilter'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(strings.tr('allRegions')),
                      ),
                      ...toRegionOptions.map(
                        (region) => DropdownMenuItem<int?>(
                          value: region.id,
                          child: Text(state.regionLabel(region)),
                        ),
                      ),
                    ],
                    onChanged: (value) => _onToRegionChanged(value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<OrderType?>(
              value: orderTypeFilter,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: strings.tr('orderTypeFilter'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                DropdownMenuItem<OrderType?>(
                  value: null,
                  child: Text(strings.tr('any')),
                ),
                DropdownMenuItem<OrderType?>(
                  value: OrderType.taxi,
                  child: Text(strings.tr('taxiOrder')),
                ),
                DropdownMenuItem<OrderType?>(
                  value: OrderType.delivery,
                  child: Text(strings.tr('deliveryOrder')),
                ),
              ],
              onChanged: (value) => _onOrderTypeFilterChanged(value),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
    ];

    if (pendingOrders.isEmpty) {
      children.add(
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: Text(strings.tr('noPendingOrders'))),
          ),
        ),
      );
    } else {
      for (var i = 0; i < pendingOrders.length; i++) {
        children.add(
          _PendingOrderTile(
            key: ValueKey(pendingOrders[i].id),
            order: pendingOrders[i],
          ),
        );
        if (i != pendingOrders.length - 1) {
          children.add(const SizedBox(height: AppSpacing.sm));
        }
      }

      if (hasMore || isLoadingMore) {
        children.add(const SizedBox(height: AppSpacing.sm));
        children.add(
          Center(
            child: isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: CircularProgressIndicator(),
                  )
                : ElevatedButton(
                    onPressed: _loadMoreOrders,
                    child: Text(strings.tr('more')),
                  ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('incomingOrders')),
        actions: [
          IconButton(
            tooltip: strings.tr('refresh'),
            onPressed: _refreshing ? null : _refreshOrders,
            icon: SizedBox.square(
              dimension: 24,
              child: _refreshing
                  ? const Padding(
                      padding: EdgeInsets.all(2),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrders,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: children,
        ),
      ),
    );
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
    final viewerCount = state.driverOrderViewerCount(order.id);
    final canAccept = state.canDriverAcceptOrder(order);
    final disabled = !canAccept;
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
    final routeLabel = _formatOrderRoute(state, order);

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: GlassCard(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: disabled
                ? null
                : () => _showDetails(context, canAccept: canAccept),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          order.isTaxi
                              ? Icons.local_taxi_rounded
                              : Icons.inventory_2_rounded,
                          size: 18,
                        ),
                        label: Text(
                          order.isTaxi
                              ? strings.tr('taxiOrder')
                              : strings.tr('deliveryOrder'),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#${order.id}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    routeLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoChip(
                        icon: Icons.group_rounded,
                        label: passengersLabel,
                      ),
                      _InfoChip(
                        icon: Icons.payments_rounded,
                        label: priceLabel,
                      ),
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
                      if (!canAccept)
                        _InfoChip(
                          icon: Icons.lock_rounded,
                          label: strings.tr('currentBalance'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(
    BuildContext context, {
    required bool canAccept,
  }) async {
    if (!canAccept) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient balance to view this order'),
          ),
        );
      }
      return;
    }
    var orderToShow = order;
    try {
      final detailed = await context.read<AppState>().loadDriverOrderDetail(
        order,
      );
      if (detailed != null) {
        orderToShow = detailed;
      }
    } catch (_) {
      // Ignore detail fetch errors; fall back to current order data.
    }
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final padding = MediaQuery.of(context).padding;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, padding.bottom + 24),
          child: _DriverOrderDetailSheet(
            order: orderToShow,
            hasPrefetchedDetails: true,
            previewMode: true,
            canAccept: canAccept,
          ),
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Chip(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: primary.withOpacity(0.08)),
      backgroundColor: primary.withOpacity(0.06),
      avatar: Icon(icon, size: 16, color: primary),
      label: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
    final state = context.watch<AppState>();
    final order = widget.order;
    final confirmed = order.isConfirmed;
    final confirmationInfo = confirmed
        ? strings.tr('orderConfirmed')
        : strings.tr('orderConfirmRequired');
    final routeLabel = _formatOrderRoute(state, order);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  routeLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(order.id),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: confirmed
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F7F1),
                          borderRadius: BorderRadius.circular(AppRadii.button),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF10B981),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                confirmationInfo,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: const Color(0xFF059669),
                                      fontWeight: FontWeight.w700,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: strings.tr('viewOrderDetails'),
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(10),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                ),
                onPressed: () => _showDetails(context),
                icon: const Icon(Icons.remove_red_eye_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
      final state = context.read<AppState>();
      await state.completeDriverOrder(widget.order);
      unawaited(state.refreshDriverDashboard(force: true));
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

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final padding = MediaQuery.of(context).padding;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, padding.bottom + 24),
          child: _DriverOrderDetailSheet(
            order: widget.order,
            previewMode: false,
          ),
        );
      },
    );
  }
}

class _DriverOrderDetailSheet extends StatefulWidget {
  const _DriverOrderDetailSheet({
    required this.order,
    this.previewMode = true,
    this.hasPrefetchedDetails = false,
    this.canAccept = true,
  });

  final AppOrder order;
  final bool previewMode;
  final bool hasPrefetchedDetails;
  final bool canAccept;

  @override
  State<_DriverOrderDetailSheet> createState() =>
      _DriverOrderDetailSheetState();
}

class _DriverOrderDetailSheetState extends State<_DriverOrderDetailSheet> {
  late AppOrder _order;
  Timer? _timer;
  Future<void>? _previewFuture;
  Duration? _remaining;
  bool _expired = false;
  bool _accepting = false;
  bool _releasing = false;
  bool _stopSent = false;
  bool _holdReleased = false;
  late final bool _shouldFetchDetails;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _shouldFetchDetails =
        !widget.hasPrefetchedDetails || _needsDetails(widget.order);
    final previewEnabled = widget.previewMode && widget.canAccept;
    if (previewEnabled) {
      final state = context.read<AppState>();
      _previewFuture = state.beginDriverOrderPreview(widget.order);
      _remaining = _remainingFrom(
        state.driverOrderPreviewExpiresAt(widget.order.id),
      );
      _expired = _remaining == Duration.zero;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
    if (_shouldFetchDetails) {
      _loadDetails();
    }
  }

  @override
  void dispose() {
    if (widget.previewMode) {
      _timer?.cancel();
      if (!_stopSent) {
        context.read<AppState>().endDriverOrderPreview(_order);
        _stopSent = true;
      }
    }
    super.dispose();
  }

  void _tick() {
    if (!widget.previewMode || !widget.canAccept) return;
    if (!mounted) return;
    final state = context.read<AppState>();
    final remaining = _remainingFrom(
      state.driverOrderPreviewExpiresAt(_order.id),
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

  bool _needsDetails(AppOrder order) {
    final hasPickup =
        (order.pickupAddress?.trim().isNotEmpty ?? false) ||
        (order.pickupLatitude != null && order.pickupLongitude != null);
    final hasPhone = (order.customerPhone?.trim().isNotEmpty ?? false);
    return !(hasPickup && hasPhone);
  }

  Future<void> _loadDetails() async {
    final appState = context.read<AppState>();
    if (!_needsDetails(_order)) return;
    if (widget.previewMode && _previewFuture != null) {
      try {
        await _previewFuture;
      } catch (_) {
        // Ignore preview failures; we will still try to fetch details.
      }
    }
    final fetched = await appState.loadDriverOrderDetail(_order);
    if (fetched != null && mounted) {
      setState(() {
        _order = fetched;
      });
    }
  }

  void _sendStopViewing({bool releaseHold = false, String? reason}) {
    if (!widget.previewMode || !widget.canAccept) return;
    context.read<AppState>().endDriverOrderPreview(
      _order,
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
      await state.acceptDriverOrder(_order);
      unawaited(state.refreshDriverDashboard(force: true));
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
    final phone = _order.customerPhone?.trim();
    if (phone == null || phone.isEmpty) return;
    final sanitizedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (sanitizedPhone.isEmpty) return;

    final scheme = Platform.isIOS ? 'telprompt' : 'tel';
    final uri = Uri.parse('$scheme:$sanitizedPhone');
    bool launched = false;

    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }

    if (!context.mounted) return;
    if (launched) return;
    await _copyText(context, phone);
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(strings.tr('cannotMakeCall'))),
    );
  }

  Future<void> _copyText(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    final strings = context.strings;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.tr('copied'))));
  }

  Future<void> _openYandexMap(BuildContext context) async {
    final lat = _order.pickupLatitude;
    final lng = _order.pickupLongitude;
    final strings = context.strings;
    final fallbackLabel = _pickupLabel(_order);
    Uri? uri;
    if (lat != null && lng != null) {
      uri = Uri.parse(
        'https://yandex.com/maps/?ll=$lng,$lat&z=17&pt=$lng,$lat&l=map',
      );
    } else if (fallbackLabel != null && fallbackLabel.isNotEmpty) {
      uri = Uri.parse(
        'https://yandex.com/maps/?text=${Uri.encodeComponent(fallbackLabel)}',
      );
    }
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.tr('mapOpenFailed'))));
      return;
    }
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!context.mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.tr('mapOpenFailed'))));
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

  String? _pickupLabel(AppOrder order) {
    final address = order.pickupAddress?.trim();
    if (address != null && address.isNotEmpty) return address;
    final lat = order.pickupLatitude;
    final lng = order.pickupLongitude;
    if (lat != null && lng != null) {
      return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final order = _order;
    final previewActive = widget.previewMode && widget.canAccept;
    final viewerCount = previewActive
        ? state.driverOrderViewerCount(order.id)
        : 0;
    final expiresAt = previewActive
        ? state.driverOrderPreviewExpiresAt(order.id)
        : null;
    final holdWindow = previewActive
        ? state.driverOrderPreviewWindow
        : Duration.zero;
    final totalSeconds = holdWindow.inSeconds;
    final rawSeconds = (_remaining ?? Duration.zero).inSeconds;
    final clampedSeconds = totalSeconds == 0
        ? 0
        : rawSeconds.clamp(0, totalSeconds);
    final progress = totalSeconds == 0
        ? 1.0
        : 1 - (clampedSeconds.toDouble() / totalSeconds.toDouble());
    final startLabel = _formatTimeOfDay(order.startTime);
    final endLabel = _formatTimeOfDay(order.endTime);
    final timeLabel = startLabel == endLabel
        ? startLabel
        : '$startLabel - $endLabel';
    final hasExplicitTime =
        !(order.startTime.hour == 0 &&
            order.startTime.minute == 0 &&
            order.endTime == order.startTime);
    final String? scheduleLabel = hasExplicitTime ? timeLabel : null;
    final pickupLabel = _pickupLabel(order);
    final priceLabel = order.priceAvailable
        ? NumberFormat.currency(
            symbol: 'so\'m ',
            decimalDigits: 0,
          ).format(order.price)
        : strings.tr('priceUnspecified');
    final passengersLabel = strings
        .tr('passengersCount')
        .replaceFirst('{count}', order.passengers.toString());
    final reservedLabel = previewActive && !_expired && expiresAt != null
        ? strings
              .tr('reservedUntil')
              .replaceFirst('{time}', DateFormat.Hm().format(expiresAt))
        : null;
    final note = order.note?.trim();
    final phone = order.customerPhone?.trim() ?? '';
    final hasPhone = phone.isNotEmpty;
    final canCall =
        hasPhone && (!widget.previewMode || (!_expired && !_holdReleased));
    final routeLabel = _formatOrderRoute(state, order);

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
                        order.isTaxi
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
                  routeLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (scheduleLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(scheduleLabel, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 12),
                if (widget.previewMode) ...[
                  Text(
                    strings.tr('orderHoldMessage'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (reservedLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      reservedLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
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
                ] else
                  const SizedBox(height: 8),
                _buildInfoRow(
                  context,
                  icon: Icons.calendar_today_rounded,
                  label: strings.tr('date'),
                  value: DateFormat.yMMMMd().format(order.date),
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
                if (pickupLabel != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        context,
                        icon: Icons.place_rounded,
                        label: strings.tr('pickupAddress'),
                        value: pickupLabel,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.button,
                              ),
                            ),
                          ),
                          onPressed: () => _openYandexMap(context),
                          icon: const Icon(Icons.map_rounded),
                          label: Text(strings.tr('openInMap')),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
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
                if (widget.previewMode) ...[
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
                ],
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
    Widget? trailing,
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
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }
}

String _formatRegionDistrict(String region, String district) {
  final regionLabel = region.trim();
  final districtLabel = district.trim();
  if (districtLabel.isEmpty ||
      districtLabel.toLowerCase() == regionLabel.toLowerCase()) {
    return regionLabel;
  }
  return '$regionLabel, $districtLabel';
}

String _formatOrderRoute(AppState state, AppOrder order) {
  final fromDistrict = _resolveDistrictLabel(
    state,
    order.fromDistrict,
    order.fromDistrictId,
  );
  final toDistrict = _resolveDistrictLabel(
    state,
    order.toDistrict,
    order.toDistrictId,
  );
  final fromLabel = _formatRegionDistrict(order.fromRegion, fromDistrict);
  final toLabel = _formatRegionDistrict(order.toRegion, toDistrict);
  return '$fromLabel → $toLabel';
}

String _resolveDistrictLabel(AppState state, String district, int districtId) {
  final trimmed = district.trim();
  if (trimmed.isNotEmpty) return trimmed;
  if (districtId <= 0) return '';
  return state.districtLabelById(districtId);
}

String _formatTimeOfDay(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
