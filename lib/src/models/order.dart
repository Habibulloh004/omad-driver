import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum OrderType { taxi, delivery }

enum OrderStatus { pending, active, completed, cancelled }

class AppOrder {
  AppOrder({
    required this.id,
    this.ownerId = '',
    this.createdAt,
    required this.type,
    required this.fromRegion,
    required this.fromDistrict,
    required this.toRegion,
    required this.toDistrict,
    required this.passengers,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.price,
    this.serviceFee = 0,
    this.priceAvailable = false,
    required this.status,
    required this.fromRegionId,
    required this.fromDistrictId,
    required this.toRegionId,
    required this.toDistrictId,
    this.note,
    this.driverName,
    this.driverPhone,
    this.vehicle,
    this.vehiclePlate,
    this.cancelReason,
    this.scheduledAt,
    this.driverStartTime,
    this.driverEndTime,
    this.customerName,
    this.customerPhone,
    this.isConfirmed = false,
    this.confirmedAt,
    this.pickupLatitude,
    this.pickupLongitude,
    this.pickupAddress,
    this.driverId,
  });

  factory AppOrder.fromJson(
    Map<String, dynamic> json, {
    String Function(int id)? resolveRegionName,
    String Function(int id)? resolveDistrictName,
    OrderType? fallbackType,
  }) {
    final rawType = (json['order_type'] ?? json['type'] ?? '')
        .toString()
        .toLowerCase();
    final rawStatus = (json['status'] ?? '').toString().toLowerCase();
    final scheduledDate = (json['scheduled_date'] ?? json['date'] ?? '')
        .toString();
    final scheduledRaw = json['scheduled_datetime']?.toString() ?? '';
    final startRaw = (json['time_range_start'] ?? json['time_start'] ?? '')
        .toString();
    final endRaw = (json['time_range_end'] ?? json['time_end'] ?? '')
        .toString();

    final fromRegionId = _toInt(json['from_region_id']);
    final fromDistrictId = _toInt(json['from_district_id']);
    final toRegionId = _toInt(json['to_region_id']);
    final toDistrictId = _toInt(json['to_district_id']);

    final regionName = resolveRegionName ?? _fallbackRegionName;
    final districtName = resolveDistrictName ?? _fallbackDistrictName;

    final orderType = rawType == 'delivery'
        ? OrderType.delivery
        : rawType == 'taxi'
        ? OrderType.taxi
        : (fallbackType ?? _inferOrderTypeFromJson(json));
    final orderStatus = _parseStatus(rawStatus);

    final scheduledAt =
        _parseDateTimeValue(scheduledRaw) ?? _parseDate(scheduledDate);
    final scheduledTime = scheduledAt == null
        ? _parseTime(startRaw)
        : TimeOfDay(hour: scheduledAt.hour, minute: scheduledAt.minute);
    final actualStartTime = _parseTime((json['time_start'] ?? '').toString());
    final actualEndTime = _parseTime((json['time_end'] ?? '').toString());
    final startTime =
        actualStartTime ?? scheduledTime ?? const TimeOfDay(hour: 0, minute: 0);
    final endTime = actualEndTime ?? _parseTime(endRaw) ?? startTime;

    final passengersValue =
        json['passenger_count'] ?? json['passengers'] ?? json['passenger'];
    final passengers = passengersValue is num
        ? passengersValue.toInt()
        : int.tryParse('$passengersValue') ?? 1;

    final priceSource =
        json['final_price'] ?? json['price'] ?? json['calculated_price'];
    final parsedPrice = _toDouble(priceSource);
    final price = parsedPrice ?? 0.0;
    final hasPrice = parsedPrice != null;
    final rawServiceFee =
        json['service_fee'] ?? json['serviceFee'] ?? json['service_fee_amount'];
    final serviceFee = _toDouble(rawServiceFee) ?? 0.0;
    final ownerId = (json['user_id'] ?? json['customer_id'] ?? '').toString();
    final createdAtRaw = json['created_at'] ?? json['createdAt'];
    final createdAt = createdAtRaw == null
        ? null
        : _parseDateTimeValue(createdAtRaw.toString());

    String? driverName;
    String? driverPhone;
    String? vehicle;
    String? vehiclePlate;
    final rawDriverId = _toInt(json['driver_id']);
    int? driverId = rawDriverId == 0 ? null : rawDriverId;

    final driver = json['driver'];
    if (driver is Map) {
      final map = Map<String, dynamic>.from(driver);
      final mappedId = _toInt(map['id']);
      if (mappedId > 0) driverId = mappedId;
      driverName = map['full_name']?.toString() ?? map['name']?.toString();
      driverPhone = map['phone_number']?.toString();
      vehicle = map['car_model']?.toString() ?? map['vehicle']?.toString();
      vehiclePlate =
          map['car_number']?.toString() ?? map['vehicle_plate']?.toString();
    }
    driverName ??=
        json['driver_name']?.toString() ?? json['driver_full_name']?.toString();
    driverPhone ??= json['driver_phone']?.toString();
    vehicle ??= json['driver_car_model']?.toString();
    vehiclePlate ??= json['driver_car_number']?.toString();
    final customerName =
        json['username']?.toString() ??
        json['customer_name']?.toString() ??
        json['user_name']?.toString();
    final customerPhone =
        json['telephone']?.toString() ??
        json['phone_number']?.toString() ??
        json['user_phone']?.toString() ??
        (orderType == OrderType.delivery
            ? (json['sender_telephone'] ?? json['receiver_telephone'])
                  ?.toString()
            : null);
    final confirmedAtRaw = json['confirmed_at'] ?? json['confirmation_time'];
    final confirmedAt = confirmedAtRaw == null
        ? null
        : _parseDateTimeValue(confirmedAtRaw.toString());
    final isConfirmed = _toBool(json['is_confirmed']);
    final pickupLatitude = _toDouble(
      json['pickup_latitude'] ??
          json['pickup_lat'] ??
          json['from_latitude'] ??
          json['latitude'],
    );
    final pickupLongitude = _toDouble(
      json['pickup_longitude'] ??
          json['pickup_lng'] ??
          json['from_longitude'] ??
          json['longitude'],
    );
    final pickupAddress =
        (json['pickup_address'] ?? json['address'] ?? json['from_address'])
            ?.toString();

    return AppOrder(
      id: (json['id'] ?? '').toString(),
      ownerId: ownerId,
      createdAt: createdAt,
      type: orderType,
      fromRegion: regionName(fromRegionId),
      fromDistrict: districtName(fromDistrictId),
      toRegion: regionName(toRegionId),
      toDistrict: districtName(toDistrictId),
      passengers: passengers,
      date: scheduledAt ?? DateTime.now(),
      startTime: startTime,
      endTime: endTime,
      price: price,
      serviceFee: serviceFee,
      priceAvailable: hasPrice,
      status: orderStatus,
      fromRegionId: fromRegionId,
      fromDistrictId: fromDistrictId,
      toRegionId: toRegionId,
      toDistrictId: toDistrictId,
      note: (json['notes'] ?? json['note'])?.toString(),
      driverName: driverName,
      driverPhone: driverPhone,
      vehicle: vehicle,
      vehiclePlate: vehiclePlate,
      cancelReason: json['cancellation_reason']?.toString(),
      scheduledAt: scheduledAt,
      driverStartTime: actualStartTime,
      driverEndTime: actualEndTime,
      customerName: customerName,
      customerPhone: customerPhone,
      isConfirmed: isConfirmed,
      confirmedAt: confirmedAt,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      pickupAddress: pickupAddress,
      driverId: driverId,
    );
  }

  final String id;
  final String ownerId;
  final DateTime? createdAt;
  final OrderType type;
  final String fromRegion;
  final String fromDistrict;
  final String toRegion;
  final String toDistrict;
  final int passengers;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final double price;
  final double serviceFee;
  final bool priceAvailable;
  final OrderStatus status;
  final int fromRegionId;
  final int fromDistrictId;
  final int toRegionId;
  final int toDistrictId;
  final String? note;
  final String? driverName;
  final String? driverPhone;
  final String? vehicle;
  final String? vehiclePlate;
  final int? driverId;
  final String? cancelReason;
  final DateTime? scheduledAt;
  final TimeOfDay? driverStartTime;
  final TimeOfDay? driverEndTime;
  final String? customerName;
  final String? customerPhone;
  final bool isConfirmed;
  final DateTime? confirmedAt;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String? pickupAddress;

  bool get isTaxi => type == OrderType.taxi;
  bool get isDelivery => type == OrderType.delivery;

  AppOrder copyWith({
    OrderStatus? status,
    String? driverName,
    String? driverPhone,
    String? vehicle,
    String? vehiclePlate,
    int? driverId,
    String? note,
    double? price,
    double? serviceFee,
    bool? priceAvailable,
    String? cancelReason,
    DateTime? scheduledAt,
    TimeOfDay? driverStartTime,
    TimeOfDay? driverEndTime,
    String? ownerId,
    DateTime? createdAt,
    String? customerName,
    String? customerPhone,
    bool? isConfirmed,
    DateTime? confirmedAt,
    double? pickupLatitude,
    double? pickupLongitude,
    String? pickupAddress,
  }) {
    return AppOrder(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      type: type,
      fromRegion: fromRegion,
      fromDistrict: fromDistrict,
      toRegion: toRegion,
      toDistrict: toDistrict,
      passengers: passengers,
      date: date,
      startTime: startTime,
      endTime: endTime,
      price: price ?? this.price,
      serviceFee: serviceFee ?? this.serviceFee,
      priceAvailable: priceAvailable ?? this.priceAvailable,
      status: status ?? this.status,
      fromRegionId: fromRegionId,
      fromDistrictId: fromDistrictId,
      toRegionId: toRegionId,
      toDistrictId: toDistrictId,
      note: note ?? this.note,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      vehicle: vehicle ?? this.vehicle,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      driverId: driverId ?? this.driverId,
      cancelReason: cancelReason ?? this.cancelReason,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      driverStartTime: driverStartTime ?? this.driverStartTime,
      driverEndTime: driverEndTime ?? this.driverEndTime,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      pickupAddress: pickupAddress ?? this.pickupAddress,
    );
  }

  AppOrder withResolvedNames({
    required String fromRegion,
    required String fromDistrict,
    required String toRegion,
    required String toDistrict,
  }) {
    return AppOrder(
      id: id,
      ownerId: ownerId,
      createdAt: createdAt,
      type: type,
      fromRegion: fromRegion,
      fromDistrict: fromDistrict,
      toRegion: toRegion,
      toDistrict: toDistrict,
      passengers: passengers,
      date: date,
      startTime: startTime,
      endTime: endTime,
      price: price,
      serviceFee: serviceFee,
      status: status,
      fromRegionId: fromRegionId,
      fromDistrictId: fromDistrictId,
      toRegionId: toRegionId,
      toDistrictId: toDistrictId,
      note: note,
      driverName: driverName,
      driverPhone: driverPhone,
      vehicle: vehicle,
      vehiclePlate: vehiclePlate,
      cancelReason: cancelReason,
      scheduledAt: scheduledAt,
      driverStartTime: driverStartTime,
      driverEndTime: driverEndTime,
      customerName: customerName,
      customerPhone: customerPhone,
      isConfirmed: isConfirmed,
      confirmedAt: confirmedAt,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      pickupAddress: pickupAddress,
      driverId: driverId,
    );
  }
}

OrderType _inferOrderTypeFromJson(Map<String, dynamic> json) {
  if (json.containsKey('item_type') ||
      json.containsKey('sender_telephone') ||
      json.containsKey('receiver_telephone') ||
      json.containsKey('recipient_phone') ||
      json.containsKey('delivery_type')) {
    return OrderType.delivery;
  }
  return OrderType.taxi;
}

OrderStatus _parseStatus(String raw) {
  return switch (raw) {
    'pending' => OrderStatus.pending,
    'accepted' || 'in_progress' => OrderStatus.active,
    'completed' => OrderStatus.completed,
    'cancelled' => OrderStatus.cancelled,
    _ => OrderStatus.pending,
  };
}

DateTime? _parseDate(String value) {
  if (value.isEmpty) return null;
  try {
    return DateFormat('dd.MM.yyyy').parse(value);
  } catch (_) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
}

DateTime? _parseDateTimeValue(String value) {
  if (value.isEmpty) return null;
  try {
    final parsed = DateTime.parse(value);
    return parsed.isUtc ? parsed.toLocal() : parsed;
  } catch (_) {
    return _parseDate(value);
  }
}

TimeOfDay? _parseTime(String value) {
  if (value.isEmpty) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
}

String _fallbackRegionName(int id) => id == 0 ? '' : 'Region $id';

String _fallbackDistrictName(int id) => id == 0 ? '' : 'District $id';

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final sanitized = value.toString().trim();
  if (sanitized.isEmpty) return null;
  return double.tryParse(sanitized);
}

bool _toBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  if (normalized.isEmpty) return false;
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'ha';
}
