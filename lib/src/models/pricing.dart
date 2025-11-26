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
    // Backend calculation logic:
    // 1. Get discount_percentage based on passenger count
    // 2. price_per_person = base_price × (1 - discount_percentage / 100)
    // 3. total_price = price_per_person × passengers

    if (serviceType == 'delivery') {
      // For delivery: fixed price regardless of passengers
      return basePrice;
    }

    // For taxi: apply discount based on passenger count
    final discountPercentage = _getDiscountPercentage(passengers);
    final pricePerPerson = basePrice * (1 - (discountPercentage / 100));
    return pricePerPerson * passengers;
  }

  double _getDiscountPercentage(int passengers) {
    return switch (passengers) {
      1 => discountOnePassenger,
      2 => discountTwoPassengers,
      3 => discountThreePassengers,
      4 => discountFullCar,
      _ => 0.0,
    };
  }

  double priceWithoutDiscount() => basePrice;

  static int _parseInt(Object? value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  static double _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
