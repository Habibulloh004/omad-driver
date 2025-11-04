import 'package:flutter/material.dart';

enum OrderType { taxi, delivery }

enum OrderStatus { pending, active, completed, cancelled }

class AppOrder {
  AppOrder({
    required this.id,
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
    required this.status,
    this.note,
    this.driverName,
    this.driverPhone,
    this.vehicle,
    this.vehiclePlate,
  });

  final String id;
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
  final OrderStatus status;
  final String? note;
  final String? driverName;
  final String? driverPhone;
  final String? vehicle;
  final String? vehiclePlate;

  bool get isTaxi => type == OrderType.taxi;
  bool get isDelivery => type == OrderType.delivery;

  AppOrder copyWith({
    OrderStatus? status,
    String? driverName,
    String? driverPhone,
    String? vehicle,
    String? vehiclePlate,
  }) {
    return AppOrder(
      id: id,
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
      status: status ?? this.status,
      note: note,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      vehicle: vehicle ?? this.vehicle,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
    );
  }
}
