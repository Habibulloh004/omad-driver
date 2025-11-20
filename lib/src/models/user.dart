class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.avatarUrl,
    required this.rating,
    required this.language,
    required this.role,
    this.isDriver = false,
    this.driverApproved = false,
    this.balance = 0,
  });

  factory AppUser.empty() {
    return AppUser(
      id: '',
      fullName: '',
      phoneNumber: '',
      avatarUrl: '',
      rating: 0,
      language: 'uz_latin',
      role: 'user',
      isDriver: false,
      driverApproved: false,
      balance: 0,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final dynamic roleValue = json['role'];
    final dynamic avatarValue =
        json['avatar'] ?? json['avatar_url'] ?? json['profile_picture'];
    final dynamic ratingValue = json['rating'];
    final dynamic balanceValue =
        json['balance'] ??
        json['wallet_balance'] ??
        json['driver_balance'] ??
        json['driver_balance_amount'];

    final role = roleValue == null ? '' : roleValue.toString().toLowerCase();
    final driverStatus = (json['driver_status'] ?? json['status'])
        ?.toString()
        .toLowerCase();
    final isDriverFlag = json['is_driver'] == true;
    final isDriver = role == 'driver' || (role.isEmpty && isDriverFlag);
    final isApproved = isDriver && driverStatus == 'approved';

    return AppUser(
      id: (json['id'] ?? '').toString(),
      fullName: (json['name'] ?? json['full_name'] ?? '').toString(),
      phoneNumber: (json['phone_number'] ?? json['telephone'] ?? '').toString(),
      avatarUrl: avatarValue == null ? '' : avatarValue.toString(),
      rating: ratingValue is num ? ratingValue.toDouble() : 0,
      language: (json['language'] ?? 'uz_latin').toString(),
      role: role.isEmpty ? 'user' : role,
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
  final String language;
  final String role;
  final bool isDriver;
  final bool driverApproved;
  final double balance;

  AppUser copyWith({
    String? fullName,
    String? avatarUrl,
    String? phoneNumber,
    String? language,
    String? role,
    bool? isDriver,
    bool? driverApproved,
    double? rating,
    double? balance,
  }) {
    final resolvedIsDriver = isDriver ?? this.isDriver;
    return AppUser(
      id: id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rating: rating ?? this.rating,
      language: language ?? this.language,
      role: role ?? this.role,
      isDriver: resolvedIsDriver,
      driverApproved: driverApproved ??
          (resolvedIsDriver ? this.driverApproved : false),
      balance: balance ?? this.balance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': fullName,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'telephone': phoneNumber,
      'avatar': avatarUrl,
      'rating': rating,
      'language': language,
      'role': role,
      'driver_status': driverApproved ? 'approved' : 'pending',
      'is_driver': isDriver,
      'balance': balance,
    };
  }
}
