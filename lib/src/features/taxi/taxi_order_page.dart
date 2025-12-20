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
import '../../widgets/cupertino_wheel_time_picker.dart';
import '../auth/auth_guard.dart';
import '../common/order_sent_page.dart';
import 'pickup_location_picker_page.dart';

class TaxiOrderPage extends StatefulWidget {
  const TaxiOrderPage({super.key});

  @override
  State<TaxiOrderPage> createState() => _TaxiOrderPageState();
}

class _TaxiOrderPageState extends State<TaxiOrderPage> {
  final TextEditingController clientNameCtrl = TextEditingController();
  final TextEditingController clientPhoneCtrl = TextEditingController();
  String? fromRegion;
  String? fromDistrict;
  String? toRegion;
  String? toDistrict;
  int passengers = 1;
  String clientGender = 'male';
  DateTime selectedDate = DateTime.now();
  TimeOfDay scheduledTime = TimeOfDay.fromDateTime(DateTime.now());
  bool confirming = false;
  PickupLocation? pickupLocation;
  bool detectingPickup = false;
  final LocationService _locationService = const LocationService();
  final TextEditingController noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser;
    clientNameCtrl.text =
        user.fullName.toLowerCase() == 'unknown' ? '' : user.fullName;
    clientPhoneCtrl.text = user.phoneNumber.trim().startsWith('+')
        ? user.phoneNumber
        : '+998';
    _detectInitialPickupLocation();
  }

  @override
  void dispose() {
    clientNameCtrl.dispose();
    clientPhoneCtrl.dispose();
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
        pickupLocation != null;

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
                  _SectionTitle(label: strings.tr('senderInfo')),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: clientNameCtrl,
                    label: strings.tr('fullName'),
                    prefixIcon: Icons.person_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: clientPhoneCtrl,
                    label: strings.tr('phoneNumber'),
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
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
                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle(label: strings.tr('pickupAddress')),
                  GestureDetector(
                    onTap: _openPickupLocationPicker,
                    behavior: HitTestBehavior.opaque,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: strings.tr('pickupAddress'),
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
                      onPressed: detectingPickup ? null : _useCurrentLocation,
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
                            setState(() {
                              passengers = count;
                              if (passengers == 1 && clientGender == 'both') {
                                clientGender = 'male';
                              }
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle(label: strings.tr('passengerGender')),
                  Wrap(
                    spacing: 10,
                    runSpacing: AppSpacing.xs,
                    children: ['male', 'female', 'both'].map((gender) {
                      final enabled = passengers > 1 || gender != 'both';
                      return ChoiceChip(
                        label: Text(_genderLabel(strings, gender)),
                        selected: clientGender == gender,
                        onSelected: !enabled
                            ? null
                            : (selected) {
                                if (selected) {
                                  setState(() => clientGender = gender);
                                }
                              },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle(label: strings.tr('scheduledTime')),
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
                  _SectionTitle(label: strings.tr('optionalNote')),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: noteCtrl,
                    label: strings.tr('note'),
                    hintText: strings.tr('noteHint'),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    minLines: 3,
                    maxLines: 3,
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
                    strings.tr('confirmOrder'),
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
                      fontWeight: FontWeight.w600,
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

  Future<void> _selectScheduledTime() async {
    final picked = await showCupertinoWheelTimePicker(
      context,
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

  Future<void> _useCurrentLocation() async {
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

  String _pickupAddressLabel(AppLocalizations strings) {
    if (pickupLocation != null && pickupLocation!.address.trim().isNotEmpty) {
      return pickupLocation!.address;
    }
    if (pickupLocation != null) {
      return '${pickupLocation!.latitude.toStringAsFixed(5)}, '
          '${pickupLocation!.longitude.toStringAsFixed(5)}';
    }
    if (detectingPickup) {
      return strings.tr('detectingLocation');
    }
    return strings.tr('tapToPickOnMap');
  }

  String _effectiveClientName(AppState state) {
    final input = clientNameCtrl.text.trim();
    if (input.isNotEmpty) return input;
    return state.currentUser.fullName;
  }

  String _effectiveClientPhone(AppState state) {
    final input = clientPhoneCtrl.text.trim();
    if (input.isNotEmpty) return input;
    final userPhone = state.currentUser.phoneNumber.trim();
    if (userPhone.isNotEmpty) return userPhone;
    return '+998';
  }

  String _genderLabel(AppLocalizations strings, String gender) {
    switch (gender) {
      case 'male':
        return strings.tr('genderMale');
      case 'female':
        return strings.tr('genderFemale');
      default:
        return strings.tr('genderBoth');
    }
  }

  double? _calculatePrice(AppState state) {
    if (fromRegion == null || toRegion == null) {
      return null;
    }
    return state.calculateTaxiPrice(
      fromRegion: fromRegion!,
      toRegion: toRegion!,
      passengers: passengers,
    );
  }

  String _formatPrice(double price) {
    final formatted = NumberFormat.decimalPattern().format(price);
    return '$formatted so\'m';
  }

  Future<void> _showSummary(double? price) async {
    setState(() => confirming = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final state = context.read<AppState>();
    final strings = context.strings;
    if (!state.isAuthenticated) {
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
        final dialogStrings = dialogContext.strings;
        final scheduledTimeLabel = scheduledTime.format(dialogContext);
        final clientName = _effectiveClientName(state);
        final clientPhone = _effectiveClientPhone(state);
        return GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogStrings.tr('orderSummary'),
                style: Theme.of(
                  dialogContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              _SummaryRow(
                label: dialogStrings.tr('sender'),
                value: '$clientName\n$clientPhone',
              ),
              _SummaryRow(
                label: dialogStrings.tr('fromLocation'),
                value: '${fromRegion!}, ${fromDistrict!}',
              ),
              _SummaryRow(
                label: dialogStrings.tr('toLocation'),
                value: '${toRegion!}, ${toDistrict!}',
              ),
              if (pickupLocation != null)
                _SummaryRow(
                  label: dialogStrings.tr('pickupAddress'),
                  value: pickupLocation!.address.trim().isEmpty
                      ? '${pickupLocation!.latitude.toStringAsFixed(5)}, '
                            '${pickupLocation!.longitude.toStringAsFixed(5)}'
                      : pickupLocation!.address,
                ),
              _SummaryRow(
                label: dialogStrings.tr('passengers'),
                value: passengers == 4
                    ? dialogStrings.tr('fullCar')
                    : passengers.toString(),
              ),
              _SummaryRow(
                label: dialogStrings.tr('passengerGender'),
                value: _genderLabel(dialogStrings, clientGender),
              ),
              _SummaryRow(
                label: dialogStrings.tr('date'),
                value: DateFormat('dd.MM.yyyy').format(selectedDate),
              ),
              _SummaryRow(
                label: dialogStrings.tr('scheduledTime'),
                value: scheduledTimeLabel,
              ),
              _SummaryRow(
                label: dialogStrings.tr('note'),
                value: noteCtrl.text.isEmpty
                    ? dialogStrings.tr('noNote')
                    : noteCtrl.text,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                price == null
                    ? dialogStrings.tr('priceUnspecified')
                    : _formatPrice(price),
                style: Theme.of(dialogContext).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              GradientButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _sendOrder();
                },
                label: dialogStrings.tr('sendOrder'),
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
    if (!mounted) return;
    if (!loggedIn) {
      setState(() => confirming = false);
      return;
    }
    if (pickupLocation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.tr('tapToPickOnMap'))));
      return;
    }
    try {
      final order = await state.createTaxiOrder(
        fromRegion: fromRegion!,
        fromDistrict: fromDistrict!,
        toRegion: toRegion!,
        toDistrict: toDistrict!,
        passengers: passengers,
        clientGender: clientGender,
        scheduledDate: selectedDate,
        scheduledTime: scheduledTime,
        pickupLocation: pickupLocation!,
        note: noteCtrl.text,
        customerName: clientNameCtrl.text,
        customerPhone: clientPhoneCtrl.text,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => OrderSentPage(
            title: strings.tr('orderSentTitle'),
            message: strings.tr('orderSentDescription'),
            orderId: order.id,
          ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}
