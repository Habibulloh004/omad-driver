class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.carModel,
    required this.carNumber,
    required this.licensePhotoUrl,
    required this.rating,
    required this.balance,
    required this.isBlocked,
    required this.createdAt,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    double parseDouble(Object? value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int parseInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime? parseDate(Object? value) {
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '');
    }

    return DriverProfile(
      id: parseInt(json['id']),
      userId: parseInt(json['user_id']),
      fullName: (json['full_name'] ?? json['name'] ?? '').toString(),
      carModel: (json['car_model'] ?? '').toString(),
      carNumber: (json['car_number'] ?? '').toString(),
      licensePhotoUrl: (json['license_photo'] ?? '').toString(),
      rating: parseDouble(json['rating']),
      balance: parseDouble(
        json['balance'] ?? json['driver_balance'] ?? json['wallet_balance'],
      ),
      isBlocked: json['is_blocked'] == true,
      createdAt: parseDate(json['created_at']),
    );
  }

  final int id;
  final int userId;
  final String fullName;
  final String carModel;
  final String carNumber;
  final String licensePhotoUrl;
  final double rating;
  final double balance;
  final bool isBlocked;
  final DateTime? createdAt;

  DriverProfile copyWith({
    String? fullName,
    String? carModel,
    String? carNumber,
    String? licensePhotoUrl,
    double? rating,
    double? balance,
    bool? isBlocked,
    DateTime? createdAt,
  }) {
    return DriverProfile(
      id: id,
      userId: userId,
      fullName: fullName ?? this.fullName,
      carModel: carModel ?? this.carModel,
      carNumber: carNumber ?? this.carNumber,
      licensePhotoUrl: licensePhotoUrl ?? this.licensePhotoUrl,
      rating: rating ?? this.rating,
      balance: balance ?? this.balance,
      isBlocked: isBlocked ?? this.isBlocked,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
