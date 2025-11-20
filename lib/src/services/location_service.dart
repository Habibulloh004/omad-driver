import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

import '../models/location.dart';

class LocationPermissionException implements Exception {
  const LocationPermissionException([this.message]);
  final String? message;
}

class LocationServicesDisabledException implements Exception {
  const LocationServicesDisabledException([this.message]);
  final String? message;
}

class LocationService {
  const LocationService();

  Future<void> _ensurePermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServicesDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationPermissionException();
    }
  }

  Future<Position> _currentPosition() async {
    await _ensurePermissions();
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Future<PickupLocation> fetchCurrentPickup() async {
    final position = await _currentPosition();
    final address = await resolveAddress(
          latitude: position.latitude,
          longitude: position.longitude,
        ) ??
        '';
    return PickupLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
    );
  }

  Future<PickupLocation?> tryFetchCurrentPickup() async {
    try {
      return await fetchCurrentPickup();
    } on LocationPermissionException {
      return null;
    } on LocationServicesDisabledException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> resolveAddress({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isEmpty) return null;
      final place = placemarks.first;
      final segments = <String?>[
        place.street ?? place.thoroughfare,
        place.subLocality,
        place.locality,
        place.administrativeArea,
      ];
      final cleaned = segments
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (cleaned.isEmpty) return null;
      return cleaned.toSet().join(', ');
    } catch (_) {
      return null;
    }
  }
}
