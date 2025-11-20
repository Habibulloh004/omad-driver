class DriverStats {
  const DriverStats({
    required this.dailyOrders,
    required this.dailyRevenue,
    required this.monthlyOrders,
    required this.monthlyRevenue,
    required this.totalOrders,
    required this.totalRevenue,
    required this.currentBalance,
    required this.rating,
  });

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    double parseNumeric(Object? value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0;
    }

    int parseInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    return DriverStats(
      dailyOrders: parseInt(json['daily_orders']),
      dailyRevenue: parseNumeric(json['daily_revenue']),
      monthlyOrders: parseInt(json['monthly_orders']),
      monthlyRevenue: parseNumeric(json['monthly_revenue']),
      totalOrders: parseInt(json['total_orders']),
      totalRevenue: parseNumeric(json['total_revenue']),
      currentBalance: parseNumeric(json['current_balance']),
      rating: parseNumeric(json['rating']),
    );
  }

  final int dailyOrders;
  final double dailyRevenue;
  final int monthlyOrders;
  final double monthlyRevenue;
  final int totalOrders;
  final double totalRevenue;
  final double currentBalance;
  final double rating;

  DriverStats copyWith({
    int? dailyOrders,
    double? dailyRevenue,
    int? monthlyOrders,
    double? monthlyRevenue,
    int? totalOrders,
    double? totalRevenue,
    double? currentBalance,
    double? rating,
  }) {
    return DriverStats(
      dailyOrders: dailyOrders ?? this.dailyOrders,
      dailyRevenue: dailyRevenue ?? this.dailyRevenue,
      monthlyOrders: monthlyOrders ?? this.monthlyOrders,
      monthlyRevenue: monthlyRevenue ?? this.monthlyRevenue,
      totalOrders: totalOrders ?? this.totalOrders,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      currentBalance: currentBalance ?? this.currentBalance,
      rating: rating ?? this.rating,
    );
  }
}
