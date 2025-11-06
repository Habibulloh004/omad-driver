class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.avatarUrl,
    required this.rating,
    this.isDriver = false,
    this.driverApproved = false,
    this.balance = 0,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final dynamic roleValue = json['role'];
    final dynamic avatarValue = json['avatar'];
    final dynamic ratingValue = json['rating'];
    final dynamic balanceValue =
        json['balance'] ?? json['wallet_balance'] ?? json['driver_balance'];

    final role = roleValue == null ? '' : roleValue.toString().toLowerCase();
    final driverStatus = json['driver_status'] == null
        ? ''
        : json['driver_status'].toString().toLowerCase();
    final isDriver = role == 'driver';
    final isApproved = driverStatus == 'approved';

    return AppUser(
      id: (json['id'] ?? '').toString(),
      fullName: (json['name'] ?? json['full_name'] ?? '').toString(),
      phoneNumber: (json['phone_number'] ?? '').toString(),
      avatarUrl: avatarValue == null ? '' : avatarValue.toString(),
      rating: ratingValue is num ? ratingValue.toDouble() : 0,
      isDriver: isDriver,
      driverApproved: isApproved,
      balance: balanceValue is num ? balanceValue.toDouble() : 0,
    );
  }

  final String id;
  final String fullName;
  final String phoneNumber;
  final String avatarUrl;
  final double rating;
  final bool isDriver;
  final bool driverApproved;
  final double balance;

  AppUser copyWith({
    String? fullName,
    String? avatarUrl,
    bool? isDriver,
    bool? driverApproved,
    double? rating,
    double? balance,
  }) {
    return AppUser(
      id: id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rating: rating ?? this.rating,
      isDriver: isDriver ?? this.isDriver,
      driverApproved: driverApproved ?? this.driverApproved,
      balance: balance ?? this.balance,
    );
  }
}
