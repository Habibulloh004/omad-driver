import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/auth_api.dart';
import '../core/backend_config.dart';
import '../core/realtime_gateway.dart';
import '../localization/app_localizations.dart';
import '../models/app_notification.dart';
import '../models/driver_profile.dart';
import '../models/driver_stats.dart';
import '../models/location.dart';
import '../models/pricing.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../storage/session_storage.dart';

class AppState extends ChangeNotifier {
  AppState({ApiClient? apiClient, RealtimeGateway? realtime})
    : _api = apiClient ?? ApiClient(),
      _realtime = realtime ?? RealtimeGateway(baseUrl: backendBaseUrl) {
    _realtime.setHandlers(
      onUserEvent: _handleUserRealtimeEvent,
      onDriverEvent: _handleDriverRealtimeEvent,
    );
    _init();
  }

  static const Duration _sessionTTL = Duration(days: 7);
  static const Duration _driverOrderFreshnessWindow = Duration(minutes: 5);
  static const Duration _serverTimeOffset = Duration(hours: 5);
  static const Set<String> _driverEligibleRoles = {
    'driver',
    'admin',
    'superadmin',
  };
  static const String _uploadsOrigin = backendBaseUrl;

  final ApiClient _api;
  final RealtimeGateway _realtime;
  SessionStorage? _sessionStorage;

  AppUser _currentUser = AppUser.empty();
  List<AppOrder> _orders = <AppOrder>[];
  List<AppNotification> _notifications = <AppNotification>[];
  List<RegionModel> _regions = <RegionModel>[];
  final Map<int, RegionModel> _regionById = <int, RegionModel>{};
  final Map<int, DistrictModel> _districtById = <int, DistrictModel>{};
  final Map<String, PricingModel> _pricingByRoute = <String, PricingModel>{};
  List<AppOrder> _driverAvailableOrders = <AppOrder>[];
  List<AppOrder> _driverActiveOrders = <AppOrder>[];
  List<AppOrder> _driverCompletedOrders = <AppOrder>[];
  DriverStats? _driverStats;
  DriverProfile? _driverProfile;
  final Queue<({String title, String message})> _userRealtimeMessages =
      Queue<({String title, String message})>();
  final Queue<({String title, String message})> _driverRealtimeMessages =
      Queue<({String title, String message})>();

  ThemeMode _themeMode = ThemeMode.light;
  AppLocale _locale = AppLocale.uzLatin;
  bool _isAuthenticated = false;
  bool _isDriverMode = false;
  bool _driverApplicationSubmitted = false;
  bool _bootstrapping = true;
  bool _driverContextLoading = false;
  String? _authToken;
  int? _driverProfileId;
  int _notificationSignal = 0;
  String? _lastDriverStatusEventId;

  AppLocalizations get localization => AppLocalizations(_locale);
  AppUser get currentUser => _currentUser;
  ThemeMode get themeMode => _themeMode;
  Locale get locale => localization.locale;
  bool get isAuthenticated => _isAuthenticated;
  bool get isDriverMode => _isDriverMode && _currentUser.isDriver;
  bool get isDriverApproved => _currentUser.driverApproved;
  bool get driverApplicationSubmitted => _driverApplicationSubmitted;
  bool get isBootstrapping => _bootstrapping;
  String? get authToken => _authToken;

  List<AppOrder> get activeOrders => _ordersForCurrentUser()
      .where(
        (order) =>
            order.status == OrderStatus.active ||
            order.status == OrderStatus.pending,
      )
      .toList();
  List<AppOrder> get pendingOrders => _ordersForCurrentUser()
      .where((order) => order.status == OrderStatus.pending)
      .toList();
  List<AppOrder> get historyOrders => _ordersForCurrentUser()
      .where(
        (order) =>
            order.status == OrderStatus.completed ||
            order.status == OrderStatus.cancelled,
      )
      .toList();
  List<AppNotification> get notifications =>
      List<AppNotification>.unmodifiable(_notifications);
  int get notificationSignal => _notificationSignal;
  int get unreadNotificationsCount =>
      _notifications.where((item) => !item.isRead).length;
  List<AppOrder> get driverAvailableOrders =>
      List<AppOrder>.unmodifiable(_driverAvailableOrders);
  List<AppOrder> get driverActiveOrders =>
      List<AppOrder>.unmodifiable(_driverActiveOrders);
  List<AppOrder> get driverCompletedOrders =>
      List<AppOrder>.unmodifiable(_driverCompletedOrders);
  DriverStats? get driverStats => _driverStats;
  DriverProfile? get driverProfile => _driverProfile;
  bool get isDriverContextLoading => _driverContextLoading;
  ({String title, String message})? takeNextUserRealtimeMessage() {
    if (_userRealtimeMessages.isEmpty) return null;
    return _userRealtimeMessages.removeFirst();
  }

  ({String title, String message})? takeNextDriverRealtimeMessage() {
    if (_driverRealtimeMessages.isEmpty) return null;
    return _driverRealtimeMessages.removeFirst();
  }

  Map<String, List<String>> get regions {
    final result = <String, List<String>>{};
    for (final region in _regions) {
      final regionName = _regionDisplayName(region);
      result[regionName] = region.districts
          .map(_districtDisplayName)
          .toList(growable: false);
    }
    return result;
  }

  Iterable<AppOrder> _ordersForCurrentUser() sync* {
    final currentId = _currentUser.id.trim();
    for (final order in _orders) {
      final ownerId = order.ownerId.trim();
      if (currentId.isEmpty || ownerId.isEmpty || ownerId == currentId) {
        yield order;
      }
    }
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
  }

  Future<void> switchLocale(AppLocale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    _localizeOrders();
    notifyListeners();

    if (_isAuthenticated) {
      final languageCode = _languageCodeForLocale(locale);
      try {
        await _api.updateProfile(language: languageCode);
        _currentUser = _currentUser.copyWith(language: languageCode);
        await _saveSessionSnapshot();
        _syncLocaleFromUser(_currentUser.language);
        notifyListeners();
      } on ApiException {
        // Ignore backend failures; locale already updated locally.
      }
    }
  }

  Future<void> login({required String phone, required String password}) async {
    final session = await _api.login(
      phoneNumber: phone.trim(),
      password: password,
    );
    await _onAuthenticated(session);
  }

  Future<void> register({
    required String phone,
    required String fullName,
    required String password,
    required String confirmPassword,
  }) async {
    final session = await _api.register(
      phoneNumber: phone.trim(),
      password: password,
      confirmPassword: confirmPassword,
      fullName: fullName.trim(),
    );
    await _onAuthenticated(session);
  }

  Future<void> refreshProfile() async {
    if (!_isAuthenticated) return;
    final profile = await _api.fetchProfile();
    var nextUser = _hydrateUser(profile);
    final roleAllowsDriver = _roleAllowsDriverPrivileges(nextUser.role);
    if (!roleAllowsDriver) {
      _driverProfile = null;
      nextUser = nextUser.copyWith(isDriver: false, driverApproved: false);
    } else if (_driverProfile != null) {
      nextUser = nextUser.copyWith(
        isDriver: true,
        driverApproved: true,
        rating: _driverProfile!.rating,
        balance: _driverProfile!.balance,
      );
    }
    _currentUser = nextUser;
    _isDriverMode = _isDriverMode && _currentUser.isDriver;
    _syncLocaleFromUser(_currentUser.language);
    await _saveSessionSnapshot();
    notifyListeners();
  }

  Future<void> refreshOrders() async {
    if (!_isAuthenticated) return;
    if (_regions.isEmpty) {
      await loadRegions(force: true);
    }
    final data = await _api.fetchUserOrders();
    final orders = data
        .map(
          (json) => AppOrder.fromJson(
            json,
            resolveRegionName: _regionDisplayNameById,
            resolveDistrictName: _districtDisplayNameById,
          ),
        )
        .toList();
    orders.sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      return _timeOfDayToMinutes(
        b.startTime,
      ).compareTo(_timeOfDayToMinutes(a.startTime));
    });
    _orders = orders;
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    if (!_isAuthenticated) return;
    final data = await _api.fetchNotifications();
    final items = data.map(AppNotification.fromJson).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final previousIds = _notifications.map((item) => item.id).toSet();
    final hasNew = items.any((item) => !previousIds.contains(item.id));
    _notifications = items;
    if (hasNew) {
      _bumpNotificationSignal();
    }
    notifyListeners();
  }

  Future<void> refreshDriverStatus({bool loadDashboard = false}) async {
    await _syncDriverContext(loadDashboard: loadDashboard);
    notifyListeners();
  }

  Future<void> loadRegions({bool force = false}) async {
    if (!force && _regions.isNotEmpty) return;
    final regionMaps = await _api.fetchRegions();
    final regions = regionMaps.map(RegionModel.fromJson).toList();
    final districtFutures = regions
        .map(
          (region) => region.districts.isNotEmpty
              ? Future.value(region.districts)
              : _api
                    .fetchDistricts(region.id)
                    .then(
                      (items) => items.map(DistrictModel.fromJson).toList(),
                    ),
        )
        .toList();
    final districtLists = await Future.wait(districtFutures);

    final updatedRegions = <RegionModel>[];
    _regionById.clear();
    _districtById.clear();

    for (var i = 0; i < regions.length; i++) {
      final region = regions[i].copyWith(districts: districtLists[i]);
      updatedRegions.add(region);
      _regionById[region.id] = region;
      for (final district in region.districts) {
        _districtById[district.id] = district;
      }
    }
    _regions = updatedRegions;
    _localizeOrders();
    await _loadPricing(force: force);
    notifyListeners();
  }

  Future<AppOrder> createTaxiOrder({
    required String fromRegion,
    required String fromDistrict,
    required String toRegion,
    required String toDistrict,
    required int passengers,
    required DateTime scheduledDate,
    required TimeOfDay scheduledTime,
    required PickupLocation pickupLocation,
    String? note,
  }) async {
    final fromRegionId = _regionIdByName(fromRegion);
    final toRegionId = _regionIdByName(toRegion);
    if (fromRegionId == null || toRegionId == null) {
      throw const ApiException('Region not found', statusCode: 400);
    }
    final fromDistrictId = _districtIdByName(fromRegionId, fromDistrict);
    final toDistrictId = _districtIdByName(toRegionId, toDistrict);
    if (fromDistrictId == null || toDistrictId == null) {
      throw const ApiException('District not found', statusCode: 400);
    }
    if (fromRegionId == toRegionId) {
      throw const ApiException(
        'Pickup and destination regions must differ',
        statusCode: 400,
      );
    }

    final scheduled = _combineDateTime(scheduledDate, scheduledTime);
    if (scheduled == null) {
      throw const ApiException('Invalid scheduled time', statusCode: 400);
    }
    final normalizedTelephone = _preparePhoneNumber(_currentUser.phoneNumber);
    final body = <String, dynamic>{
      'username': _currentUser.fullName,
      'telephone': normalizedTelephone.toString(),
      'from_region_id': fromRegionId,
      'from_district_id': fromDistrictId,
      'to_region_id': toRegionId,
      'to_district_id': toDistrictId,
      'pickup_latitude': _stringifyCoordinate(pickupLocation.latitude),
      'pickup_longitude': _stringifyCoordinate(pickupLocation.longitude),
      'pickup_address': pickupLocation.address,
      'passengers': passengers,
      'date': "",
      'time_start': "",
      'time_end': "",
      'scheduled_datetime': scheduled.toUtc().toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };

    final response = await _api.createTaxiOrder(body);
    final order = AppOrder.fromJson(
      response,
      resolveRegionName: _regionDisplayNameById,
      resolveDistrictName: _districtDisplayNameById,
      fallbackType: OrderType.taxi,
    );
    _orders = [order, ..._orders];
    notifyListeners();
    return order;
  }

  Future<AppOrder> createDeliveryOrder({
    required String fromRegion,
    required String fromDistrict,
    required String toRegion,
    required String toDistrict,
    required String packageType,
    required DateTime scheduledDate,
    required TimeOfDay scheduledTime,
    required String senderName,
    required String senderPhone,
    required String receiverPhone,
    required PickupLocation pickupLocation,
    required PickupLocation dropoffLocation,
    String? note,
  }) async {
    final fromRegionId = _regionIdByName(fromRegion);
    final toRegionId = _regionIdByName(toRegion);
    if (fromRegionId == null || toRegionId == null) {
      throw const ApiException('Region not found', statusCode: 400);
    }
    final fromDistrictId = _districtIdByName(fromRegionId, fromDistrict);
    final toDistrictId = _districtIdByName(toRegionId, toDistrict);
    if (fromDistrictId == null || toDistrictId == null) {
      throw const ApiException('District not found', statusCode: 400);
    }
    if (fromRegionId == toRegionId) {
      throw const ApiException(
        'Pickup and destination regions must differ',
        statusCode: 400,
      );
    }

    final scheduled = _combineDateTime(scheduledDate, scheduledTime);
    if (scheduled == null) {
      throw const ApiException('Invalid scheduled time', statusCode: 400);
    }
    final normalizedSenderPhone = _preparePhoneNumber(senderPhone);
    final normalizedReceiverPhone = _preparePhoneNumber(receiverPhone);

    final body = <String, dynamic>{
      'username': senderName.toString(),
      'sender_telephone': normalizedSenderPhone.toString(),
      'receiver_telephone': normalizedReceiverPhone.toString(),
      'item_type': packageType.toString(),
      'date': "",
      'time_start': "",
      'time_end': "",
      'from_region_id': fromRegionId,
      'from_district_id': fromDistrictId,
      'to_region_id': toRegionId,
      'to_district_id': toDistrictId,
      'scheduled_datetime': scheduled.toUtc().toIso8601String(),
      'pickup_latitude': _stringifyCoordinate(pickupLocation.latitude),
      'pickup_longitude': _stringifyCoordinate(pickupLocation.longitude),
      'pickup_address': pickupLocation.address.toString(),
      'dropoff_latitude': _stringifyCoordinate(dropoffLocation.latitude),
      'dropoff_longitude': _stringifyCoordinate(dropoffLocation.longitude),
      'dropoff_address': dropoffLocation.address.toString(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    debugPrint(
      '[DeliveryOrder] sending payload -> ${const JsonEncoder.withIndent('  ').convert(body)}',
    );

    final response = await _api.createDeliveryOrder(body);
    debugPrint(
      '[DeliveryOrder] response <- ${const JsonEncoder.withIndent('  ').convert(response)}',
    );
    final order = AppOrder.fromJson(
      response,
      resolveRegionName: _regionDisplayNameById,
      resolveDistrictName: _districtDisplayNameById,
      fallbackType: OrderType.delivery,
    );
    _orders = [order, ..._orders];
    notifyListeners();
    return order;
  }

  Future<void> cancelOrder(String id, String reason) async {
    final orderId = int.tryParse(id);
    if (orderId == null) {
      throw const ApiException('Invalid order id', statusCode: 400);
    }
    final targetOrder = _orders.firstWhere(
      (item) => item.id == id,
      orElse: () =>
          throw const ApiException('Order not found', statusCode: 404),
    );
    await _api.cancelOrder(
      id: orderId,
      orderType: targetOrder.type,
      reason: reason,
    );
    _orders = _orders
        .map(
          (order) => order.id == id
              ? order.copyWith(
                  status: OrderStatus.cancelled,
                  cancelReason: reason,
                )
              : order,
        )
        .toList();
    notifyListeners();
  }

  Future<void> markNotificationsRead() async {
    final unread = _notifications.where((item) => !item.isRead).toList();
    if (unread.isEmpty) return;
    _notifications = _notifications
        .map((item) => item.isRead ? item : item.markRead())
        .toList();
    notifyListeners();

    for (final notification in unread) {
      final id = int.tryParse(notification.id);
      if (id == null) continue;
      try {
        await _api.markNotificationRead(id);
      } on ApiException {
        // Ignore individual failures.
      }
    }
  }

  Future<void> toggleNotificationRead(String id) async {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final notification = _notifications[index];
    if (notification.isRead) {
      _notifications[index] = notification.copyWith(isRead: false);
      notifyListeners();
      return;
    }
    _notifications[index] = notification.markRead();
    notifyListeners();

    final numericId = int.tryParse(id);
    if (numericId == null) return;
    try {
      await _api.markNotificationRead(numericId);
    } on ApiException {
      // Ignore failure; remain marked as read locally.
    }
  }

  double? calculateTaxiPrice({
    required String fromRegion,
    required String toRegion,
    required int passengers,
  }) {
    final fromRegionId = _regionIdByName(fromRegion);
    final toRegionId = _regionIdByName(toRegion);
    if (fromRegionId == null || toRegionId == null) {
      return null;
    }
    final pricing = _findPricingEntry(fromRegionId, toRegionId, 'taxi');
    if (pricing == null) {
      return null;
    }
    return pricing.priceForPassengers(passengers);
  }

  double? calculateDeliveryPrice({
    required String fromRegion,
    required String toRegion,
    required String packageType,
  }) {
    final fromRegionId = _regionIdByName(fromRegion);
    final toRegionId = _regionIdByName(toRegion);
    if (fromRegionId == null || toRegionId == null) {
      return null;
    }
    final pricing = _findPricingEntry(fromRegionId, toRegionId, 'delivery');
    if (pricing == null) {
      return null;
    }
    return pricing.priceWithoutDiscount();
  }

  Future<void> updateProfile({String? name}) async {
    final trimmedName = name?.trim();
    final shouldUpdateName =
        trimmedName != null &&
        trimmedName.isNotEmpty &&
        trimmedName != _currentUser.fullName;

    if (shouldUpdateName) {
      await _api.updateProfile(name: trimmedName);
      _currentUser = _currentUser.copyWith(fullName: trimmedName);
    }

    await _saveSessionSnapshot();
    notifyListeners();
  }

  Future<void> uploadProfilePicture(File file) async {
    final response = await _api.uploadProfilePicture(file);
    final uploadedPath = response['file_path']?.toString() ?? '';
    if (uploadedPath.isEmpty) {
      return;
    }
    _currentUser = _currentUser.copyWith(
      avatarUrl: _resolveAssetUrl(uploadedPath),
    );
    await _saveSessionSnapshot();
    notifyListeners();
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _api.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }

  Future<void> logout() async {
    await _ensureStorage();
    await _sessionStorage?.clear();
    _authToken = null;
    _api.updateToken(null);
    _isAuthenticated = false;
    _isDriverMode = false;
    _driverApplicationSubmitted = false;
    _currentUser = AppUser.empty();
    _orders = <AppOrder>[];
    _notifications = <AppNotification>[];
    _driverAvailableOrders = <AppOrder>[];
    _driverActiveOrders = <AppOrder>[];
    _driverCompletedOrders = <AppOrder>[];
    _driverStats = null;
    _driverProfile = null;
    _driverContextLoading = false;
    _bootstrapping = false;
    _driverProfileId = null;
    _lastDriverStatusEventId = null;
    _refreshRealtimeConnections();
    notifyListeners();
  }

  void switchToDriverMode() {
    if (!_currentUser.isDriver || _isDriverMode) return;
    _isDriverMode = true;
    notifyListeners();
  }

  void switchToPassengerMode() {
    if (!_isDriverMode) return;
    _isDriverMode = false;
    notifyListeners();
  }

  Future<void> submitDriverApplication({
    required String fullName,
    required String carModel,
    required String carNumber,
    required File licenseFile,
  }) async {
    final upload = await _api.uploadDriverLicense(licenseFile);
    final uploadedPath = upload['file_path']?.toString() ?? '';
    if (uploadedPath.isEmpty) {
      throw const ApiException(
        'Failed to upload license photo',
        statusCode: 400,
      );
    }
    await _api.submitDriverApplication(
      fullName: fullName.trim(),
      carModel: carModel.trim(),
      carNumber: carNumber.trim(),
      licensePath: uploadedPath,
    );
    _driverApplicationSubmitted = true;
    _currentUser = _currentUser.copyWith(fullName: fullName.trim());
    await _saveSessionSnapshot();
    notifyListeners();
  }

  Future<void> refreshDriverDashboard({bool force = false}) async {
    if (!_currentUser.isDriver || !_currentUser.driverApproved) return;
    if (_driverContextLoading && !force) return;
    if (_regions.isEmpty) {
      await loadRegions(force: true);
    }
    _driverContextLoading = true;
    notifyListeners();
    try {
      final dashboardData = await Future.wait([
        _loadDriverStatistics(),
        _loadDriverNewOrders(),
        _loadDriverActiveOrders(),
      ]);
      final stats = dashboardData[0] as DriverStats;
      final pending = dashboardData[1] as List<AppOrder>;
      final active = dashboardData[2] as List<AppOrder>;
      _driverStats = stats;
      _currentUser = _currentUser.copyWith(
        balance: stats.currentBalance,
        rating: stats.rating,
        isDriver: true,
        driverApproved: true,
      );
      if (_driverProfile != null) {
        _driverProfile = _driverProfile!.copyWith(
          balance: stats.currentBalance,
          rating: stats.rating,
        );
      }
      _driverAvailableOrders = pending;
      _pruneExpiredDriverOrders();
      _driverActiveOrders = active;
      await _saveSessionSnapshot();
    } finally {
      _driverContextLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptDriverOrder(AppOrder order) async {
    if (!_currentUser.isDriver || !_currentUser.driverApproved) {
      throw const ApiException(
        'Driver account not approved yet',
        statusCode: 403,
      );
    }
    final numericId = int.tryParse(order.id);
    if (numericId == null) {
      throw const ApiException('Invalid order id', statusCode: 400);
    }
    await _api.acceptDriverOrder(id: numericId, type: order.type);
    _driverAvailableOrders = _driverAvailableOrders
        .where((item) => item.id != order.id)
        .toList();

    AppOrder accepted = order.copyWith(status: OrderStatus.active);
    try {
      final details = await _api.fetchOrder(id: numericId, type: order.type);
      accepted = AppOrder.fromJson(
        details,
        resolveRegionName: _regionDisplayNameById,
        resolveDistrictName: _districtDisplayNameById,
        fallbackType: order.type,
      );
    } on ApiException {
      // Ignore detail fetch errors; proceed with basic data.
    }
    _driverActiveOrders = [
      accepted.copyWith(status: OrderStatus.active),
      ..._driverActiveOrders.where((item) => item.id != accepted.id),
    ];
    _mergePassengerOrderFromDriverContext(
      accepted.copyWith(status: OrderStatus.active),
    );
    await _refreshDriverStatsOnly();
    notifyListeners();
  }

  Future<void> completeDriverOrder(AppOrder order) async {
    if (!_currentUser.isDriver || !_currentUser.driverApproved) {
      throw const ApiException(
        'Driver account not approved yet',
        statusCode: 403,
      );
    }
    final numericId = int.tryParse(order.id);
    if (numericId == null) {
      throw const ApiException('Invalid order id', statusCode: 400);
    }
    await _api.completeDriverOrder(id: numericId, type: order.type);
    _driverActiveOrders = _driverActiveOrders
        .where((item) => item.id != order.id)
        .toList();

    AppOrder completed = order.copyWith(status: OrderStatus.completed);
    try {
      final details = await _api.fetchOrder(id: numericId, type: order.type);
      completed = AppOrder.fromJson(
        details,
        resolveRegionName: _regionDisplayNameById,
        resolveDistrictName: _districtDisplayNameById,
        fallbackType: order.type,
      );
    } on ApiException {
      // Ignore detail fetch errors; use local data.
    }

    _driverCompletedOrders = <AppOrder>[
      completed.copyWith(status: OrderStatus.completed),
      ..._driverCompletedOrders,
    ].take(20).toList();
    _mergePassengerOrderFromDriverContext(
      completed.copyWith(status: OrderStatus.completed),
    );
    await _refreshDriverStatsOnly();
    notifyListeners();
  }

  Future<void> acceptOrder(String id) async {
    _orders = _orders
        .map(
          (order) => order.id == id
              ? order.copyWith(status: OrderStatus.active)
              : order,
        )
        .toList();
    notifyListeners();
  }

  Future<void> completeOrder(String id) async {
    _orders = _orders
        .map(
          (order) => order.id == id
              ? order.copyWith(status: OrderStatus.completed)
              : order,
        )
        .toList();
    notifyListeners();
  }

  Future<void> _onAuthenticated(AuthSession session) async {
    _authToken = session.token;
    _api.updateToken(_authToken);
    _currentUser = _hydrateUser(session.user);
    _isAuthenticated = true;
    _isDriverMode = session.user.isDriver;
    _driverApplicationSubmitted = false;
    await _saveSessionSnapshot(refreshTimestamp: true);
    _refreshRealtimeConnections();
    notifyListeners();
    await _bootstrapAfterAuth();
  }

  Future<void> _bootstrapAfterAuth() async {
    _bootstrapping = true;
    notifyListeners();
    try {
      await loadRegions(force: true);
      await Future.wait([
        refreshProfile(),
        refreshOrders(),
        refreshNotifications(),
      ]);
      await _syncDriverContext(loadDashboard: true);
    } finally {
      _bootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> _handleUserRealtimeEvent(Map<String, dynamic> payload) async {
    if (!_isAuthenticated) return;
    final eventType = _eventTypeFromPayload(payload);
    if (eventType == null || eventType.isEmpty) return;
    _logRealtime('user', 'event=$eventType payload=${jsonEncode(payload)}');
    switch (eventType) {
      case 'active_orders_snapshot':
        await _handlePassengerActiveOrdersSnapshot(payload);
        break;
      case 'order_status':
        final resolvedStatus = _resolveRealtimeStatus(payload);
        if (resolvedStatus != null) {
          await _handlePassengerOrderStatusPush(payload, resolvedStatus);
        }
        break;
      case 'order_accepted':
        await _handlePassengerOrderStatusPush(payload, OrderStatus.active);
        break;
      case 'order_completed':
        await _handlePassengerOrderStatusPush(payload, OrderStatus.completed);
        break;
      case 'driver_status':
        await _handleDriverStatusPush(payload);
        break;
      case 'notification':
      case 'notification_created':
      case 'notification_event':
        _handleRealtimeNotification(payload);
        break;
      default:
        break;
    }
  }

  Future<void> _handlePassengerOrderStatusPush(
    Map<String, dynamic> payload,
    OrderStatus status,
  ) async {
    final orderId = _stringify(payload['order_id']);
    if (orderId.isEmpty) return;
    if (!_payloadTargetsCurrentUser(payload)) {
      _logRealtime(
        'user',
        'order_status ignored orderId=$orderId user_id=${payload['user_id']}',
      );
      return;
    }
    final orderType = _orderTypeFromPayload(payload['order_type']);
    final driverInfo = status == OrderStatus.active
        ? _extractDriverInfo(payload['driver'])
        : null;
    final updated = _applyUserOrderStatus(
      payload,
      status,
      driverInfo: driverInfo,
    );

    final eventLabel = switch (status) {
      OrderStatus.active => 'order_accepted',
      OrderStatus.completed => 'order_completed',
      OrderStatus.cancelled => 'order_cancelled',
      _ => 'order_status',
    };

    _logRealtime('user', '$eventLabel orderId=$orderId localUpdated=$updated');

    if (!updated) {
      _logRealtime(
        'user',
        '$eventLabel orderId=$orderId local_miss=true -> syncing',
      );
      await _syncPassengerOrderOrRefresh(
        orderId: orderId,
        orderType: orderType,
      );
      unawaited(refreshNotifications());
    } else {
      _logRealtime(
        'user',
        '$eventLabel orderId=$orderId schedule background sync',
      );
      unawaited(
        _syncPassengerOrderOrRefresh(orderId: orderId, orderType: orderType),
      );
      unawaited(refreshNotifications());
    }

    String? toastTitle;
    String? toastDetails;
    switch (status) {
      case OrderStatus.active:
        toastTitle = localization.tr('orderAccepted');
        toastDetails = driverInfo?.name;
        break;
      case OrderStatus.completed:
        toastTitle = localization.tr('orderCompleted');
        break;
      default:
        break;
    }
    if (toastTitle != null) {
      _announceUserOrderEvent(
        title: toastTitle,
        orderId: orderId,
        details: toastDetails,
      );
    }
  }

  Future<void> _handlePassengerActiveOrdersSnapshot(
    Map<String, dynamic> payload,
  ) async {
    if (!_payloadTargetsCurrentUser(payload)) {
      return;
    }

    final rawOrders = payload['orders'];
    if (rawOrders is! List) {
      _logRealtime('user', 'orders_snapshot ignored invalid payload');
      return;
    }

    var changed = false;
    for (final entry in rawOrders) {
      if (entry is! Map) continue;
      final data = Map<String, dynamic>.from(entry);
      final fallbackType = _orderTypeFromPayload(
        data['order_type'] ?? data['type'],
      );
      final order = AppOrder.fromJson(
        data,
        resolveRegionName: _regionDisplayNameById,
        resolveDistrictName: _districtDisplayNameById,
        fallbackType: fallbackType,
      );
      if (_mergePassengerOrderFromDriverContext(order)) {
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
      _logRealtime('user', 'orders_snapshot applied count=${rawOrders.length}');
      unawaited(refreshNotifications());
    } else {
      _logRealtime(
        'user',
        'orders_snapshot no_local_change count=${rawOrders.length}',
      );
    }
  }

  void _handleRealtimeNotification(
    Map<String, dynamic> payload, {
    bool enforceUserCheck = true,
    bool announce = true,
  }) {
    if (enforceUserCheck && !_payloadTargetsCurrentUser(payload)) {
      return;
    }
    final data = _extractNotificationPayload(payload);
    if (data == null) return;

    final rawType = (data['notification_type'] ?? data['type'])
        ?.toString()
        .toLowerCase();
    final isDriverApplicationUpdate =
        rawType == 'application_approved' || rawType == 'application_rejected';

    final notification = AppNotification.fromJson(data);
    final existing = _notifications.any((item) => item.id == notification.id);
    final updatedList = [
      notification,
      ..._notifications.where((item) => item.id != notification.id),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _notifications = updatedList;
    if (!existing) {
      _bumpNotificationSignal();
    }
    notifyListeners();

    if (isDriverApplicationUpdate) {
      unawaited(
        refreshDriverStatus(loadDashboard: rawType == 'application_approved'),
      );
    }

    if (announce && !existing) {
      _enqueueUserRealtimeMessage(
        title: notification.title,
        message: notification.message,
      );
    }
  }

  Future<void> _handleDriverRealtimeEvent(Map<String, dynamic> payload) async {
    if (!_isAuthenticated || !_currentUser.isDriver) return;
    final eventType = _eventTypeFromPayload(payload);
    if (eventType == null || eventType.isEmpty) return;
    _logRealtime('driver', 'event=$eventType payload=${jsonEncode(payload)}');

    switch (eventType) {
      case 'new_order':
        final orderPayload = payload['order'];
        Map<String, dynamic>? orderMap;
        if (orderPayload is Map<String, dynamic>) {
          orderMap = orderPayload;
        } else if (orderPayload is Map) {
          orderMap = Map<String, dynamic>.from(orderPayload);
        }
        if (orderMap != null) {
          final orderType = _orderTypeFromPayload(orderMap['type']);
          final mapped = _driverOrderFromMap(orderMap, orderType);
          if (mapped != null) {
            _upsertDriverPendingOrder(mapped);
            _announceDriverNewOrder(mapped);
            _logRealtime(
              'driver',
              'new_order mapped id=${mapped.id} status=${mapped.status.name}',
            );
          }
        }
        break;
      case 'order_accepted':
        _logRealtime('driver', 'order_accepted forwarding to handler');
        await _handleDriverOrderAcceptedEvent(payload);
        break;
      case 'order_completed':
        _logRealtime('driver', 'order_completed forwarding to handler');
        await _handleDriverOrderCompletedEvent(payload);
        break;
      case 'order_cancelled':
        _logRealtime('driver', 'order_cancelled forwarding to handler');
        await _handleDriverOrderCancelledEvent(payload);
        break;
      case 'driver_status':
        _logRealtime('driver', 'driver_status forwarding to handler');
        await _handleDriverStatusPush(payload);
        break;
      case 'notification':
      case 'notification_created':
      case 'notification_event':
        _handleRealtimeNotification(
          payload,
          enforceUserCheck: false,
          announce: true,
        );
        break;
      default:
        break;
    }
  }

  void _logRealtime(String scope, String message) {
    assert(() {
      debugPrint('[Realtime][$scope] $message');
      return true;
    }());
  }

  void _announceUserOrderEvent({
    required String title,
    required String orderId,
    String? details,
  }) {
    if (orderId.isEmpty) return;
    final idLabel = localization
        .tr('orderIdLabel')
        .replaceFirst('{id}', orderId);
    final message = details == null || details.isEmpty
        ? idLabel
        : '$idLabel - $details';
    _enqueueUserRealtimeMessage(title: title, message: message);
    _prependRealtimeNotification(title, message);
  }

  void _announceDriverNewOrder(AppOrder order) {
    final title = order.isDelivery
        ? localization.tr('deliveryOrder')
        : localization.tr('taxiOrder');
    final message = '${order.fromRegion} -> ${order.toRegion}';
    _enqueueDriverRealtimeMessage(title: title, message: message);
    _prependRealtimeNotification(title, message);
  }

  void _enqueueUserRealtimeMessage({
    required String title,
    required String message,
  }) {
    if (title.isEmpty && message.isEmpty) return;
    _userRealtimeMessages.add((title: title, message: message));
    notifyListeners();
  }

  void _enqueueDriverRealtimeMessage({
    required String title,
    required String message,
  }) {
    if (title.isEmpty && message.isEmpty) return;
    _driverRealtimeMessages.add((title: title, message: message));
    notifyListeners();
  }

  void _upsertDriverPendingOrder(AppOrder order) {
    _driverAvailableOrders = [
      order,
      ..._driverAvailableOrders.where((item) => item.id != order.id),
    ];
    _driverAvailableOrders.sort(_driverOrderComparator);
    _pruneExpiredDriverOrders();
    notifyListeners();
  }

  bool _removeDriverPendingOrder(String orderId) {
    final before = _driverAvailableOrders.length;
    _driverAvailableOrders = _driverAvailableOrders
        .where((order) => order.id != orderId)
        .toList();
    return before != _driverAvailableOrders.length;
  }

  Future<void> _handleDriverOrderAcceptedEvent(
    Map<String, dynamic> payload,
  ) async {
    final orderId = _stringify(payload['order_id']);
    if (orderId.isEmpty) return;
    final orderType = _orderTypeFromPayload(payload['order_type']);
    final driverId = _tryParseInt(payload['driver_id']);
    final removed = _removeDriverPendingOrder(orderId);
    var shouldNotify = removed;

    if (driverId != null && driverId != 0 && driverId == _driverProfileId) {
      final numericId = int.tryParse(orderId);
      if (numericId != null) {
        try {
          final details = await _api.fetchOrder(id: numericId, type: orderType);
          final mapped = AppOrder.fromJson(
            details,
            resolveRegionName: _regionDisplayNameById,
            resolveDistrictName: _districtDisplayNameById,
            fallbackType: orderType,
          ).copyWith(status: OrderStatus.active);
          _driverActiveOrders = [
            mapped,
            ..._driverActiveOrders.where((item) => item.id != mapped.id),
          ];
          if (_mergePassengerOrderFromDriverContext(mapped)) {
            shouldNotify = true;
          }
          shouldNotify = true;
        } on ApiException {
          // Ignore detail fetch failures; UI will refresh later.
        }
      }
      await _refreshDriverStatsOnly();
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  Future<void> _handleDriverOrderCompletedEvent(
    Map<String, dynamic> payload,
  ) async {
    final orderId = _stringify(payload['order_id']);
    if (orderId.isEmpty) return;
    final driverId = _tryParseInt(payload['driver_id']);
    if (driverId == null || driverId == 0 || driverId != _driverProfileId) {
      return;
    }
    final orderType = _orderTypeFromPayload(payload['order_type']);
    final numericId = int.tryParse(orderId);
    if (numericId == null) return;

    try {
      final details = await _api.fetchOrder(id: numericId, type: orderType);
      final completed = AppOrder.fromJson(
        details,
        resolveRegionName: _regionDisplayNameById,
        resolveDistrictName: _districtDisplayNameById,
        fallbackType: orderType,
      ).copyWith(status: OrderStatus.completed);
      _driverActiveOrders = _driverActiveOrders
          .where((order) => order.id != orderId)
          .toList();
      _driverCompletedOrders = <AppOrder>[
        completed,
        ..._driverCompletedOrders,
      ].take(20).toList();
      _mergePassengerOrderFromDriverContext(completed);
      await _refreshDriverStatsOnly();
      notifyListeners();
    } on ApiException {
      _driverActiveOrders = _driverActiveOrders
          .where((order) => order.id != orderId)
          .toList();
      notifyListeners();
    }
  }

  Future<void> _handleDriverOrderCancelledEvent(
    Map<String, dynamic> payload,
  ) async {
    final orderId = _stringify(payload['order_id']);
    if (orderId.isEmpty) return;

    final reason = payload['cancellation_reason']?.toString();

    final pendingChanged = _removeDriverPendingOrder(orderId);

    AppOrder? removedActive;
    if (_driverActiveOrders.isNotEmpty) {
      _driverActiveOrders = _driverActiveOrders.where((order) {
        final keep = order.id != orderId;
        if (!keep) {
          removedActive = order;
        }
        return keep;
      }).toList();
    }

    final removedFromActive = removedActive != null;
    var shouldNotify = pendingChanged || removedFromActive;

    if (removedFromActive) {
      await _refreshDriverStatsOnly();
      final cancelledOrder = removedActive!.copyWith(
        status: OrderStatus.cancelled,
        cancelReason: reason ?? removedActive!.cancelReason,
      );
      if (_mergePassengerOrderFromDriverContext(cancelledOrder)) {
        shouldNotify = true;
      }

      final strings = localization;
      final baseMessage = strings
          .tr('orderIdLabel')
          .replaceFirst('{id}', orderId);
      final message = (reason != null && reason.trim().isNotEmpty)
          ? '$baseMessage - $reason'
          : baseMessage;
      _enqueueDriverRealtimeMessage(
        title: strings.tr('orderCancelled'),
        message: message,
      );
      _prependRealtimeNotification(strings.tr('orderCancelled'), message);
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  Map<String, dynamic>? _extractNotificationPayload(
    Map<String, dynamic> payload,
  ) {
    final raw = payload['notification'];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    final keys = [
      'id',
      'title',
      'message',
      'notification_type',
      'type',
      'created_at',
      'is_read',
    ];
    final normalized = <String, dynamic>{};
    for (final key in keys) {
      if (!payload.containsKey(key)) continue;
      final value = payload[key];
      if (value != null) {
        normalized[key] = value;
      }
    }
    if (normalized.isEmpty) return null;
    final notificationType =
        normalized['notification_type'] ?? payload['notification_type'];
    if (notificationType != null) {
      normalized['notification_type'] = notificationType;
      normalized['type'] = notificationType;
    }
    return normalized;
  }

  void _bumpNotificationSignal() {
    _notificationSignal = (_notificationSignal + 1) & 0x7fffffff;
  }

  String? _eventTypeFromPayload(Map<String, dynamic> payload) {
    const keys = ['type', 'event', 'action'];
    for (final key in keys) {
      final normalized = _normalizeEventTypeValue(payload[key]);
      if (normalized != null) return normalized;
    }
    return null;
  }

  String? _normalizeEventTypeValue(Object? raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    final camelExpanded = text.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)}',
    );
    final withSeparators = camelExpanded
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .replaceAll('.', '_');
    final normalized = withSeparators
        .toLowerCase()
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    return normalized.isEmpty ? null : normalized;
  }

  OrderType _orderTypeFromPayload(Object? raw) {
    final normalized = raw?.toString().toLowerCase();
    return normalized == 'delivery' ? OrderType.delivery : OrderType.taxi;
  }

  OrderStatus? _resolveRealtimeStatus(Map<String, dynamic> payload) {
    const keys = ['status', 'order_status', 'state'];
    for (final key in keys) {
      final resolved = _orderStatusFromValue(payload[key]);
      if (resolved != null) return resolved;
    }
    return null;
  }

  OrderStatus? _orderStatusFromValue(Object? raw) {
    final normalized = raw?.toString().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    switch (normalized) {
      case 'pending':
        return OrderStatus.pending;
      case 'accepted':
      case 'active':
      case 'in_progress':
        return OrderStatus.active;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
      default:
        return null;
    }
  }

  bool _applyUserOrderStatus(
    Map<String, dynamic> payload,
    OrderStatus status, {
    _DriverInfo? driverInfo,
  }) {
    final orderId = _stringify(payload['order_id']);
    if (orderId.isEmpty) {
      _logRealtime(
        'user',
        'local_status_update skipped missing order_id for status=${status.name}',
      );
      return false;
    }

    var updated = false;
    _orders = _orders.map((order) {
      if (order.id != orderId) return order;
      updated = true;
      return order.copyWith(
        status: status,
        driverName: driverInfo?.name,
        driverPhone: driverInfo?.phone,
        vehicle: driverInfo?.vehicle,
        vehiclePlate: driverInfo?.plate,
      );
    }).toList();

    if (updated) {
      _sortOrders();
      notifyListeners();
      _logRealtime(
        'user',
        'local_status_update orderId=$orderId status=${status.name}',
      );
    } else {
      _logRealtime(
        'user',
        'local_status_update missing orderId=$orderId status=${status.name}',
      );
    }
    return updated;
  }

  bool _mergePassengerOrderFromDriverContext(AppOrder updated) {
    final currentId = _currentUser.id.trim();
    final ownerId = updated.ownerId.trim();
    final belongsToUser =
        currentId.isEmpty || ownerId.isEmpty || ownerId == currentId;
    if (!belongsToUser) return false;

    var changed = false;
    var found = false;
    final merged = _orders.map((order) {
      if (order.id != updated.id) {
        return order;
      }
      found = true;
      changed = true;
      return order.copyWith(
        status: updated.status,
        driverName: updated.driverName ?? order.driverName,
        driverPhone: updated.driverPhone ?? order.driverPhone,
        vehicle: updated.vehicle ?? order.vehicle,
        vehiclePlate: updated.vehiclePlate ?? order.vehiclePlate,
        note: updated.note ?? order.note,
        price: updated.price,
        scheduledAt: updated.scheduledAt ?? order.scheduledAt,
        driverStartTime: updated.driverStartTime ?? order.driverStartTime,
        driverEndTime: updated.driverEndTime ?? order.driverEndTime,
      );
    }).toList();

    if (!found) {
      merged.add(updated);
      changed = true;
    }

    if (changed) {
      _orders = merged;
      _sortOrders();
    }
    return changed;
  }

  Future<bool> _syncPassengerOrderFromBackend({
    required String orderId,
    required OrderType orderType,
  }) async {
    final numericId = int.tryParse(orderId);
    if (numericId == null) return false;
    try {
      _logRealtime(
        'user',
        'sync_fetch orderId=$orderId type=${orderType.name}',
      );
      final details = await _api.fetchOrder(id: numericId, type: orderType);
      final mapped = AppOrder.fromJson(
        details,
        resolveRegionName: _regionDisplayNameById,
        resolveDistrictName: _districtDisplayNameById,
        fallbackType: orderType,
      );
      final changed = _mergePassengerOrderFromDriverContext(mapped);
      if (changed) {
        _logRealtime(
          'user',
          'sync_fetch merged orderId=$orderId status=${mapped.status.name}',
        );
        notifyListeners();
      } else {
        _logRealtime('user', 'sync_fetch no_change orderId=$orderId');
      }
      return changed;
    } on ApiException catch (error) {
      _logRealtime(
        'user',
        'sync_fetch failed orderId=$orderId error=${error.message}',
      );
      return false;
    }
  }

  Future<void> _syncPassengerOrderOrRefresh({
    required String orderId,
    required OrderType orderType,
  }) async {
    _logRealtime(
      'user',
      'sync_request orderId=$orderId type=${orderType.name}',
    );
    try {
      final synced = await _syncPassengerOrderFromBackend(
        orderId: orderId,
        orderType: orderType,
      );
      if (!synced) {
        _logRealtime('user', 'sync_request orderId=$orderId fallback=refresh');
        await refreshOrders();
      }
    } catch (_) {
      try {
        _logRealtime('user', 'sync_request orderId=$orderId retry=refresh');
        await refreshOrders();
      } catch (_) {
        // Swallow refresh failures triggered by realtime sync attempts.
      }
    }
  }

  Future<void> _handleDriverStatusPush(Map<String, dynamic> payload) async {
    final sourceChannel = payload['channel']?.toString().toLowerCase();
    final eventScope = sourceChannel == 'driver' ? 'driver' : 'user';
    final eventId = payload['event_id']?.toString();
    if (eventId != null && eventId.isNotEmpty) {
      if (_lastDriverStatusEventId == eventId) {
        _logRealtime(
          eventScope,
          'driver_status duplicate ignored event_id=$eventId',
        );
        return;
      }
      _lastDriverStatusEventId = eventId;
    }
    final statusRaw = payload['status']?.toString().toLowerCase();
    if (statusRaw == null || statusRaw.isEmpty) return;
    final title = payload['title']?.toString().isNotEmpty == true
        ? payload['title'].toString()
        : (statusRaw == 'approved'
              ? 'Driver access granted'
              : 'Driver application update');
    final message = payload['message']?.toString().isNotEmpty == true
        ? payload['message'].toString()
        : (statusRaw == 'approved'
              ? 'Your driver application has been approved. Please log in again to access driver tools.'
              : 'Your driver application status changed.');

    _enqueueUserRealtimeMessage(title: title, message: message);
    final shouldNotifyDriverToast =
        (_currentUser.isDriver && _currentUser.driverApproved) ||
        sourceChannel == 'driver';
    if (shouldNotifyDriverToast) {
      _enqueueDriverRealtimeMessage(title: title, message: message);
    }
    _prependRealtimeNotification(title, message);
    await _syncDriverContext(loadDashboard: statusRaw == 'approved');
    try {
      await refreshProfile();
    } on ApiException {
      // Ignore profile refresh failures; driver context already synced.
    }
    await refreshNotifications();
  }

  _DriverInfo? _extractDriverInfo(Object? payload) {
    if (payload is Map<String, dynamic>) {
      return (
        name: payload['full_name']?.toString() ?? payload['name']?.toString(),
        phone:
            payload['telephone']?.toString() ??
            payload['phone_number']?.toString(),
        vehicle:
            payload['car_model']?.toString() ?? payload['vehicle']?.toString(),
        plate:
            payload['car_number']?.toString() ??
            payload['vehicle_plate']?.toString(),
      );
    }
    if (payload is Map) {
      final data = Map<String, dynamic>.from(payload);
      return (
        name: data['full_name']?.toString() ?? data['name']?.toString(),
        phone:
            data['telephone']?.toString() ?? data['phone_number']?.toString(),
        vehicle: data['car_model']?.toString() ?? data['vehicle']?.toString(),
        plate:
            data['car_number']?.toString() ?? data['vehicle_plate']?.toString(),
      );
    }
    return null;
  }

  bool _payloadTargetsCurrentUser(Map<String, dynamic> payload) {
    final rawUserId = payload['user_id'];
    if (rawUserId == null) return true;
    final targetId = rawUserId.toString().trim();
    if (targetId.isEmpty) return true;
    final currentId = _currentUser.id.trim();
    final matches = targetId == currentId;
    if (!matches) {
      _logRealtime(
        'user',
        'payload_rejected target_user=$targetId current_user=$currentId',
      );
    }
    return matches;
  }

  void _init() {
    Future.microtask(() async {
      await _ensureStorage();
      final restored = await _restoreSession();
      if (!restored) {
        _bootstrapping = false;
        notifyListeners();
      }
    });
  }

  Future<void> _ensureStorage() async {
    _sessionStorage ??= await SessionStorage.getInstance();
  }

  Future<bool> _restoreSession() async {
    final storage = _sessionStorage;
    if (storage == null) return false;
    final stored = await storage.read();
    if (stored == null) return false;
    final expiresAt = stored.savedAt.add(_sessionTTL);
    if (DateTime.now().isAfter(expiresAt)) {
      await storage.clear();
      return false;
    }
    _authToken = stored.token;
    _api.updateToken(_authToken);
    _currentUser = _hydrateUser(AppUser.fromJson(stored.userJson));
    _isAuthenticated = true;
    _isDriverMode = _currentUser.isDriver;
    _driverApplicationSubmitted = false;
    _refreshRealtimeConnections();
    notifyListeners();
    await _bootstrapAfterAuth();
    return true;
  }

  Future<void> _saveSessionSnapshot({bool refreshTimestamp = false}) async {
    if (!_isAuthenticated) return;
    final token = _authToken;
    if (token == null || token.isEmpty) return;
    await _ensureStorage();
    final storage = _sessionStorage;
    if (storage == null) return;
    if (refreshTimestamp) {
      await storage.saveSession(token: token, user: _currentUser);
    } else {
      await storage.updateUser(_currentUser);
    }
  }

  AppUser _hydrateUser(AppUser user) {
    final avatar = user.avatarUrl;
    final resolvedAvatar = _resolveAssetUrl(avatar);
    return user.copyWith(avatarUrl: resolvedAvatar);
  }

  void _syncLocaleFromUser(String? languageCode) {
    final locale = _localeFromLanguage(languageCode);
    if (locale != null && _locale != locale) {
      _locale = locale;
      _localizeOrders();
    }
  }

  void _localizeOrders() {
    if (_orders.isEmpty || _regions.isEmpty) return;
    _orders = _orders
        .map(
          (order) => order.withResolvedNames(
            fromRegion: _regionDisplayNameById(order.fromRegionId),
            fromDistrict: _districtDisplayNameById(order.fromDistrictId),
            toRegion: _regionDisplayNameById(order.toRegionId),
            toDistrict: _districtDisplayNameById(order.toDistrictId),
          ),
        )
        .toList();
  }

  void _sortOrders() {
    _orders.sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      return _timeOfDayToMinutes(
        b.startTime,
      ).compareTo(_timeOfDayToMinutes(a.startTime));
    });
  }

  Future<void> _loadPricing({bool force = false}) async {
    if (!force && _pricingByRoute.isNotEmpty) return;
    final pricingData = await _api.fetchPricing();
    _pricingByRoute.clear();
    for (final item in pricingData) {
      final pricing = PricingModel.fromJson(item);
      if (!pricing.isActive) continue;
      _pricingByRoute[_pricingKey(
            pricing.fromRegionId,
            pricing.toRegionId,
            pricing.serviceType,
          )] =
          pricing;
    }
  }

  String _regionDisplayName(RegionModel region) {
    return switch (_locale) {
      AppLocale.uzLatin => region.nameUzLat,
      AppLocale.uzCyrillic => region.nameUzCyr,
      AppLocale.ru => region.nameRu,
    };
  }

  String _districtDisplayName(DistrictModel district) {
    return switch (_locale) {
      AppLocale.uzLatin => district.nameUzLat,
      AppLocale.uzCyrillic => district.nameUzCyr,
      AppLocale.ru => district.nameRu,
    };
  }

  String _regionDisplayNameById(int id) {
    final region = _regionById[id];
    if (region == null) {
      return _fallbackRegionName(id);
    }
    return _regionDisplayName(region);
  }

  String _districtDisplayNameById(int id) {
    final district = _districtById[id];
    if (district == null) {
      return _fallbackDistrictName(id);
    }
    return _districtDisplayName(district);
  }

  int? _regionIdByName(String name) {
    for (final region in _regions) {
      if (_regionDisplayName(region) == name) {
        return region.id;
      }
    }
    return null;
  }

  int? _districtIdByName(int regionId, String name) {
    final region = _regionById[regionId];
    if (region == null) return null;
    for (final district in region.districts) {
      if (_districtDisplayName(district) == name) {
        return district.id;
      }
    }
    return null;
  }

  PricingModel? _findPricingEntry(
    int fromRegionId,
    int toRegionId,
    String serviceType,
  ) {
    final normalizedService = serviceType.toLowerCase();
    final direct =
        _pricingByRoute[_pricingKey(
          fromRegionId,
          toRegionId,
          normalizedService,
        )];
    if (direct != null) {
      return direct;
    }
    return _pricingByRoute[_pricingKey(
      toRegionId,
      fromRegionId,
      normalizedService,
    )];
  }

  String _pricingKey(int fromRegionId, int toRegionId, String serviceType) {
    return '$fromRegionId|$toRegionId|${serviceType.toLowerCase()}';
  }

  bool _roleAllowsDriverPrivileges(String role) {
    return _driverEligibleRoles.contains(role.toLowerCase());
  }

  Future<void> _syncDriverContext({bool loadDashboard = false}) async {
    if (!_isAuthenticated) return;
    try {
      final status = await _api.fetchDriverStatus();
      var userRole = _currentUser.role.toLowerCase();
      var roleAllowsDriver = _roleAllowsDriverPrivileges(userRole);
      final backendReportsDriver = status['is_driver'] == true;
      if (backendReportsDriver && !roleAllowsDriver) {
        try {
          final latestProfile = await _api.fetchProfile();
          _currentUser = _hydrateUser(latestProfile);
          userRole = _currentUser.role.toLowerCase();
          roleAllowsDriver = _roleAllowsDriverPrivileges(userRole);
        } on ApiException {
          // Ignore profile refresh failures here; fallback to cached role.
        }
      }
      final isDriver = roleAllowsDriver && backendReportsDriver;
      final driverStatusRaw = (status['status'] ?? status['driver_status'])
          ?.toString()
          .toLowerCase();
      final driverApproved = isDriver && driverStatusRaw == 'approved';
      final applicationStatus = status['application_status']
          ?.toString()
          .toLowerCase();
      final driverId = _tryParseInt(status['driver_id']);
      _driverProfileId = isDriver ? driverId : null;
      DriverProfile? nextDriverProfile = _driverProfile;
      if (isDriver) {
        try {
          final profileMap = await _api.fetchDriverProfile();
          nextDriverProfile = _mapDriverProfile(profileMap);
        } on ApiException {
          // Keep existing driver profile cache if fetching fails.
        }
      } else {
        nextDriverProfile = null;
      }
      _driverProfile = nextDriverProfile;
      var updatedUser = _currentUser.copyWith(
        isDriver: isDriver,
        driverApproved: driverApproved,
      );
      if (nextDriverProfile != null) {
        updatedUser = updatedUser.copyWith(
          rating: nextDriverProfile.rating,
          balance: nextDriverProfile.balance,
        );
      }
      _currentUser = updatedUser;
      _driverApplicationSubmitted = !isDriver && applicationStatus == 'pending';
      if (!isDriver) {
        _driverAvailableOrders = <AppOrder>[];
        _driverActiveOrders = <AppOrder>[];
        _driverCompletedOrders = <AppOrder>[];
        _driverStats = null;
        _isDriverMode = false;
        if (!roleAllowsDriver) {
          _driverProfile = null;
        }
      }
      await _saveSessionSnapshot();
      _refreshRealtimeConnections();
      if (isDriver && driverApproved && loadDashboard) {
        try {
          await refreshDriverDashboard(force: true);
        } on ApiException {
          // Ignore dashboard refresh failures during sync.
        }
      }
    } on ApiException {
      // Driver sync can fail if endpoints are unavailable; ignore silently.
    }
  }

  void _refreshRealtimeConnections() {
    final token = _authToken;
    final hasToken = token != null && token.isNotEmpty;
    _realtime.updateSession(
      token: token,
      enableUserChannel: _isAuthenticated && hasToken,
      enableDriverChannel:
          _isAuthenticated &&
          hasToken &&
          _currentUser.isDriver &&
          _currentUser.driverApproved,
    );
  }

  Future<DriverStats> _loadDriverStatistics() async {
    final response = await _api.fetchDriverStatistics();
    return DriverStats.fromJson(response);
  }

  Future<List<AppOrder>> _loadDriverNewOrders() async {
    final response = await _api.fetchDriverNewOrders();
    return _mapDriverNewOrders(response);
  }

  Future<List<AppOrder>> _loadDriverActiveOrders() async {
    final response = await _api.fetchDriverActiveOrders();
    return _mapDriverOrders(response, status: OrderStatus.active);
  }

  DriverProfile _mapDriverProfile(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    final license = normalized['license_photo']?.toString() ?? '';
    if (license.isNotEmpty) {
      normalized['license_photo'] = _resolveAssetUrl(license);
    }
    return DriverProfile.fromJson(normalized);
  }

  List<AppOrder> _mapDriverNewOrders(Map<String, dynamic> payload) {
    return _mapDriverOrders(payload, status: OrderStatus.pending);
  }

  List<AppOrder> _mapDriverOrders(
    Map<String, dynamic> payload, {
    required OrderStatus status,
  }) {
    final results = <AppOrder>[];
    final taxiOrders = payload['taxi_orders'];
    if (taxiOrders is List) {
      for (final item in taxiOrders) {
        final order = switch (item) {
          Map<String, dynamic> data => _driverOrderFromMap(
            data,
            OrderType.taxi,
            status: status,
          ),
          Map data => _driverOrderFromMap(
            Map<String, dynamic>.from(data),
            OrderType.taxi,
            status: status,
          ),
          _ => null,
        };
        if (order != null) results.add(order);
      }
    }
    final deliveryOrders = payload['delivery_orders'];
    if (deliveryOrders is List) {
      for (final item in deliveryOrders) {
        final order = switch (item) {
          Map<String, dynamic> data => _driverOrderFromMap(
            data,
            OrderType.delivery,
            status: status,
          ),
          Map data => _driverOrderFromMap(
            Map<String, dynamic>.from(data),
            OrderType.delivery,
            status: status,
          ),
          _ => null,
        };
        if (order != null) results.add(order);
      }
    }
    results.sort(_driverOrderComparator);
    return results;
  }

  AppOrder? _driverOrderFromMap(
    Map<String, dynamic> json,
    OrderType type, {
    OrderStatus status = OrderStatus.pending,
  }) {
    int parseInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    double parseDouble(Object? value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0;
    }

    final fromRegionId = parseInt(json['from_region_id']);
    final toRegionId = parseInt(json['to_region_id']);
    final passengers = parseInt(json['passengers'] ?? 1).clamp(1, 4);
    final date = _parseDriverDate(json['date']?.toString()) ?? DateTime.now();
    final start =
        _parseDriverTime(json['time_start']?.toString()) ??
        const TimeOfDay(hour: 0, minute: 0);
    final end =
        _parseDriverTime(json['time_end']?.toString()) ??
        const TimeOfDay(hour: 0, minute: 0);
    final fromRegion = _regionDisplayNameById(fromRegionId);
    final toRegion = _regionDisplayNameById(toRegionId);
    final note = type == OrderType.delivery
        ? json['item_type']?.toString()
        : json['note']?.toString();
    final createdAt = _normalizeServerTimestamp(json['created_at']?.toString());
    if (status == OrderStatus.pending && !_isDriverOrderFresh(createdAt)) {
      return null;
    }
    final rawPrice = json['price'];
    final hasPrice = rawPrice != null && rawPrice.toString().trim().isNotEmpty;
    final parsedPrice = hasPrice ? parseDouble(rawPrice) : 0.0;

    return AppOrder(
      id: (json['id'] ?? '').toString(),
      ownerId: (json['user_id'] ?? json['customer_id'] ?? '').toString(),
      createdAt: createdAt,
      type: type,
      fromRegion: fromRegion,
      fromDistrict: fromRegion,
      toRegion: toRegion,
      toDistrict: toRegion,
      passengers: type == OrderType.taxi ? passengers : 1,
      date: date,
      startTime: start,
      endTime: end,
      price: parsedPrice,
      priceAvailable: hasPrice,
      status: status,
      fromRegionId: fromRegionId,
      fromDistrictId: 0,
      toRegionId: toRegionId,
      toDistrictId: 0,
      note: note,
    );
  }

  int _driverOrderComparator(AppOrder a, AppOrder b) {
    final createdCompare = _compareNullableDates(a.createdAt, b.createdAt);
    if (createdCompare != 0) return createdCompare;
    final dateCompare = a.date.compareTo(b.date);
    if (dateCompare != 0) return dateCompare;
    return _timeOfDayToMinutes(
      a.startTime,
    ).compareTo(_timeOfDayToMinutes(b.startTime));
  }

  int _compareNullableDates(DateTime? a, DateTime? b) {
    if (identical(a, b)) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }

  void _pruneExpiredDriverOrders() {
    _driverAvailableOrders = _driverAvailableOrders
        .where((order) => _isDriverOrderFresh(order.createdAt))
        .toList();
  }

  bool _isDriverOrderFresh(DateTime? timestamp) {
    if (timestamp == null) return true;
    final age = DateTime.now().difference(timestamp);
    if (age.isNegative) {
      return true;
    }
    return age <= _driverOrderFreshnessWindow;
  }

  DateTime? _normalizeServerTimestamp(String? value) {
    final parsed = _parseDriverDateTime(value);
    if (parsed == null) return null;
    if (_timestampHasExplicitOffset(value)) {
      return parsed;
    }
    return parsed.add(_serverTimeOffset);
  }

  bool _timestampHasExplicitOffset(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final normalized = value.trim().toUpperCase();
    if (normalized.endsWith('Z')) return true;
    return RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(normalized);
  }

  DateTime? _parseDriverDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final parsed = DateTime.parse(value);
      return parsed.isUtc ? parsed.toLocal() : parsed;
    } catch (_) {
      return _parseDriverDate(value);
    }
  }

  DateTime? _parseDriverDate(String? value) {
    if (value == null || value.isEmpty) return null;
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

  TimeOfDay? _parseDriverTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  int? _tryParseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _stringify(Object? value) => value?.toString() ?? '';

  Future<void> _refreshDriverStatsOnly() async {
    if (!_currentUser.isDriver || !_currentUser.driverApproved) return;
    try {
      final stats = await _loadDriverStatistics();
      _driverStats = stats;
      _currentUser = _currentUser.copyWith(
        balance: stats.currentBalance,
        rating: stats.rating,
      );
      await _saveSessionSnapshot();
    } on ApiException {
      // Ignore stat refresh failures.
    }
  }

  void _prependRealtimeNotification(String title, String message) {
    if (title.isEmpty && message.isEmpty) return;
    final notification = AppNotification(
      id: 'rt-${DateTime.now().microsecondsSinceEpoch}',
      title: title.isEmpty ? 'Update' : title,
      message: message,
      timestamp: DateTime.now(),
      category: NotificationCategory.system,
      isRead: false,
    );
    _notifications = [notification, ..._notifications];
    _bumpNotificationSignal();
    notifyListeners();
  }

  String _languageCodeForLocale(AppLocale locale) {
    return switch (locale) {
      AppLocale.uzLatin => 'uz_latin',
      AppLocale.uzCyrillic => 'uz_cyrillic',
      AppLocale.ru => 'russian',
    };
  }

  AppLocale? _localeFromLanguage(String? code) {
    return switch (code?.toLowerCase()) {
      'uz_cyrillic' => AppLocale.uzCyrillic,
      'uz_latin' => AppLocale.uzLatin,
      'russian' || 'ru' => AppLocale.ru,
      _ => null,
    };
  }

  String _resolveAssetUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final normalized = url.startsWith('/') ? url.substring(1) : url;
    return '$_uploadsOrigin/$normalized';
  }

  String _preparePhoneNumber(String input) {
    final normalized = _normalizePhoneNumber(input);
    if (normalized.isEmpty) {
      throw const ApiException('Phone number is required', statusCode: 400);
    }
    if (normalized.length > 20) {
      throw const ApiException(
        'Phone number is too long (max 20 characters)',
        statusCode: 400,
      );
    }
    return normalized;
  }

  String _normalizePhoneNumber(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      final char = trimmed[i];
      if (char == '+' && buffer.isEmpty) {
        buffer.write(char);
      } else if (_isDigit(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  String _stringifyCoordinate(double value) => value.toStringAsFixed(8);

  DateTime? _combineDateTime(DateTime date, TimeOfDay time) {
    try {
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    } catch (_) {
      return null;
    }
  }

  int _timeOfDayToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  String _fallbackRegionName(int id) => id == 0 ? '' : 'Region $id';

  String _fallbackDistrictName(int id) => id == 0 ? '' : 'District $id';

  @override
  void dispose() {
    _realtime.dispose();
    _api.dispose();
    super.dispose();
  }
}

typedef _DriverInfo = ({
  String? name,
  String? phone,
  String? vehicle,
  String? plate,
});
