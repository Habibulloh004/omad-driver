import 'dart:math';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../mock/mock_data.dart';
import '../models/app_notification.dart';
import '../models/order.dart';
import '../models/user.dart';

class AppState extends ChangeNotifier {
  AppState() {
    _currentUser = MockData.defaultUser();
    _orders = MockData.mockOrders();
    _notifications = MockData.notifications();
  }

  late AppUser _currentUser;
  late List<AppOrder> _orders;
  late List<AppNotification> _notifications;

  ThemeMode _themeMode = ThemeMode.light;
  AppLocale _locale = AppLocale.uzLatin;
  bool _isAuthenticated = false;
  bool _isDriverMode = false;
  bool _driverApplicationSubmitted = false;

  AppLocalizations get localization => AppLocalizations(_locale);
  AppUser get currentUser => _currentUser;
  ThemeMode get themeMode => _themeMode;
  Locale get locale => localization.locale;

  bool get isAuthenticated => _isAuthenticated;
  bool get isDriverMode => _isDriverMode && _currentUser.isDriver;
  bool get isDriverApproved => _currentUser.driverApproved;
  bool get driverApplicationSubmitted => _driverApplicationSubmitted;

  List<AppOrder> get activeOrders =>
      _orders.where((o) => o.status == OrderStatus.active).toList();
  List<AppOrder> get pendingOrders =>
      _orders.where((o) => o.status == OrderStatus.pending).toList();
  List<AppOrder> get historyOrders =>
      _orders.where((o) => o.status != OrderStatus.active).toList();
  List<AppNotification> get notifications => _notifications;

  Map<String, List<String>> get regions => MockData.regions;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
  }

  void switchLocale(AppLocale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }

  void login({required String phone, required String password}) {
    _isAuthenticated = true;
    notifyListeners();
  }

  void register({
    required String phone,
    required String fullName,
    required String password,
  }) {
    _currentUser = _currentUser.copyWith(fullName: fullName);
    _isAuthenticated = true;
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _isDriverMode = false;
    notifyListeners();
  }

  void updateProfile({String? name, String? avatar}) {
    _currentUser = _currentUser.copyWith(fullName: name, avatarUrl: avatar);
    notifyListeners();
  }

  void switchToDriverMode() {
    if (!_currentUser.isDriver) return;
    _isDriverMode = true;
    notifyListeners();
  }

  void switchToPassengerMode() {
    _isDriverMode = false;
    notifyListeners();
  }

  void submitDriverApplication({
    required String fullName,
    required String carModel,
    required String carNumber,
  }) {
    _driverApplicationSubmitted = true;
    _currentUser = _currentUser.copyWith(fullName: fullName);
    _notifications.insert(
      0,
      AppNotification(
        id: 'NOTIF-${DateTime.now().millisecondsSinceEpoch}',
        title: localization.tr('driverApplication'),
        message: localization.tr('notifDriverApplication'),
        timestamp: DateTime.now(),
        category: NotificationCategory.system,
      ),
    );
    notifyListeners();

    Future.delayed(const Duration(seconds: 2), () {
      _currentUser = _currentUser.copyWith(
        isDriver: true,
        driverApproved: true,
        balance: 235000,
      );
      _notifications.insert(
        0,
        AppNotification(
          id: 'NOTIF-${DateTime.now().millisecondsSinceEpoch}',
          title: localization.tr('driverDashboard'),
          message: localization.tr('notifDriverApproved'),
          timestamp: DateTime.now(),
          category: NotificationCategory.orderUpdate,
        ),
      );
      notifyListeners();
    });
  }

  void approveDriver() {
    _currentUser = _currentUser.copyWith(
      isDriver: true,
      driverApproved: true,
      balance: 235000,
    );
    notifyListeners();
  }

  void markNotificationsRead() {
    _notifications = _notifications
        .map((item) => item.copyWith(isRead: true))
        .toList(growable: false);
    notifyListeners();
  }

  void toggleNotificationRead(String id) {
    _notifications = _notifications
        .map(
          (item) => item.id == id ? item.copyWith(isRead: !item.isRead) : item,
        )
        .toList(growable: false);
    notifyListeners();
  }

  double calculateTaxiPrice({
    required String fromRegion,
    required String toRegion,
    required int passengers,
  }) {
    final basePrice = fromRegion == toRegion ? 30000 : 55000;
    final distanceMultiplier = fromRegion == toRegion ? 1.0 : 1.6;
    final passengerDiscount = switch (passengers) {
      1 => 0.90,
      2 => 0.85,
      3 => 0.80,
      _ => 0.75,
    };
    return basePrice * distanceMultiplier * passengerDiscount;
  }

  double calculateDeliveryPrice({
    required String fromRegion,
    required String toRegion,
    required String packageType,
  }) {
    final basePrice = fromRegion == toRegion ? 40000 : 70000;
    final typeMultiplier = switch (packageType) {
      'document' => 0.9,
      'box' => 1.0,
      'luggage' => 1.2,
      'valuable' => 1.4,
      _ => 1.05,
    };
    final distanceMultiplier = fromRegion == toRegion ? 1.0 : 1.5;
    return basePrice * typeMultiplier * distanceMultiplier;
  }

  AppOrder createTaxiOrder({
    required String fromRegion,
    required String fromDistrict,
    required String toRegion,
    required String toDistrict,
    required int passengers,
    required DateTime date,
    required TimeOfDay start,
    required TimeOfDay end,
    String? note,
  }) {
    final price = calculateTaxiPrice(
      fromRegion: fromRegion,
      toRegion: toRegion,
      passengers: passengers,
    );

    final order = AppOrder(
      id: _generateOrderId(),
      type: OrderType.taxi,
      fromRegion: fromRegion,
      fromDistrict: fromDistrict,
      toRegion: toRegion,
      toDistrict: toDistrict,
      passengers: passengers,
      date: date,
      startTime: start,
      endTime: end,
      price: price,
      status: OrderStatus.pending,
      note: note,
    );

    _orders = [order, ..._orders];
    notifyListeners();
    return order;
  }

  AppOrder createDeliveryOrder({
    required String fromRegion,
    required String fromDistrict,
    required String toRegion,
    required String toDistrict,
    required String packageType,
    required DateTime date,
    required TimeOfDay start,
    required TimeOfDay end,
    required String senderName,
    required String senderPhone,
    required String receiverPhone,
    String? note,
  }) {
    final price = calculateDeliveryPrice(
      fromRegion: fromRegion,
      toRegion: toRegion,
      packageType: packageType,
    );

    final order = AppOrder(
      id: _generateOrderId(),
      type: OrderType.delivery,
      fromRegion: fromRegion,
      fromDistrict: fromDistrict,
      toRegion: toRegion,
      toDistrict: toDistrict,
      passengers: 1,
      date: date,
      startTime: start,
      endTime: end,
      price: price,
      status: OrderStatus.pending,
      note: note,
    );

    _orders = [order, ..._orders];
    notifyListeners();
    return order;
  }

  void cancelOrder(String id, String reason) {
    _orders = _orders
        .map(
          (order) => order.id == id
              ? order.copyWith(status: OrderStatus.cancelled)
              : order,
        )
        .toList(growable: false);

    _notifications.insert(
      0,
      AppNotification(
        id: 'NOTIF-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Order Cancelled',
        message: reason,
        timestamp: DateTime.now(),
        category: NotificationCategory.orderUpdate,
      ),
    );
    notifyListeners();
  }

  void acceptOrder(String id) {
    _orders = _orders
        .map(
          (order) => order.id == id
              ? order.copyWith(
                  status: OrderStatus.active,
                  driverName: _currentUser.fullName,
                  driverPhone: _currentUser.phoneNumber,
                  vehicle: 'Chevrolet Equinox',
                  vehiclePlate: '01 C123 CC',
                )
              : order,
        )
        .toList(growable: false);
    notifyListeners();
  }

  void completeOrder(String id) {
    _orders = _orders
        .map(
          (order) => order.id == id
              ? order.copyWith(status: OrderStatus.completed)
              : order,
        )
        .toList(growable: false);
    _currentUser = _currentUser.copyWith(balance: _currentUser.balance + 85000);
    notifyListeners();
  }

  String _generateOrderId() {
    final random = Random();
    final code = random.nextInt(900) + 100;
    return 'ORD-${DateTime.now().year}-$code';
  }
}
