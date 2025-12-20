import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../localization/app_localizations.dart';
import '../../localization/localization_ext.dart';
import '../../models/order.dart';
import '../../state/app_state.dart';
import '../../widgets/glass_card.dart';

class DriverOrderHistoryPage extends StatefulWidget {
  const DriverOrderHistoryPage({super.key});

  @override
  State<DriverOrderHistoryPage> createState() => _DriverOrderHistoryPageState();
}

class _DriverOrderHistoryPageState extends State<DriverOrderHistoryPage> {
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  Future<void> _loadInitial() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await context.read<AppState>().reloadDriverCompletedOrders();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final state = context.watch<AppState>();
    final orders = state.driverCompletedOrders.reversed.toList();
    final isLoading = state.isLoadingMoreDriverCompleted;
    final hasMore = state.driverCompletedHasMore;

    return Scaffold(
      appBar: AppBar(title: Text(strings.tr('orderHistory'))),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().reloadDriverCompletedOrders(),
        child: _HistoryList(
          orders: orders,
          isLoading: isLoading,
          hasMore: hasMore,
          onLoadMore: () =>
              context.read<AppState>().loadMoreDriverCompletedOrders(),
          onOpenDetails: (order) => _openDetails(context, order),
        ),
      ),
    );
  }

  Future<void> _openDetails(BuildContext context, AppOrder order) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
            top: AppSpacing.lg,
          ),
          child: _HistoryOrderDetailSheet(order: order),
        );
      },
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.orders,
    required this.isLoading,
    required this.hasMore,
    required this.onLoadMore,
    required this.onOpenDetails,
  });

  final List<AppOrder> orders;
  final bool isLoading;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final ValueChanged<AppOrder> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    if (orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      strings.tr('noHistory'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    final itemCount = orders.length + ((hasMore || isLoading) ? 1 : 0);
    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index >= orders.length) {
          if (isLoading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!hasMore) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Center(
              child: ElevatedButton(
                onPressed: onLoadMore,
                child: Text(strings.tr('more')),
              ),
            ),
          );
        }
        final order = orders[index];
        return _HistoryOrderCard(
          order: order,
          onTap: () => onOpenDetails(order),
        );
      },
    );
  }
}

class _HistoryOrderCard extends StatelessWidget {
  const _HistoryOrderCard({required this.order, required this.onTap});

  final AppOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final passengersLabel = strings
        .tr('passengersCount')
        .replaceFirst('{count}', order.passengers.toString());
    final genderLabel =
        _genderLabel(strings, order.clientGender, passengers: order.passengers);
    final priceLabel = order.priceAvailable
        ? NumberFormat.currency(
            symbol: 'so\'m ',
            decimalDigits: 0,
          ).format(order.price)
        : strings.tr('priceUnspecified');
    final dateLabel = DateFormat('dd MMM, yyyy').format(order.date);
    final timeLabel = _formatTimeRange(order);

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
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
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.pillRadius,
                  color: theme.colorScheme.primary.withOpacity(0.08),
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
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_formatLocation(order.fromRegion, order.fromDistrict)} → ${_formatLocation(order.toRegion, order.toDistrict)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MetaPill(icon: Icons.calendar_month_rounded, label: dateLabel),
              if (timeLabel != null)
                _MetaPill(icon: Icons.schedule_rounded, label: timeLabel),
              _MetaPill(icon: Icons.group_rounded, label: passengersLabel),
              _MetaPill(icon: Icons.wc_rounded, label: genderLabel),
              _MetaPill(icon: Icons.payments_rounded, label: priceLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryOrderDetailSheet extends StatelessWidget {
  const _HistoryOrderDetailSheet({required this.order});

  final AppOrder order;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final priceLabel = order.priceAvailable
        ? NumberFormat.currency(
            symbol: 'so\'m ',
            decimalDigits: 0,
          ).format(order.price)
        : strings.tr('priceUnspecified');
    final passengersLabel = strings
        .tr('passengersCount')
        .replaceFirst('{count}', order.passengers.toString());
    final genderLabel =
        _genderLabel(strings, order.clientGender, passengers: order.passengers);
    final dateLabel = DateFormat.yMMMMd().format(order.date);
    final timeLabel = _formatTimeRange(order);
    final note = order.note?.trim();
    final customerName = order.customerName?.trim();
    final customerPhone = order.customerPhone?.trim();

    return SafeArea(
      child: SingleChildScrollView(
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${_formatLocation(order.fromRegion, order.fromDistrict)} → ${_formatLocation(order.toRegion, order.toDistrict)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Chip(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
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
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '#${order.id}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  icon: Icons.map_rounded,
                  label: strings.tr('fromLocation'),
                  value: _formatLocation(order.fromRegion, order.fromDistrict),
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  icon: Icons.flag_rounded,
                  label: strings.tr('toLocation'),
                  value: _formatLocation(order.toRegion, order.toDistrict),
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: strings.tr('date'),
                  value: timeLabel == null
                      ? dateLabel
                      : '$dateLabel • $timeLabel',
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  icon: Icons.people_alt_rounded,
                  label: strings.tr('passengers'),
                  value: passengersLabel,
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  icon: Icons.wc_rounded,
                  label: strings.tr('passengerGender'),
                  value: genderLabel,
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  icon: Icons.attach_money_rounded,
                  label: strings.tr('price'),
                  value: priceLabel,
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  icon: Icons.note_alt_rounded,
                  label: strings.tr('note'),
                  value: (note == null || note.isEmpty)
                      ? strings.tr('noNote')
                      : note,
                ),
                if ((customerName != null && customerName.isNotEmpty) ||
                    (customerPhone != null && customerPhone.isNotEmpty)) ...[
                  const SizedBox(height: AppSpacing.md),
                  _DetailRow(
                    icon: Icons.person_rounded,
                    label: strings.tr('callPassenger'),
                    value: [
                      if (customerName != null && customerName.isNotEmpty)
                        customerName,
                      if (customerPhone != null && customerPhone.isNotEmpty)
                        customerPhone,
                    ].join(' • '),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.pillRadius,
                      color: theme.colorScheme.primary.withOpacity(0.08),
                    ),
                    child: Text(
                      strings.tr('status_${order.status.name}'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadii.pillRadius,
        color: theme.colorScheme.primary.withOpacity(0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withOpacity(0.1),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.82,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String? _formatTimeRange(AppOrder order) {
  final start = order.startTime;
  final end = order.endTime;
  final hasExplicitTime =
      !(start.hour == 0 && start.minute == 0 && end == start);
  if (!hasExplicitTime) return null;
  final startLabel = _formatTimeOfDay(start);
  final endLabel = _formatTimeOfDay(end);
  return startLabel == endLabel ? startLabel : '$startLabel - $endLabel';
}

String _formatLocation(String region, String district) {
  final regionLabel = region.trim();
  final districtLabel = district.trim();
  if (districtLabel.isEmpty ||
      districtLabel.toLowerCase() == regionLabel.toLowerCase()) {
    return regionLabel;
  }
  return '$regionLabel, $districtLabel';
}

String _formatTimeOfDay(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _genderLabel(
  AppLocalizations strings,
  String? raw, {
  required int passengers,
}) {
  final normalized = raw?.toLowerCase().trim();
  switch (normalized) {
    case 'male':
      return strings.tr('genderMale');
    case 'female':
      return strings.tr('genderFemale');
    case 'both':
      return strings.tr('genderBoth');
    default:
      return strings.tr('genderBoth');
  }
}
