import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/design_tokens.dart';
import '../../localization/localization_ext.dart';
import '../../models/location.dart';
import '../../services/location_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';

class PickupLocationPickerPage extends StatefulWidget {
  const PickupLocationPickerPage({super.key, this.initialLocation});

  final PickupLocation? initialLocation;

  @override
  State<PickupLocationPickerPage> createState() =>
      _PickupLocationPickerPageState();
}

class _PickupLocationPickerPageState extends State<PickupLocationPickerPage> {
  late final MapController _mapController;
  final LocationService _locationService = const LocationService();

  LatLng _selected = const LatLng(41.2995, 69.2401);
  String? _address;
  bool _resolvingAddress = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    final initialLocation = widget.initialLocation ??
        const PickupLocation(latitude: 41.2995, longitude: 69.2401);
    _selected = LatLng(initialLocation.latitude, initialLocation.longitude);
    _address = initialLocation.address.isEmpty ? null : initialLocation.address;
    if (_address == null) {
      _resolveAddress(_selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('pickOnMap')),
        actions: [
          IconButton(
            onPressed: _locating ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selected,
              initialZoom: 16,
              maxZoom: 18,
              onTap: (_, latLng) => _onMapTap(latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.mobile.taxi',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 60,
                    height: 60,
                    point: _selected,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.redAccent,
                      size: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.xxl * 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'pickup-zoom-in',
                  onPressed: () => _zoomBy(1),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: AppSpacing.sm),
                FloatingActionButton.small(
                  heroTag: 'pickup-zoom-out',
                  onPressed: () => _zoomBy(-1),
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.lg,
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.tr('selectedAddress'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _address ??
                        (_resolvingAddress
                            ? strings.tr('searchingAddress')
                            : strings.tr('tapToPickOnMap')),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GradientButton(
                    onPressed: () => _confirmSelection(context),
                    label: strings.tr('confirmLocation'),
                    icon: Icons.check_rounded,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _selected = latLng;
    });
    _resolveAddress(latLng);
  }

  Future<void> _resolveAddress(LatLng latLng) async {
    setState(() => _resolvingAddress = true);
    final address = await _locationService.resolveAddress(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
    );
    if (!mounted) return;
    setState(() {
      _resolvingAddress = false;
      _address = address;
    });
  }

  Future<void> _useCurrentLocation() async {
    final strings = context.strings;
    setState(() => _locating = true);
    try {
      final location = await _locationService.fetchCurrentPickup();
      if (!mounted) return;
      final latLng = LatLng(location.latitude, location.longitude);
      _mapController.move(latLng, 16);
      setState(() {
        _selected = latLng;
        _address = location.address.isEmpty ? null : location.address;
      });
      if (!_resolvingAddress && !_hasAddress) {
        _resolveAddress(latLng);
      }
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
        setState(() => _locating = false);
      }
    }
  }

  bool get _hasAddress => (_address ?? '').trim().isNotEmpty;

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final newZoom = (camera.zoom + delta).clamp(3.0, 18.0);
    _mapController.move(camera.center, newZoom);
  }

  void _confirmSelection(BuildContext context) {
    final location = PickupLocation(
      latitude: _selected.latitude,
      longitude: _selected.longitude,
      address: _hasAddress
          ? _address!.trim()
          : '${_selected.latitude.toStringAsFixed(5)}, '
              '${_selected.longitude.toStringAsFixed(5)}',
    );
    Navigator.of(context).pop(location);
  }
}
