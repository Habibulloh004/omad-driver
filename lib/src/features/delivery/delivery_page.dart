import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../api/auth_api.dart';
import '../../core/design_tokens.dart';
import '../../localization/app_localizations.dart';
import '../../localization/localization_ext.dart';
import '../../models/location.dart';
import '../../services/location_service.dart';
import '../../state/app_state.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/gradient_button.dart';
import '../auth/auth_guard.dart';
import '../common/order_sent_page.dart';
import '../taxi/pickup_location_picker_page.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  final TextEditingController senderNameCtrl = TextEditingController();
  final TextEditingController senderPhoneCtrl = TextEditingController();
  final TextEditingController receiverPhoneCtrl = TextEditingController();
  final TextEditingController noteCtrl = TextEditingController();
  final LocationService _locationService = const LocationService();

  String? fromRegion;
  String? fromDistrict;
  String? toRegion;
  String? toDistrict;
  String packageType = 'document';
  DateTime selectedDate = DateTime.now();
  TimeOfDay scheduledTime = TimeOfDay.fromDateTime(DateTime.now());
  PickupLocation? pickupLocation;
  PickupLocation? dropoffLocation;
  bool detectingPickup = false;

  bool confirming = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final user = state.currentUser;
    senderNameCtrl.text = user.fullName.toLowerCase() == 'unknown'
        ? ''
        : user.fullName;
    senderPhoneCtrl.text = user.phoneNumber.trim().startsWith('+')
        ? user.phoneNumber
        : '+998';
    receiverPhoneCtrl.text = '+998';
    _detectInitialPickupLocation();
  }

  @override
  void dispose() {
    senderNameCtrl.dispose();
    senderPhoneCtrl.dispose();
    receiverPhoneCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = context.strings;
    final regions = state.regions;
    final price = _calculatePrice(state);
    final isAuthenticated = state.isAuthenticated;
    final canSubmitOrder = isAuthenticated;

    final ready =
        fromRegion != null &&
        fromDistrict != null &&
        toRegion != null &&
        toDistrict != null &&
        fromRegion != toRegion &&
        pickupLocation != null &&
        dropoffLocation != null &&
        receiverPhoneCtrl.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(strings.tr('sendDelivery'))),
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
                  _SectionLabel(label: strings.tr('senderInfo')),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: senderNameCtrl,
                    label: strings.tr('fullName'),
                    prefixIcon: Icons.person_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: senderPhoneCtrl,
                    label: strings.tr('phoneNumber'),
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_rounded,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionLabel(label: strings.tr('receiverInfo')),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: receiverPhoneCtrl,
                    label: strings.tr('receiverPhone'),
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.call_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: strings.tr('pickupLocation')),
                  const SizedBox(height: AppSpacing.xxs),
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
                        if (toRegion == value) {
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
                  _SectionLabel(label: strings.tr('dropLocation')),
                  const SizedBox(height: AppSpacing.xxs),
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
                                : regions[toRegion]!)
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
                  const SizedBox(height: AppSpacing.lg),
                  _SectionLabel(label: strings.tr('pickupAddress')),
                  const SizedBox(height: AppSpacing.xxs),
                  GestureDetector(
                    onTap: _openPickupLocationPicker,
                    behavior: HitTestBehavior.opaque,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        hintText: strings.tr('tapToPickOnMap'),
                        suffixIcon: const Icon(Icons.pin_drop_outlined),
                      ),
                      isEmpty: pickupLocation == null,
                      child: pickupLocation == null
                          ? const SizedBox.shrink()
                          : Text(
                              _pickupAddressLabel(strings),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: detectingPickup ? null : _useCurrentPickup,
                      icon: detectingPickup
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded),
                      label: Text(strings.tr('useCurrentLocation')),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionLabel(label: strings.tr('dropoffAddress')),
                  const SizedBox(height: AppSpacing.xxs),
                  GestureDetector(
                    onTap: _openDropoffLocationPicker,
                    behavior: HitTestBehavior.opaque,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        hintText: strings.tr('tapToPickOnMap'),
                        suffixIcon: const Icon(Icons.place_outlined),
                      ),
                      isEmpty: dropoffLocation == null,
                      child: dropoffLocation == null
                          ? const SizedBox.shrink()
                          : Text(
                              _dropoffAddressLabel(strings),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: strings.tr('packageType')),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _packageTypes
                        .map(
                          (type) => ChoiceChip(
                            label: Text(strings.tr(type)),
                            selected: packageType == type,
                            onSelected: (value) {
                              if (value) {
                                setState(() => packageType = type);
                              }
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionLabel(label: strings.tr('scheduledTime')),
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
                          onPressed: _selectScheduledTime,
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text(scheduledTime.format(context)),
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
                  _SectionLabel(label: strings.tr('optionalNote')),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: noteCtrl,
                    label: strings.tr('note'),
                    hintText: strings.tr('noteHint'),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    maxLines: 3,
                    minLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.tr('confirmDelivery'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    !ready
                        ? strings.tr('fillInfoForPrice')
                        : price == null
                        ? strings.tr('priceUnspecified')
                        : _formatPrice(price),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (!canSubmitOrder) ...[
                    Text(
                      strings.tr('loginToOrder'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  GradientButton(
                    onPressed: !ready || confirming || !canSubmitOrder
                        ? null
                        : () => _showSummary(price),
                    label: strings.tr('confirmDelivery'),
                    icon: Icons.inventory_2_rounded,
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

  Future<void> _selectScheduledTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: scheduledTime,
    );
    if (picked != null) {
      setState(() => scheduledTime = picked);
    }
  }

  Future<void> _detectInitialPickupLocation() async {
    final detected = await _locationService.tryFetchCurrentPickup();
    if (mounted && detected != null) {
      setState(() => pickupLocation = detected);
    }
  }

  Future<void> _useCurrentPickup() async {
    final strings = context.strings;
    setState(() => detectingPickup = true);
    try {
      final location = await _locationService.fetchCurrentPickup();
      if (!mounted) return;
      setState(() => pickupLocation = location);
    } on LocationPermissionException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.tr('locationPermissionDenied'))),
      );
    } on LocationServicesDisabledException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.tr('enableLocationServices'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.tr('locationUnavailable'))),
      );
    } finally {
      if (mounted) {
        setState(() => detectingPickup = false);
      }
    }
  }

  Future<void> _openPickupLocationPicker() async {
    final selected = await Navigator.of(context).push<PickupLocation>(
      MaterialPageRoute(
        builder: (_) =>
            PickupLocationPickerPage(initialLocation: pickupLocation),
      ),
    );
    if (selected != null && mounted) {
      setState(() => pickupLocation = selected);
    }
  }

  Future<void> _openDropoffLocationPicker() async {
    final selected = await Navigator.of(context).push<PickupLocation>(
      MaterialPageRoute(
        builder: (_) =>
            PickupLocationPickerPage(initialLocation: dropoffLocation),
      ),
    );
    if (selected != null && mounted) {
      setState(() => dropoffLocation = selected);
    }
  }

  String _pickupAddressLabel(AppLocalizations strings) {
    return _addressLabel(pickupLocation, strings, detectingPickup);
  }

  String _dropoffAddressLabel(AppLocalizations strings) {
    return _addressLabel(dropoffLocation, strings, false);
  }

  String _addressLabel(
    PickupLocation? location,
    AppLocalizations strings,
    bool detecting,
  ) {
    if (location != null && location.address.trim().isNotEmpty) {
      return location.address;
    }
    if (location != null) {
      return '${location.latitude.toStringAsFixed(5)}, '
          '${location.longitude.toStringAsFixed(5)}';
    }
    if (detecting) {
      return strings.tr('detectingLocation');
    }
    return strings.tr('tapToPickOnMap');
  }

  String _formatLocation(PickupLocation location) {
    return location.address.trim().isEmpty
        ? '${location.latitude.toStringAsFixed(5)}, '
              '${location.longitude.toStringAsFixed(5)}'
        : location.address;
  }

  double? _calculatePrice(AppState state) {
    if (fromRegion == null || toRegion == null) {
      return null;
    }
    return state.calculateDeliveryPrice(
      fromRegion: fromRegion!,
      toRegion: toRegion!,
      packageType: packageType,
    );
  }

  String _formatPrice(double price) {
    final formatted = NumberFormat.decimalPattern().format(price);
    return '$formatted so\'m';
  }

  Future<void> _showSummary(double? price) async {
    setState(() => confirming = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final strings = context.strings;
    if (!context.read<AppState>().isAuthenticated) {
      await ensureLoggedIn(context);
      if (mounted) {
        setState(() => confirming = false);
      }
      return;
    }

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
                strings.tr('deliverySummary'),
                style: Theme.of(
                  dialogContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              _SummaryRow(
                label: strings.tr('sender'),
                value: '${senderNameCtrl.text}\n${senderPhoneCtrl.text}',
              ),
              _SummaryRow(
                label: strings.tr('receiver'),
                value: receiverPhoneCtrl.text,
              ),
              _SummaryRow(
                label: strings.tr('fromLocation'),
                value: '${fromRegion!}, ${fromDistrict!}',
              ),
              _SummaryRow(
                label: strings.tr('toLocation'),
                value: '${toRegion!}, ${toDistrict!}',
              ),
              if (pickupLocation != null)
                _SummaryRow(
                  label: strings.tr('pickupAddress'),
                  value: _formatLocation(pickupLocation!),
                ),
              if (dropoffLocation != null)
                _SummaryRow(
                  label: strings.tr('dropoffAddress'),
                  value: _formatLocation(dropoffLocation!),
                ),
              _SummaryRow(
                label: strings.tr('packageType'),
                value: strings.tr(packageType),
              ),
              _SummaryRow(
                label: strings.tr('scheduledTime'),
                value: scheduledTime.format(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(strings.tr('note')),
              Text(
                noteCtrl.text.isEmpty ? strings.tr('noNote') : noteCtrl.text,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                price == null
                    ? strings.tr('priceUnspecified')
                    : _formatPrice(price),
                style: Theme.of(dialogContext).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              GradientButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _sendOrder();
                },
                label: strings.tr('sendDelivery'),
                icon: Icons.send_rounded,
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() => confirming = false);
  }

  Future<void> _sendOrder() async {
    final state = context.read<AppState>();
    final strings = context.strings;
    final loggedIn = await ensureLoggedIn(context, showMessage: false);
    if (!loggedIn) {
      if (mounted) {
        setState(() => confirming = false);
      }
      return;
    }
    if (pickupLocation == null || dropoffLocation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.tr('tapToPickOnMap'))));
      return;
    }
    try {
      final order = await state.createDeliveryOrder(
        fromRegion: fromRegion!,
        fromDistrict: fromDistrict!,
        toRegion: toRegion!,
        toDistrict: toDistrict!,
        packageType: packageType,
        scheduledDate: selectedDate,
        scheduledTime: scheduledTime,
        senderName: senderNameCtrl.text,
        senderPhone: senderPhoneCtrl.text,
        receiverPhone: receiverPhoneCtrl.text,
        pickupLocation: pickupLocation!,
        dropoffLocation: dropoffLocation!,
        note: noteCtrl.text,
      );

      if (!mounted) return;

      final orderId = order.id;
      final title = strings.tr('deliverySentTitle');
      final message = strings.tr('deliverySentDescription');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) =>
              OrderSentPage(title: title, message: message, orderId: orderId),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.tr('unexpectedError'))),
      );
    }
  }
}

const _packageTypes = ['document', 'box', 'luggage', 'valuable', 'other'];

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
