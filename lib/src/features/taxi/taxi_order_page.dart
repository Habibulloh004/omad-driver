import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../localization/localization_ext.dart';
import '../../state/app_state.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/gradient_button.dart';
import '../common/order_sent_page.dart';

class TaxiOrderPage extends StatefulWidget {
  const TaxiOrderPage({super.key});

  @override
  State<TaxiOrderPage> createState() => _TaxiOrderPageState();
}

class _TaxiOrderPageState extends State<TaxiOrderPage> {
  String? fromRegion;
  String? fromDistrict;
  String? toRegion;
  String? toDistrict;
  int passengers = 1;
  DateTime selectedDate = DateTime.now();
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
  final TextEditingController noteCtrl = TextEditingController();
  bool confirming = false;

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = context.strings;
    final regions = state.regions;
    final price = _calculatePrice(state);

    final ready =
        fromRegion != null &&
        fromDistrict != null &&
        toRegion != null &&
        toDistrict != null;

    return Scaffold(
      appBar: AppBar(title: Text(strings.tr('orderTaxi'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(label: strings.tr('pickupLocation')),
                  DropdownButtonFormField<String>(
                    value: fromRegion,
                    decoration: InputDecoration(
                      labelText: strings.tr('region'),
                    ),
                    items: regions.keys
                        .map(
                          (region) => DropdownMenuItem(
                            value: region,
                            child: Text(region),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        fromRegion = value;
                        fromDistrict = null;
                        if (toRegion == fromRegion) {
                          toRegion = null;
                          toDistrict = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: fromDistrict,
                    decoration: InputDecoration(
                      labelText: strings.tr('district'),
                    ),
                    items:
                        (fromRegion == null
                                ? const <String>[]
                                : regions[fromRegion]!)
                            .map(
                              (district) => DropdownMenuItem(
                                value: district,
                                child: Text(district),
                              ),
                            )
                            .toList(),
                    onChanged: fromRegion == null
                        ? null
                        : (value) => setState(() => fromDistrict = value),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle(label: strings.tr('dropLocation')),
                  DropdownButtonFormField<String>(
                    value: toRegion,
                    decoration: InputDecoration(
                      labelText: strings.tr('region'),
                    ),
                    items: regions.keys
                        .where((region) => region != fromRegion)
                        .map(
                          (region) => DropdownMenuItem(
                            value: region,
                            child: Text(region),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        toRegion = value;
                        toDistrict = null;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: toDistrict,
                    decoration: InputDecoration(
                      labelText: strings.tr('district'),
                    ),
                    items:
                        (toRegion == null
                                ? const <String>[]
                                : state.regions[toRegion]!)
                            .map(
                              (district) => DropdownMenuItem(
                                value: district,
                                child: Text(district),
                              ),
                            )
                            .toList(),
                    onChanged: toRegion == null
                        ? null
                        : (value) => setState(() => toDistrict = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(label: strings.tr('passengers')),
                  Wrap(
                    spacing: 10,
                    children: [1, 2, 3, 4].map((count) {
                      return ChoiceChip(
                        label: Text(
                          count == 4
                              ? strings.tr('fullCar')
                              : strings
                                    .tr('passengersCount')
                                    .replaceFirst('{count}', count.toString()),
                        ),
                        selected: passengers == count,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => passengers = count);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle(label: strings.tr('date')),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectDate,
                          icon: const Icon(Icons.calendar_today_rounded),
                          label: Text(
                            DateFormat('dd.MM.yyyy').format(selectedDate),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectTimeRange(isStart: true),
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text(startTime.format(context)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectTimeRange(isStart: false),
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text(endTime.format(context)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(label: strings.tr('optionalNote')),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: noteCtrl,
                    label: strings.tr('noteHint'),
                    maxLines: 3,
                    minLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.tr('estimatedPrice'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          price == 0
                              ? strings.tr('fillInfoForPrice')
                              : NumberFormat.currency(
                                  symbol: 'so\'m',
                                  decimalDigits: 0,
                                ).format(price),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  GradientButton(
                    onPressed: !ready || price == 0 || confirming
                        ? null
                        : () => _showSummary(context, price),
                    label: strings.tr('confirmOrder'),
                    icon: Icons.check_rounded,
                    loading: confirming,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _selectTimeRange({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? startTime : endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });
    }
  }

  double _calculatePrice(AppState state) {
    if (fromRegion == null || toRegion == null) {
      return 0;
    }
    return state.calculateTaxiPrice(
      fromRegion: fromRegion!,
      toRegion: toRegion!,
      passengers: passengers,
    );
  }

  Future<void> _showSummary(BuildContext context, double price) async {
    setState(() => confirming = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!context.mounted) return;
    final strings = context.strings;

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
                strings.tr('orderSummary'),
                style: Theme.of(
                  dialogContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              _SummaryRow(
                label: strings.tr('fromLocation'),
                value: '${fromRegion!}, ${fromDistrict!}',
              ),
              _SummaryRow(
                label: strings.tr('toLocation'),
                value: '${toRegion!}, ${toDistrict!}',
              ),
              _SummaryRow(
                label: strings.tr('passengers'),
                value: passengers == 4
                    ? strings.tr('fullCar')
                    : passengers.toString(),
              ),
              _SummaryRow(
                label: strings.tr('date'),
                value: DateFormat('dd.MM.yyyy').format(selectedDate),
              ),
              _SummaryRow(
                label: strings.tr('timeRange'),
                value:
                    '${startTime.format(context)} - ${endTime.format(context)}',
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(strings.tr('note')),
              Text(
                noteCtrl.text.isEmpty ? strings.tr('noNote') : noteCtrl.text,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                NumberFormat.currency(
                  symbol: 'so\'m',
                  decimalDigits: 0,
                ).format(price),
                style: Theme.of(dialogContext).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              GradientButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _sendOrder(price);
                },
                label: strings.tr('sendOrder'),
                icon: Icons.send_rounded,
              ),
            ],
          ),
        );
      },
    );

    if (!context.mounted) return;
    setState(() => confirming = false);
  }

  Future<void> _sendOrder(double price) async {
    final state = context.read<AppState>();
    final order = state.createTaxiOrder(
      fromRegion: fromRegion!,
      fromDistrict: fromDistrict!,
      toRegion: toRegion!,
      toDistrict: toDistrict!,
      passengers: passengers,
      date: selectedDate,
      start: startTime,
      end: endTime,
      note: noteCtrl.text,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => OrderSentPage(
          title: context.strings.tr('orderSentTitle'),
          message: context.strings.tr('orderSentDescription'),
          orderId: order.id,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
