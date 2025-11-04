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
