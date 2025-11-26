class PricingModel {
  PricingModel({
    required this.id,
    required this.fromRegionId,
    required this.toRegionId,
    required this.serviceType,
    required this.basePrice,
    required this.discountOnePassenger,
    required this.discountTwoPassengers,
    required this.discountThreePassengers,
    required this.discountFullCar,
    required this.isActive,
  });

  factory PricingModel.fromJson(Map<String, dynamic> json) {
    return PricingModel(
      id: _parseInt(json['id']),
      fromRegionId: _parseInt(json['from_region_id']),
      toRegionId: _parseInt(json['to_region_id']),
      serviceType: (json['service_type'] ?? '').toString().toLowerCase(),
      basePrice: _parseDouble(json['base_price']),
      discountOnePassenger: _parseDouble(json['discount_1_passenger']),
      discountTwoPassengers: _parseDouble(json['discount_2_passengers']),
      discountThreePassengers: _parseDouble(json['discount_3_passengers']),
      discountFullCar: _parseDouble(json['discount_full_car']),
      isActive: json['is_active'] == null
          ? true
          : json['is_active'].toString() == 'true' ||
              json['is_active'].toString() == '1',
    );
  }

  final int id;
  final int fromRegionId;
  final int toRegionId;
  final String serviceType;
  final double basePrice;
  final double discountOnePassenger;
  final double discountTwoPassengers;
  final double discountThreePassengers;
  final double discountFullCar;
  final bool isActive;

  double priceForPassengers(int passengers) {
    // For taxi service: price per person × passengers
    // Backend calculates: total_price = base_price * passengers
    if (serviceType == 'taxi') {
      return basePrice * passengers;
    }

    // For delivery: fixed price regardless of passengers
    return basePrice;
  }

  double priceWithoutDiscount() => basePrice;

  double _applyDiscount(double percent) {
    if (percent <= 0) return basePrice;
    return basePrice * (1 - (percent / 100));
  }

  static int _parseInt(Object? value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  static double _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
