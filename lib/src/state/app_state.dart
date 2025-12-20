import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
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
      _realtime =
          realtime ?? RealtimeGateway(baseUrl: backendBaseUrl, enabled: false) {
    _api.setUnauthorizedHandler(_handleUnauthorizedLogout);
    _realtime.setHandlers(
      onUserEvent: _handleUserRealtimeEvent,
      onDriverEvent: _handleDriverRealtimeEvent,
    );
    _init();
  }

  static const Duration _sessionTTL = Duration(days: 7);
  static const int _defaultDriverOrderPreviewMinutes = 2;
  static const Duration _serverTimeOffset = Duration(hours: 5);
  static const int _ordersPageSize = 20;
  static const int _driverOrdersPageSize = 10;
  static const int _driverRealtimePollLimit = 50;
  static const Duration _userRealtimePollInterval = Duration(seconds: 1);
  static const Duration _driverRealtimePollInterval = Duration(seconds: 1);
  static const Duration _notificationPollInterval = Duration(seconds: 1);
  static const Set<String> _driverEligibleRoles = {
    'driver',
    'admin',
    'superadmin',
  };
  static const String _uploadsOrigin = backendBaseUrl;
  static const bool _notificationsMuted = false;
  // Keep toast/alert popups muted while still fetching and showing notifications.
  static const bool _notificationAlertsMuted = true;

  final ApiClient _api;
  final RealtimeGateway _realtime;
  SessionStorage? _sessionStorage;

  AppUser _currentUser = AppUser.empty();
  List<AppOrder> _orders = <AppOrder>[];
  int _taxiOrdersOffset = 0;
  int _deliveryOrdersOffset = 0;
  bool _taxiOrdersHasMore = true;
  bool _deliveryOrdersHasMore = true;
  bool _ordersLoadingMore = false;
  List<AppNotification> _notifications = <AppNotification>[];
  List<RegionModel> _regions = <RegionModel>[];
  final Map<int, RegionModel> _regionById = <int, RegionModel>{};
  final Map<int, DistrictModel> _districtById = <int, DistrictModel>{};
  final Map<String, PricingModel> _pricingByRoute = <String, PricingModel>{};
  List<AppOrder> _driverAvailableOrders = <AppOrder>[];
  List<AppOrder> _driverActiveOrders = <AppOrder>[];
  List<AppOrder> _driverCompletedOrders = <AppOrder>[];
  OrderType? _driverIncomingTypeFilter;
  int? _driverIncomingFromRegionFilter;
  Set<int> _driverIncomingToRegionFilters = <int>{};
  int _driverAvailableOffset = 0;
  int _driverActiveOffset = 0;
  int _driverCompletedOffset = 0;
  bool _driverAvailableHasMore = true;
  bool _driverActiveHasMore = true;
  bool _driverCompletedHasMore = true;
  bool _driverAvailableLoadingMore = false;
  bool _driverActiveLoadingMore = false;
  bool _driverCompletedLoadingMore = false;
  DriverStats? _driverStats;
  DriverProfile? _driverProfile;
  final Queue<({String title, String message})> _userRealtimeMessages =
      Queue<({String title, String message})>();
  final Queue<({String title, String message})> _driverRealtimeMessages =
      Queue<({String title, String message})>();
  Duration _driverOrderPreviewWindow =
      const Duration(minutes: _defaultDriverOrderPreviewMinutes);
  final Map<String, DateTime> _driverOrderPreviewAnchors = <String, DateTime>{};
  final Map<String, int> _driverOrderViewerCounts = <String, int>{};
  final Set<String> _ratedOrders = <String>{};
  final Map<String, ({OrderStatus status, _DriverInfo? driver})>
  _lastPassengerOrderEvents =
      <String, ({OrderStatus status, _DriverInfo? driver})>{};

  ThemeMode _themeMode = ThemeMode.light;
  AppLocale _locale = AppLocale.uzLatin;
  bool _isAuthenticated = false;
  bool _isDriverMode = false;
  bool _driverApplicationSubmitted = false;
  bool _bootstrapping = true;
  bool _driverContextLoading = false;
  bool _handlingUnauthorizedLogout = false;
  String? _authToken;
  int? _driverProfileId;
  int _notificationSignal = 0;
  String? _lastDriverStatusEventId;
  Timer? _userRealtimeTimer;
  Timer? _driverRealtimeTimer;
  Timer? _notificationTimer;
  bool _userRealtimeTickRunning = false;
  bool _driverRealtimeTickRunning = false;
  bool _notificationTickRunning = false;
  bool _driverIncomingOrdersEnabled = true;
  bool _driverIncomingSoundEnabled = true;
  AudioPlayer? _driverIncomingPlayer;

  AppLocalizations get localization => AppLocalizations(_locale);
  AppUser get currentUser => _currentUser;
  ThemeMode get themeMode => _themeMode;
  Locale get locale => localization.locale;
  bool get isAuthenticated => _isAuthenticated;
  bool get isDriverMode => _isDriverMode && _currentUser.isDriver;
  bool get isDriverApproved => _currentUser.driverApproved;
  bool get driverIncomingOrdersEnabled => _driverIncomingOrdersEnabled;
  bool get driverIncomingSoundEnabled => _driverIncomingSoundEnabled;
  bool get driverApplicationSubmitted => _driverApplicationSubmitted;
  bool get isBootstrapping => _bootstrapping;
  String? get authToken => _authToken;
  bool hasRatedOrder(String orderId) => _ratedOrders.contains(orderId);

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
  OrderType? get driverIncomingTypeFilter => _driverIncomingTypeFilter;
  int? get driverIncomingFromRegionFilter => _driverIncomingFromRegionFilter;
  Set<int> get driverIncomingToRegionFilters =>
      Set<int>.unmodifiable(_driverIncomingToRegionFilters);
  List<RegionModel> get regionOptions =>
      List<RegionModel>.unmodifiable(_regions);
  bool get hasMoreOrders => _taxiOrdersHasMore || _deliveryOrdersHasMore;
  bool get isLoadingMoreOrders => _ordersLoadingMore;
  bool get driverAvailableHasMore => _driverAvailableHasMore;
  bool get driverActiveHasMore => _driverActiveHasMore;
  bool get driverCompletedHasMore => _driverCompletedHasMore;
  bool get isLoadingMoreDriverAvailable => _driverAvailableLoadingMore;
  bool get isLoadingMoreDriverActive => _driverActiveLoadingMore;
  bool get isLoadingMoreDriverCompleted => _driverCompletedLoadingMore;
  int driverOrderViewerCount(String orderId) =>
      _driverOrderViewerCounts[orderId] ?? 0;
  Duration get driverOrderPreviewWindow =>
      _sanitizeDriverPreviewWindow(_driverOrderPreviewWindow);
  DateTime? driverOrderPreviewStartedAt(String orderId) {
    _pruneDriverPreviewAnchors();
    return _driverOrderPreviewAnchors[orderId];
  }

  DateTime? driverOrderPreviewExpiresAt(String orderId) {
    final started = driverOrderPreviewStartedAt(orderId);
    if (started == null) return null;
    return started.add(driverOrderPreviewWindow);
  }

  Duration? driverOrderPreviewRemaining(String orderId) {
    final expiresAt = driverOrderPreviewExpiresAt(orderId);
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (!expiresAt.isAfter(now)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  bool isDriverOrderPreviewActive(String orderId) {
    final remaining = driverOrderPreviewRemaining(orderId);
    if (remaining == null) return false;
    return remaining > Duration.zero;
  }

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

  String regionLabel(RegionModel region) => _regionDisplayName(region);
  String regionLabelById(int id) => _regionDisplayNameById(id);
  String districtLabel(DistrictModel district) =>
      _districtDisplayName(district);
  String districtLabelById(int id) => _districtDisplayNameById(id);

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

  Future<void> setDriverIncomingSoundEnabled(bool enabled) async {
    if (_driverIncomingSoundEnabled == enabled) return;
    _driverIncomingSoundEnabled = enabled;
    await _persistDriverPreferences();
    notifyListeners();
  }

  Future<void> setDriverIncomingOrdersEnabled(bool enabled) async {
    if (_driverIncomingOrdersEnabled == enabled) return;
    _driverIncomingOrdersEnabled = enabled;
    await _persistDriverPreferences();
    if (enabled) {
      if (_isAuthenticated &&
          _currentUser.isDriver &&
          _currentUser.driverApproved) {
        _startDriverRealtimeTimer();
        unawaited(_pollDriverRealtime());
      }
    } else {
      _stopDriverRealtimePolling();
    }
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
    _resetUserOrderPagination();
    await _fetchNextUserOrdersPage();
  }

  Future<void> loadMoreOrders() => _fetchNextUserOrdersPage();

  Future<void> _fetchNextUserOrdersPage() async {
    if (!_isAuthenticated) return;
    if (_ordersLoadingMore) return;
    if (!_taxiOrdersHasMore && !_deliveryOrdersHasMore) return;
    _ordersLoadingMore = true;
    notifyListeners();
    try {
      final pendingRequests = <String, Future<List<Map<String, dynamic>>>>{};
      if (_taxiOrdersHasMore) {
        pendingRequests['taxi'] = _api.fetchUserOrders(
          type: 'taxi',
          limit: _ordersPageSize,
          offset: _taxiOrdersOffset,
        );
      }
      if (_deliveryOrdersHasMore) {
        pendingRequests['delivery'] = _api.fetchUserOrders(
          type: 'delivery',
          limit: _ordersPageSize,
          offset: _deliveryOrdersOffset,
        );
      }
      if (pendingRequests.isEmpty) return;
      final responses = <String, List<Map<String, dynamic>>>{};
      for (final entry in pendingRequests.entries) {
        responses[entry.key] = await entry.value;
      }

      final List<AppOrder> newOrders = [];
      final taxiData = responses['taxi'];
      if (taxiData != null) {
        final mapped = taxiData
            .map(
              (json) => AppOrder.fromJson(
                json,
                resolveRegionName: _regionDisplayNameById,
                resolveDistrictName: _districtDisplayNameById,
              ),
            )
            .toList();
        _taxiOrdersOffset += mapped.length;
        _taxiOrdersHasMore = mapped.length >= _ordersPageSize;
        newOrders.addAll(mapped);
      }
      final deliveryData = responses['delivery'];
      if (deliveryData != null) {
        final mapped = deliveryData
            .map(
              (json) => AppOrder.fromJson(
                json,
                resolveRegionName: _regionDisplayNameById,
                resolveDistrictName: _districtDisplayNameById,
              ),
            )
            .toList();
        _deliveryOrdersOffset += mapped.length;
        _deliveryOrdersHasMore = mapped.length >= _ordersPageSize;
        newOrders.addAll(mapped);
      }
      if (newOrders.isNotEmpty) {
        _mergePassengerOrders(newOrders);
      } else {
        _recomputeUserOrderOffsets();
      }
    } finally {
      _ordersLoadingMore = false;
      notifyListeners();
    }
  }

  void _resetUserOrderPagination() {
    _orders = <AppOrder>[];
    _taxiOrdersOffset = 0;
    _deliveryOrdersOffset = 0;
    _taxiOrdersHasMore = true;
    _deliveryOrdersHasMore = true;
    _ordersLoadingMore = false;
    _lastPassengerOrderEvents.clear();
  }

  Future<void> refreshNotifications() async {
    if (!_isAuthenticated) return;
    if (_notificationsMuted) {
      _notifications = <AppNotification>[];
      notifyListeners();
      return;
    }
    final data = await _api.fetchNotifications();
    final items = data.map(AppNotification.fromJson).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final seenOrderSignatures = <String>{};
    final deduped = <AppNotification>[];
    final hideOrderNotifications = !_isDriverMode;
    for (final item in items) {
      if (hideOrderNotifications &&
          item.category == NotificationCategory.orderUpdate) {
        continue;
      }
      if (item.category == NotificationCategory.orderUpdate) {
        final signature = _notificationSignature(item);
        if (!seenOrderSignatures.add(signature)) {
          continue;
        }
      }
      deduped.add(item);
    }
    final previousIds = _notifications.map((item) => item.id).toSet();
    final hasNew = deduped.any((item) => !previousIds.contains(item.id));
    _notifications = deduped;
    if (hasNew) {
      _bumpNotificationSignal();
    }
    notifyListeners();
  }

  Future<void> refreshDriverStatus({bool loadDashboard = false}) async {
    await _syncDriverContext(loadDashboard: loadDashboard);
    notifyListeners();
  }

  Future<void> refreshDriverPendingTimeSetting({bool silent = true}) async {
    await _loadDriverPendingTimeSetting(silent: silent);
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
    required String clientGender,
    required DateTime scheduledDate,
    required TimeOfDay scheduledTime,
    required PickupLocation pickupLocation,
    String? note,
    String? customerName,
    String? customerPhone,
    String? bonusUserId,
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
    final nameInput = (customerName ?? _currentUser.fullName).trim();
    final username = nameInput.isEmpty
        ? _currentUser.fullName
        : nameInput.trim();
    final phoneInput = (customerPhone ?? '').trim();
    final fallbackPhone = _currentUser.phoneNumber;
    final normalizedTelephone = _preparePhoneNumber(
      phoneInput.isNotEmpty ? phoneInput : fallbackPhone,
    );
    final normalizedGender = switch (clientGender.toLowerCase().trim()) {
      'male' => 'male',
      'female' => 'female',
      _ => 'both',
    };
    final body = <String, dynamic>{
      'username': username,
      'telephone': normalizedTelephone.toString(),
      'client_gender': normalizedGender,
      // Send common aliases to stay backward-compatible with backend expectations.
      'passenger_gender': normalizedGender,
      'gender': normalizedGender,
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
      if (bonusUserId != null && bonusUserId.trim().isNotEmpty)
        'bonus_user_id': bonusUserId.trim(),
    };

    final response = await _api.createTaxiOrder(body);
    var order = AppOrder.fromJson(
      response,
      resolveRegionName: _regionDisplayNameById,
      resolveDistrictName: _districtDisplayNameById,
      fallbackType: OrderType.taxi,
    );
    if (order.clientGender == null || order.clientGender!.isEmpty) {
      order = order.copyWith(clientGender: normalizedGender);
    }
    _orders = [order, ..._orders];
    _recomputeUserOrderOffsets();
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
    _recomputeUserOrderOffsets();
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

  Future<void> rateDriver({
    required AppOrder order,
    required int rating,
    String? comment,
  }) async {
    if (!_isAuthenticated) {
      throw const ApiException('Login required', statusCode: 401);
    }
    if (_ratedOrders.contains(order.id)) {
      throw const ApiException('You have already rated this order');
    }
    final normalizedRating = rating.clamp(1, 5).toInt();
    final driverId = order.driverId;
    if (driverId == null || driverId <= 0) {
      throw const ApiException('Driver not assigned', statusCode: 400);
    }
    final orderId = int.tryParse(order.id);
    if (orderId == null) {
      throw const ApiException('Invalid order id', statusCode: 400);
    }
    try {
      await _api.rateDriver(
        driverId: driverId,
        orderId: orderId,
        orderType: order.type,
        rating: normalizedRating,
        comment: comment,
      );
      _markOrderRated(order.id);
    } on ApiException catch (error) {
      final message = error.message.toLowerCase();
      final alreadyRated =
          message.contains('already rated') || message.contains('rated this');
      if (alreadyRated) {
        _markOrderRated(order.id);
        return;
      }
      rethrow;
    }
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
    // For delivery: passengers parameter is not applicable, returns base_price
    return pricing.priceForPassengers(1);
  }

  Future<double?> fetchCalculatedPrice({
    required int fromRegionId,
    required int toRegionId,
    required String serviceType,
    int? passengers,
    int? fromDistrictId,
    int? toDistrictId,
    String? seatType,
  }) async {
    try {
      final response = await _api.calculatePrice(
        fromRegionId: fromRegionId,
        toRegionId: toRegionId,
        serviceType: serviceType,
        passengers: passengers,
        fromDistrictId: fromDistrictId,
        toDistrictId: toDistrictId,
        seatType: seatType,
      );
      final totalPrice = response['total_price'];
      if (totalPrice == null) return null;
      if (totalPrice is num) return totalPrice.toDouble();
      final parsed = double.tryParse(totalPrice.toString());
      return parsed;
    } on ApiException {
      return null;
    }
  }

  Future<void> updateProfile({String? name, String? phoneNumber}) async {
    final trimmedName = name?.trim();
    final trimmedPhone = phoneNumber?.trim();
    final currentNormalizedPhone = _normalizePhoneNumber(
      _currentUser.phoneNumber,
    );
    final phoneChanged =
        trimmedPhone != null &&
        trimmedPhone.isNotEmpty &&
        trimmedPhone != _currentUser.phoneNumber;
    final normalizedPhone =
        phoneChanged && trimmedPhone != null && trimmedPhone.isNotEmpty
        ? _preparePhoneNumber(trimmedPhone)
        : null;
    final shouldUpdateName =
        trimmedName != null &&
        trimmedName.isNotEmpty &&
        trimmedName != _currentUser.fullName;

    final shouldUpdatePhone =
        normalizedPhone != null && normalizedPhone != currentNormalizedPhone;

    if (!shouldUpdateName && !shouldUpdatePhone) {
      return;
    }

    final updatedUser = await _api.updateProfile(
      name: shouldUpdateName ? trimmedName : null,
      phoneNumber: shouldUpdatePhone ? normalizedPhone : null,
    );
    final hydrated = _hydrateUser(updatedUser);
    _currentUser = _currentUser.copyWith(
      fullName: hydrated.fullName.isNotEmpty
          ? hydrated.fullName
          : _currentUser.fullName,
      phoneNumber: hydrated.phoneNumber.isNotEmpty
          ? hydrated.phoneNumber
          : _currentUser.phoneNumber,
      avatarUrl: hydrated.avatarUrl.isNotEmpty
          ? hydrated.avatarUrl
          : _currentUser.avatarUrl,
      language: hydrated.language.isNotEmpty
          ? hydrated.language
          : _currentUser.language,
      role: hydrated.role.isNotEmpty ? hydrated.role : _currentUser.role,
      isDriver: hydrated.isDriver,
      driverApproved: hydrated.driverApproved,
      rating: hydrated.rating,
      balance: hydrated.balance,
    );

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
    _stopRealtimePolling();
    _authToken = null;
    _api.updateToken(null);
    _isAuthenticated = false;
    _isDriverMode = false;
    _driverApplicationSubmitted = false;
    _currentUser = AppUser.empty();
    _orders = <AppOrder>[];
    _taxiOrdersOffset = 0;
    _deliveryOrdersOffset = 0;
    _taxiOrdersHasMore = true;
    _deliveryOrdersHasMore = true;
    _ordersLoadingMore = false;
    _notifications = <AppNotification>[];
    _driverAvailableOrders = <AppOrder>[];
    _driverActiveOrders = <AppOrder>[];
    _driverCompletedOrders = <AppOrder>[];
    _driverAvailableOffset = 0;
    _driverActiveOffset = 0;
    _driverCompletedOffset = 0;
    _driverAvailableHasMore = true;
    _driverActiveHasMore = true;
    _driverCompletedHasMore = true;
    _driverAvailableLoadingMore = false;
    _driverActiveLoadingMore = false;
    _driverCompletedLoadingMore = false;
    _driverStats = null;
    _driverProfile = null;
    _driverContextLoading = false;
    _bootstrapping = false;
    _driverProfileId = null;
    _lastDriverStatusEventId = null;
    _driverIncomingOrdersEnabled = true;
    _driverIncomingSoundEnabled = true;
    _driverOrderPreviewWindow =
        const Duration(minutes: _defaultDriverOrderPreviewMinutes);
    _driverOrderPreviewAnchors.clear();
    _driverOrderViewerCounts.clear();
    _lastPassengerOrderEvents.clear();
    _ratedOrders.clear();
    _refreshRealtimeConnections();
    notifyListeners();
  }

  Future<void> _handleUnauthorizedLogout() async {
    if (_handlingUnauthorizedLogout || !_isAuthenticated) return;
    _handlingUnauthorizedLogout = true;
    try {
      await logout();
    } finally {
      _handlingUnauthorizedLogout = false;
    }
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
    required File carPhotoFile,
    required File texPasFile,
  }) async {
    final licenseUpload = await _api.uploadDriverLicense(licenseFile);
    final licensePath = licenseUpload['file_path']?.toString() ?? '';
    if (licensePath.isEmpty) {
      throw const ApiException(
        'Failed to upload license photo',
        statusCode: 400,
      );
    }
    final carUpload = await _api.uploadDriverCarPhoto(carPhotoFile);
    final carPhotoPath = carUpload['file_path']?.toString() ?? '';
    if (carPhotoPath.isEmpty) {
      throw const ApiException('Failed to upload car photo', statusCode: 400);
    }
    final texUpload = await _api.uploadDriverTexPas(texPasFile);
    final texPasPath = texUpload['file_path']?.toString() ?? '';
    if (texPasPath.isEmpty) {
      throw const ApiException(
        'Failed to upload tex pas photo',
        statusCode: 400,
      );
    }
    await _api.submitDriverApplication(
      fullName: fullName.trim(),
      carModel: carModel.trim(),
      carNumber: carNumber.trim(),
      licensePath: licensePath,
      carPhotoPath: carPhotoPath,
      texPasPath: texPasPath,
    );
    _driverApplicationSubmitted = true;
    _currentUser = _currentUser.copyWith(fullName: fullName.trim());
    await _saveSessionSnapshot();
    notifyListeners();
  }

  Future<void> beginDriverOrderPreview(AppOrder order) async {
    final orderId = order.id.trim();
    if (orderId.isEmpty) return;
    _pruneDriverPreviewAnchors();
    final alreadyTracked = _driverOrderPreviewAnchors.containsKey(orderId);
    Future<void>? previewFuture;
    if (!alreadyTracked) {
      _driverOrderPreviewAnchors[orderId] = DateTime.now();
      _persistDriverPreviewAnchors();
      final numericId = int.tryParse(orderId);
      if (numericId != null) {
        previewFuture = _api.previewDriverOrder(
          id: numericId,
          type: order.type,
        );
      }
    }
    _emitDriverRealtimeCommand(
      type: 'viewing_order',
      orderId: orderId,
      orderType: order.type,
    );
    if (!alreadyTracked) {
      notifyListeners();
    }
    if (previewFuture != null) {
      try {
        await previewFuture;
      } on ApiException catch (error) {
        _logRealtime(
          'driver',
          'preview_failed orderId=$orderId error=${error.message}',
        );
      } catch (_) {
        _logRealtime('driver', 'preview_failed orderId=$orderId error=unknown');
      }
    }
  }

  void endDriverOrderPreview(
    AppOrder order, {
    bool releaseHold = false,
    String? reason,
  }) {
    final orderId = order.id.trim();
    if (orderId.isEmpty) return;
    _emitDriverRealtimeCommand(
      type: 'stop_viewing_order',
      orderId: orderId,
      orderType: order.type,
    );
    if (releaseHold) {
      releaseDriverOrderPreview(orderId, type: order.type, reason: reason);
      if (reason == 'driver_cancelled') {
        final before = _driverAvailableOrders.length;
        _driverAvailableOrders = _driverAvailableOrders
            .where((item) => item.id != orderId)
            .toList();
        if (before != _driverAvailableOrders.length) {
          _recomputeDriverPaginationOffsets();
          notifyListeners();
        }
      }
    }
  }

  void releaseDriverOrderPreview(
    String orderId, {
    OrderType? type,
    String? reason,
  }) {
    final normalized = orderId.trim();
    if (normalized.isEmpty) return;
    final removed = _driverOrderPreviewAnchors.remove(normalized) != null;
    if (removed) {
      _persistDriverPreviewAnchors();
    }
    if (type != null) {
      final numericId = int.tryParse(orderId);
      if (numericId != null) {
        Future.microtask(() async {
          try {
            await _api.releaseDriverOrderPreview(
              id: numericId,
              type: type,
              reason: reason,
            );
          } on ApiException catch (error) {
            _logRealtime(
              'driver',
              'preview_release_failed orderId=$orderId error=${error.message}',
            );
          } catch (_) {
            _logRealtime(
              'driver',
              'preview_release_failed orderId=$orderId error=unknown',
            );
          }
        });
      }
    }
    if (removed) {
      notifyListeners();
    }
  }

  OrderType? _resolveDriverPreviewOrderType(String orderId) {
    for (final order in _driverAvailableOrders) {
      if (order.id == orderId) return order.type;
    }
    for (final order in _driverActiveOrders) {
      if (order.id == orderId) return order.type;
    }
    for (final order in _driverCompletedOrders) {
      if (order.id == orderId) return order.type;
    }
    for (final order in _orders) {
      if (order.id == orderId) return order.type;
    }
    return null;
  }

  Future<void> updateDriverIncomingFilters({
    OrderType? orderType,
    int? fromRegionId,
    Set<int>? toRegionIds,
  }) async {
    final normalizedToRegions = <int>{
      ...toRegionIds ?? _driverIncomingToRegionFilters,
    }..removeWhere((id) => id <= 0);
    if (fromRegionId != null) {
      normalizedToRegions.remove(fromRegionId);
    }
    final hasChanged =
        orderType != _driverIncomingTypeFilter ||
        fromRegionId != _driverIncomingFromRegionFilter ||
        !_setEqualsInt(normalizedToRegions, _driverIncomingToRegionFilters);
    if (!hasChanged) return;
    _driverIncomingTypeFilter = orderType;
    _driverIncomingFromRegionFilter = fromRegionId;
    _driverIncomingToRegionFilters = normalizedToRegions;
    _driverAvailableOrders = <AppOrder>[];
    _driverAvailableHasMore = true;
    _driverAvailableOffset = 0;
    notifyListeners();
    await refreshDriverDashboard(force: true);
  }

  Future<void> refreshDriverDashboard({bool force = false}) async {
    if (!_currentUser.isDriver || !_currentUser.driverApproved) return;
    if (_driverContextLoading && !force) return;
    if (_regions.isEmpty) {
      await loadRegions(force: true);
    }
    _driverAvailableHasMore = true;
    _driverActiveHasMore = true;
    _driverAvailableOffset = 0;
    _driverActiveOffset = 0;
    _driverAvailableLoadingMore = false;
    _driverActiveLoadingMore = false;
    _driverContextLoading = true;
    notifyListeners();
    try {
      final dashboardData = await Future.wait([
        _loadDriverStatistics(),
        _loadDriverNewOrders(
          offset: 0,
          limit: _driverOrdersPageSize,
          orderType: _driverIncomingTypeFilter,
          fromRegionId: _driverIncomingFromRegionFilter,
          toRegionIds: _driverIncomingToRegionFilters,
        ),
        _loadDriverActiveOrders(offset: 0, limit: _driverOrdersPageSize),
      ]);
      final stats = dashboardData[0] as DriverStats;
      final pending = dashboardData[1] as _PaginatedDriverOrders;
      final active = dashboardData[2] as _PaginatedDriverOrders;
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
      _driverAvailableOrders = pending.orders;
      _driverActiveOrders = active.orders;
      _driverAvailableHasMore = pending.hasMore;
      _driverActiveHasMore = active.hasMore;
      _pruneUnaffordableAvailableOrders();
      await _hydrateDriverServiceFees(_driverAvailableOrders);
      _recomputeDriverPaginationOffsets();
      await _saveSessionSnapshot();
    } finally {
      _driverContextLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreDriverAvailableOrders() async {
    if (!_currentUser.isDriver || !_currentUser.driverApproved) return;
    if (_driverAvailableLoadingMore || !_driverAvailableHasMore) return;
    _driverAvailableLoadingMore = true;
    notifyListeners();
    try {
      final page = await _loadDriverNewOrders(
        offset: _driverAvailableOffset,
        limit: _driverOrdersPageSize,
        orderType: _driverIncomingTypeFilter,
        fromRegionId: _driverIncomingFromRegionFilter,
        toRegionIds: _driverIncomingToRegionFilters,
      );
      if (page.orders.isNotEmpty) {
        _driverAvailableOrders = _mergeDriverOrders(
          _driverAvailableOrders,
          page.orders,
        );
      }
      _driverAvailableHasMore = page.hasMore;
      _pruneUnaffordableAvailableOrders();
      await _hydrateDriverServiceFees(page.orders);
      _recomputeDriverPaginationOffsets();
    } finally {
      _driverAvailableLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreDriverActiveOrders() async {
    if (!_currentUser.isDriver || !_currentUser.driverApproved) return;
    if (_driverActiveLoadingMore || !_driverActiveHasMore) return;
    _driverActiveLoadingMore = true;
    notifyListeners();
    try {
      final page = await _loadDriverActiveOrders(
        offset: _driverActiveOffset,
        limit: _driverOrdersPageSize,
      );
      if (page.orders.isNotEmpty) {
        _driverActiveOrders = _mergeDriverOrders(
          _driverActiveOrders,
          page.orders,
        );
      }
      _driverActiveHasMore = page.hasMore;
      _recomputeDriverPaginationOffsets();
    } finally {
      _driverActiveLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> reloadDriverCompletedOrders() async {
    if (!_currentUser.isDriver || !_currentUser.driverApproved) return;
    if (_driverCompletedLoadingMore) return;
    _driverCompletedOrders = <AppOrder>[];
    _driverCompletedOffset = 0;
    _driverCompletedHasMore = true;
    notifyListeners();
    await loadMoreDriverCompletedOrders();
  }

  Future<void> loadMoreDriverCompletedOrders() async {
    if (!_currentUser.isDriver || !_currentUser.driverApproved) return;
    if (_driverCompletedLoadingMore || !_driverCompletedHasMore) return;
    _driverCompletedLoadingMore = true;
    notifyListeners();
    try {
      final page = await _loadDriverCompletedOrders(
        offset: _driverCompletedOffset,
        limit: _driverOrdersPageSize,
      );
      if (page.orders.isNotEmpty) {
        _driverCompletedOrders = _mergeDriverOrders(
          _driverCompletedOrders,
          page.orders,
        );
      }
      _driverCompletedHasMore = page.hasMore;
      _recomputeDriverPaginationOffsets();
    } finally {
      _driverCompletedLoadingMore = false;
      notifyListeners();
    }
  }

  Future<AppOrder?> loadDriverOrderDetail(AppOrder order) async {
    if (!_currentUser.isDriver || !_currentUser.driverApproved) return null;
    final numericId = int.tryParse(order.id);
    if (numericId == null) return null;
    try {
      final details = await _api.fetchOrder(id: numericId, type: order.type);
      final mapped = AppOrder.fromJson(
        details,
        resolveRegionName: _regionDisplayNameById,
        resolveDistrictName: _districtDisplayNameById,
        fallbackType: order.type,
      );
      final availableOffset = _driverAvailableOffset;
      final activeOffset = _driverActiveOffset;
      final completedOffset = _driverCompletedOffset;
      _bucketDriverOrders([mapped]);
      _driverAvailableOffset = availableOffset;
      _driverActiveOffset = activeOffset;
      _driverCompletedOffset = completedOffset;
      _mergePassengerOrderFromDriverContext(mapped);
      notifyListeners();
      return mapped;
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> acceptDriverOrder(AppOrder order) async {
    if (!_currentUser.isDriver || !_currentUser.driverApproved) {
      throw const ApiException(
        'Driver account not approved yet',
        statusCode: 403,
      );
    }
    if (!_driverCanAffordServiceFee(order.serviceFee)) {
      throw const ApiException(
        'Insufficient balance to accept this order',
        statusCode: 400,
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
    endDriverOrderPreview(order, releaseHold: true, reason: 'accepted');

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
    accepted = accepted.copyWith(status: OrderStatus.active);
    final needsConfirmation = !accepted.isConfirmed;

    _driverActiveOrders = [
      accepted,
      ..._driverActiveOrders.where((item) => item.id != accepted.id),
    ];
    _recomputeDriverPaginationOffsets();
    _mergePassengerOrderFromDriverContext(accepted);
    await _refreshDriverStatsOnly();

    if (needsConfirmation) {
      try {
        await confirmDriverOrder(accepted);
      } catch (_) {
        notifyListeners();
        rethrow;
      }
      return;
    }

    notifyListeners();
  }

  Future<void> confirmDriverOrder(AppOrder order) async {
    if (!_currentUser.isDriver || !_currentUser.driverApproved) {
      throw const ApiException(
        'Driver account not approved yet',
        statusCode: 403,
      );
    }
    if (order.isConfirmed) return;
    final numericId = int.tryParse(order.id);
    if (numericId == null) {
      throw const ApiException('Invalid order id', statusCode: 400);
    }
    final confirmed = await _api.confirmDriverOrder(
      id: numericId,
      type: order.type,
    );
    DateTime? confirmedAt;
    final confirmedDate = confirmed['confirmed_at'] ?? confirmed['confirmedAt'];
    if (confirmedDate != null) {
      confirmedAt = _normalizeServerTimestamp(confirmedDate.toString());
    }
    _driverActiveOrders = _driverActiveOrders.map((item) {
      if (item.id != order.id) return item;
      return item.copyWith(
        isConfirmed: true,
        confirmedAt: confirmedAt ?? DateTime.now(),
      );
    }).toList();
    _mergePassengerOrderFromDriverContext(
      order.copyWith(
        isConfirmed: true,
        confirmedAt: confirmedAt ?? DateTime.now(),
      ),
    );
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

    _driverCompletedOrders = _mergeDriverOrders(_driverCompletedOrders, [
      completed.copyWith(status: OrderStatus.completed),
    ]);
    _recomputeDriverPaginationOffsets();
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
      final pendingWindowFuture = _loadDriverPendingTimeSetting();
      await loadRegions(force: true);
      await Future.wait([
        refreshProfile(),
        refreshOrders(),
        refreshNotifications(),
        pendingWindowFuture,
      ]);
      await _syncDriverContext(loadDashboard: true);
    } finally {
      _bootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> _loadDriverPendingTimeSetting({bool silent = true}) async {
    try {
      final minutes = await _api.fetchOrderPendingTimeMinutes();
      if (minutes == null || minutes <= 0) return;
      final window = _sanitizeDriverPreviewWindow(Duration(minutes: minutes));
      if (window == _driverOrderPreviewWindow) return;
      _driverOrderPreviewWindow = window;
      _pruneDriverPreviewAnchors();
      notifyListeners();
    } on ApiException {
      if (!silent) rethrow;
    } catch (_) {
      if (!silent) rethrow;
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
    final previousEvent = _lastPassengerOrderEvents[orderId];
    final alreadyAnnounced =
        previousEvent != null &&
        previousEvent.status == status &&
        _sameDriverInfo(previousEvent.driver, driverInfo);
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

    _logRealtime(
      'user',
      '$eventLabel orderId=$orderId localUpdated=$updated duplicate=$alreadyAnnounced',
    );
    _lastPassengerOrderEvents[orderId] = (status: status, driver: driverInfo);

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
    if (toastTitle != null && !alreadyAnnounced) {
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
    if (_notificationsMuted) return;
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
    AppNotification? duplicateByContent;
    for (final item in _notifications) {
      if (_isSameNotificationContent(item, notification)) {
        duplicateByContent = item;
        break;
      }
    }
    final normalizedNotification =
        (duplicateByContent?.isRead == true && notification.isRead == false)
        ? notification.copyWith(isRead: true)
        : notification;
    final isOrderUpdate =
        normalizedNotification.category == NotificationCategory.orderUpdate;
    if (isOrderUpdate && !_isDriverMode) {
      return;
    }
    final existing =
        duplicateByContent != null ||
        _notifications.any((item) => item.id == normalizedNotification.id);
    final updatedList = [
      normalizedNotification,
      ..._notifications.where(
        (item) =>
            item.id != normalizedNotification.id &&
            !_isSameNotificationContent(item, normalizedNotification),
      ),
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

    // Order updates already surface localized toasts via realtime handlers.
    final shouldAnnounce =
        announce && !existing && !isOrderUpdate && !_notificationAlertsMuted;
    if (shouldAnnounce) {
      _enqueueUserRealtimeMessage(
        title: normalizedNotification.title,
        message: normalizedNotification.message,
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
        if (!_driverIncomingOrdersEnabled) break;
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
      case 'order_reserved':
        _logRealtime('driver', 'order_reserved forwarding to handler');
        await _handleDriverOrderReservedEvent(payload);
        break;
      case 'order_returned':
        _logRealtime('driver', 'order_returned forwarding to handler');
        await _handleDriverOrderReturnedEvent(payload);
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
      case 'viewer_count':
        final orderId = _stringify(payload['order_id']);
        if (orderId.isEmpty) break;
        final count = _tryParseInt(payload['count']) ?? 0;
        final previous = _driverOrderViewerCounts[orderId];
        if (count <= 0) {
          if (previous != null) {
            _driverOrderViewerCounts.remove(orderId);
            notifyListeners();
          }
        } else if (previous != count) {
          _driverOrderViewerCounts[orderId] = count;
          notifyListeners();
        }
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
    if (_notificationsMuted) return;
    if (orderId.isEmpty) return;
    final idLabel = localization
        .tr('orderIdLabel')
        .replaceFirst('{id}', orderId);
    final message = details == null || details.isEmpty
        ? idLabel
        : '$idLabel - $details';
    _enqueueUserRealtimeMessage(title: title, message: message);
  }

  bool _setEqualsInt(Set<int> a, Set<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final value in a) {
      if (!b.contains(value)) return false;
    }
    return true;
  }

  bool _matchesDriverIncomingFilters(AppOrder order) {
    final typeFilter = _driverIncomingTypeFilter;
    if (typeFilter != null && order.type != typeFilter) {
      return false;
    }
    final fromFilter = _driverIncomingFromRegionFilter;
    if (fromFilter != null && order.fromRegionId != fromFilter) {
      return false;
    }
    final toFilters = _driverIncomingToRegionFilters;
    if (toFilters.isNotEmpty && !toFilters.contains(order.toRegionId)) {
      return false;
    }
    return true;
  }

  double _driverCurrentBalance() {
    return _driverStats?.currentBalance ??
        _driverProfile?.balance ??
        _currentUser.balance;
  }

  bool _driverCanAffordServiceFee(double fee) {
    if (fee <= 0) return true;
    return _driverCurrentBalance() >= fee;
  }

  bool canDriverAcceptOrder(AppOrder order) {
    return _driverCanAffordServiceFee(order.serviceFee);
  }

  bool _pruneUnaffordableAvailableOrders() {
    if (_driverAvailableOrders.isEmpty) return false;
    final balance = _driverCurrentBalance();
    var changed = false;
    for (final order in _driverAvailableOrders) {
      final affordable = order.serviceFee <= 0 || balance >= order.serviceFee;
      if (!affordable) {
        _driverOrderViewerCounts.remove(order.id);
        releaseDriverOrderPreview(order.id);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
    return changed;
  }

  Future<void> _hydrateDriverServiceFees(
    Iterable<AppOrder> ordersToHydrate,
  ) async {
    final targets = ordersToHydrate
        .where((order) => order.serviceFee <= 0)
        .toList(growable: false);
    if (targets.isEmpty) return;
    final updated = <AppOrder>[];
    for (final order in targets) {
      final numericId = int.tryParse(order.id);
      if (numericId == null) continue;
      try {
        final details = await _api.fetchOrder(id: numericId, type: order.type);
        final mapped = AppOrder.fromJson(
          details,
          resolveRegionName: _regionDisplayNameById,
          resolveDistrictName: _districtDisplayNameById,
          fallbackType: order.type,
        );
        updated.add(
          order.copyWith(
            serviceFee: mapped.serviceFee,
            price: mapped.price,
            priceAvailable: mapped.priceAvailable,
            note: mapped.note ?? order.note,
            clientGender: mapped.clientGender,
            pickupAddress: mapped.pickupAddress ?? order.pickupAddress,
            pickupLatitude: mapped.pickupLatitude ?? order.pickupLatitude,
            pickupLongitude: mapped.pickupLongitude ?? order.pickupLongitude,
            customerPhone: mapped.customerPhone ?? order.customerPhone,
          ),
        );
      } catch (_) {
        // Ignore individual hydration failures; continue with remaining orders.
      }
    }
    if (updated.isNotEmpty) {
      _driverAvailableOrders = _mergeDriverOrders(
        _driverAvailableOrders,
        updated,
      );
      _pruneUnaffordableAvailableOrders();
      notifyListeners();
    }
  }

  void _announceDriverNewOrder(AppOrder order) {
    if (_notificationsMuted) return;
    if (!_driverIncomingOrdersEnabled) return;
    if (!_matchesDriverIncomingFilters(order)) return;
    unawaited(_playDriverIncomingAlert());
    final title = order.isDelivery
        ? localization.tr('deliveryOrder')
        : localization.tr('taxiOrder');
    final message = '${order.fromRegion} -> ${order.toRegion}';
    _enqueueDriverRealtimeMessage(title: title, message: message);
    _prependRealtimeNotification(title, message);
  }

  Future<void> _playDriverIncomingAlert() async {
    if (_notificationsMuted) return;
    if (!_driverIncomingSoundEnabled) return;
    try {
      _driverIncomingPlayer ??= AudioPlayer();
      await _driverIncomingPlayer!.stop();
      await _driverIncomingPlayer!.play(AssetSource('notification.mp3'));
    } catch (_) {
      // Ignore audio playback failures; polling will continue.
    }
  }

  void _enqueueUserRealtimeMessage({
    required String title,
    required String message,
  }) {
    if (_notificationsMuted || _notificationAlertsMuted) return;
    if (title.isEmpty && message.isEmpty) return;
    _userRealtimeMessages.add((title: title, message: message));
    notifyListeners();
  }

  void _enqueueDriverRealtimeMessage({
    required String title,
    required String message,
  }) {
    if (_notificationsMuted || _notificationAlertsMuted) return;
    if (title.isEmpty && message.isEmpty) return;
    _driverRealtimeMessages.add((title: title, message: message));
    notifyListeners();
  }

  void _upsertDriverPendingOrder(AppOrder order) {
    if (!_matchesDriverIncomingFilters(order)) {
      _driverOrderViewerCounts.remove(order.id);
      return;
    }
    final affordable = canDriverAcceptOrder(order);
    if (!affordable) {
      _driverOrderViewerCounts.remove(order.id);
      releaseDriverOrderPreview(order.id);
    }
    _driverAvailableOrders = [
      order,
      ..._driverAvailableOrders.where((item) => item.id != order.id),
    ];
    _driverAvailableOrders.sort(_driverOrderComparator);
    _recomputeDriverPaginationOffsets();
    if (order.serviceFee <= 0) {
      unawaited(_hydrateDriverServiceFees([order]));
    }
    notifyListeners();
  }

  bool _removeDriverPendingOrder(String orderId) {
    final before = _driverAvailableOrders.length;
    _driverAvailableOrders = _driverAvailableOrders
        .where((order) => order.id != orderId)
        .toList();
    final changed = before != _driverAvailableOrders.length;
    if (changed) {
      _driverOrderViewerCounts.remove(orderId);
      releaseDriverOrderPreview(orderId);
      _recomputeDriverPaginationOffsets();
    }
    return changed;
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
          _recomputeDriverPaginationOffsets();
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

  Future<void> _handleDriverOrderReservedEvent(
    Map<String, dynamic> payload,
  ) async {
    final orderId = _stringify(payload['order_id']);
    if (orderId.isEmpty) return;
    final driverId = _tryParseInt(payload['driver_id']);

    // If another driver reserved it, remove from available list
    if (driverId != null && driverId != 0 && driverId != _driverProfileId) {
      final removed = _removeDriverPendingOrder(orderId);
      if (removed) {
        notifyListeners();
      }
      return;
    }

    // If this driver reserved it, ensure we keep it tracked locally
    final expiresRaw = payload['reserved_until']?.toString();
    final expiresAt = _normalizeServerTimestamp(expiresRaw);
    if (expiresAt != null) {
      _driverOrderPreviewAnchors[orderId] = DateTime.now();
      notifyListeners();
    }
  }

  Future<void> _handleDriverOrderReturnedEvent(
    Map<String, dynamic> payload,
  ) async {
    final orderId = _stringify(payload['order_id']);
    if (orderId.isEmpty) return;
    final orderType = _orderTypeFromPayload(payload['order_type']);
    final driverId = _tryParseInt(payload['driver_id']);

    // If the current driver cancelled/rejected it, drop it locally right away.
    if (driverId != null && driverId != 0 && driverId == _driverProfileId) {
      final before = _driverAvailableOrders.length;
      _driverAvailableOrders = _driverAvailableOrders
          .where((order) => order.id != orderId)
          .toList();
      _driverOrderViewerCounts.remove(orderId);
      releaseDriverOrderPreview(orderId, type: orderType);
      if (before != _driverAvailableOrders.length) {
        _recomputeDriverPaginationOffsets();
        notifyListeners();
      }
      _logRealtime(
        'driver',
        'order_returned removed self-cancelled orderId=$orderId',
      );
      return;
    }

    // Clear viewer count so the order is interactable again
    final removedCount = _driverOrderViewerCounts.remove(orderId) != null;

    // If payload contains order snapshot, upsert directly
    final rawOrder = payload['order'];
    AppOrder? mapped;
    if (rawOrder is Map<String, dynamic>) {
      mapped = _driverOrderFromMap(rawOrder, orderType, usePayloadStatus: true);
    } else if (rawOrder is Map) {
      mapped = _driverOrderFromMap(
        Map<String, dynamic>.from(rawOrder),
        orderType,
        usePayloadStatus: true,
      );
    }

    if (mapped != null) {
      _upsertDriverPendingOrder(mapped);
      if (!removedCount) return;
      notifyListeners();
      return;
    }

    // Fallback: refresh available orders
    try {
      final pending = await _loadDriverNewOrders(
        offset: 0,
        limit: _driverOrdersPageSize,
        orderType: _driverIncomingTypeFilter,
        fromRegionId: _driverIncomingFromRegionFilter,
        toRegionIds: _driverIncomingToRegionFilters,
      );
      _driverAvailableOrders = pending.orders;
      _driverAvailableHasMore = pending.hasMore;
      _pruneUnaffordableAvailableOrders();
      await _hydrateDriverServiceFees(_driverAvailableOrders);
      _recomputeDriverPaginationOffsets();
      notifyListeners();
    } on ApiException catch (error) {
      _logRealtime(
        'driver',
        'order_returned refresh_failed orderId=$orderId error=${error.message}',
      );
    } catch (_) {}
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
      _driverCompletedOrders = _mergeDriverOrders(_driverCompletedOrders, [
        completed,
      ]);
      _recomputeDriverPaginationOffsets();
      _mergePassengerOrderFromDriverContext(completed);
      await _refreshDriverStatsOnly();
      notifyListeners();
    } on ApiException {
      _driverActiveOrders = _driverActiveOrders
          .where((order) => order.id != orderId)
          .toList();
      _recomputeDriverPaginationOffsets();
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
    if (shouldNotify) {
      _recomputeDriverPaginationOffsets();
    }

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

  bool _isSameNotificationContent(AppNotification a, AppNotification b) {
    return _notificationSignature(a) == _notificationSignature(b);
  }

  String _notificationSignature(AppNotification notification) {
    return '${notification.category.name}|'
        '${_normalizeNotificationText(notification.title)}|'
        '${_normalizeNotificationText(notification.message)}';
  }

  String _normalizeNotificationText(String input) => input.trim().toLowerCase();

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

    final driverIdFromPayload = _tryParseInt(payload['driver_id']);

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
        driverId: driverInfo?.id ?? driverIdFromPayload,
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
        driverId: updated.driverId ?? order.driverId,
        clientGender: updated.clientGender ?? order.clientGender,
        note: updated.note ?? order.note,
        price: updated.price,
        scheduledAt: updated.scheduledAt ?? order.scheduledAt,
        driverStartTime: updated.driverStartTime ?? order.driverStartTime,
        driverEndTime: updated.driverEndTime ?? order.driverEndTime,
        isConfirmed: updated.isConfirmed,
        confirmedAt: updated.confirmedAt ?? order.confirmedAt,
      );
    }).toList();

    if (!found) {
      merged.add(updated);
      changed = true;
    }

    if (changed) {
      _orders = merged;
      _sortOrders();
      _recomputeUserOrderOffsets();
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
      final id = _tryParseInt(payload['id'] ?? payload['driver_id']);
      return (
        id: id,
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
      final id = _tryParseInt(data['id'] ?? data['driver_id']);
      return (
        id: id,
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

  bool _sameDriverInfo(_DriverInfo? a, _DriverInfo? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if ((a.id ?? 0) != (b.id ?? 0)) return false;
    return (a.name ?? '').trim() == (b.name ?? '').trim() &&
        (a.phone ?? '').trim() == (b.phone ?? '').trim() &&
        (a.vehicle ?? '').trim() == (b.vehicle ?? '').trim() &&
        (a.plate ?? '').trim() == (b.plate ?? '').trim();
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
    final driverPrefs = await storage.readDriverPreferences();
    _driverIncomingSoundEnabled = driverPrefs.incomingSoundEnabled;
    _driverIncomingOrdersEnabled = driverPrefs.incomingOrdersEnabled;
    _refreshRealtimeConnections();
    final anchors = await storage.readDriverPreviewAnchors();
    if (anchors.isNotEmpty) {
      _driverOrderPreviewAnchors
        ..clear()
        ..addAll(anchors);
      _pruneDriverPreviewAnchors();
    }
    final ratedOrders = await storage.readRatedOrders();
    _ratedOrders
      ..clear()
      ..addAll(ratedOrders);
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
    await storage.saveDriverPreviewAnchors(_driverOrderPreviewAnchors);
    await storage.saveRatedOrders(_ratedOrders);
    await storage.saveDriverPreferences(
      incomingSoundEnabled: _driverIncomingSoundEnabled,
      incomingOrdersEnabled: _driverIncomingOrdersEnabled,
    );
  }

  Future<void> _persistRatedOrders() async {
    await _ensureStorage();
    final storage = _sessionStorage;
    if (storage == null) return;
    await storage.saveRatedOrders(_ratedOrders);
  }

  Future<void> _persistDriverPreferences() async {
    await _ensureStorage();
    final storage = _sessionStorage;
    if (storage == null) return;
    await storage.saveDriverPreferences(
      incomingSoundEnabled: _driverIncomingSoundEnabled,
      incomingOrdersEnabled: _driverIncomingOrdersEnabled,
    );
  }

  void _markOrderRated(String orderId) {
    final normalized = orderId.trim();
    if (normalized.isEmpty) return;
    final added = _ratedOrders.add(normalized);
    if (added) {
      unawaited(_persistRatedOrders());
      notifyListeners();
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

  void _mergePassengerOrders(List<AppOrder> incoming) {
    if (incoming.isEmpty) return;
    final merged = <String, AppOrder>{};
    for (final order in _orders) {
      merged[order.id] = order;
    }
    for (final order in incoming) {
      merged[order.id] = order;
    }
    _orders = merged.values.toList();
    _sortOrders();
    _recomputeUserOrderOffsets();
  }

  void _recomputeUserOrderOffsets() {
    _taxiOrdersOffset = _orders.where((order) => order.isTaxi).length;
    _deliveryOrdersOffset = _orders.where((order) => order.isDelivery).length;
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

  int? getRegionId(String name) => _regionIdByName(name);

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

  Future<void> _syncDriverContext({
    bool loadDashboard = false,
    bool refreshRealtime = true,
  }) async {
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
      _pruneUnaffordableAvailableOrders();
      _driverApplicationSubmitted = !isDriver && applicationStatus == 'pending';
      if (!isDriver) {
        _driverAvailableOrders = <AppOrder>[];
        _driverActiveOrders = <AppOrder>[];
        _driverCompletedOrders = <AppOrder>[];
        _driverAvailableOffset = 0;
        _driverActiveOffset = 0;
        _driverCompletedOffset = 0;
        _driverAvailableHasMore = true;
        _driverActiveHasMore = true;
        _driverCompletedHasMore = true;
        _driverAvailableLoadingMore = false;
        _driverActiveLoadingMore = false;
        _driverCompletedLoadingMore = false;
        _driverStats = null;
        _isDriverMode = false;
        if (!roleAllowsDriver) {
          _driverProfile = null;
        }
      }
      await _saveSessionSnapshot();
      if (refreshRealtime) {
        _refreshRealtimeConnections();
      }
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
    final hasSession = _isAuthenticated && hasToken;
    if (hasSession) {
      _startRealtimePolling();
    } else {
      _stopRealtimePolling();
    }
  }

  void _startRealtimePolling() {
    _stopRealtimePolling();
    _userRealtimeTimer = Timer.periodic(
      _userRealtimePollInterval,
      (_) => unawaited(_pollPassengerRealtime()),
    );
    _notificationTimer = Timer.periodic(
      _notificationPollInterval,
      (_) => unawaited(_pollNotificationsRealtime()),
    );
    if (_currentUser.isDriver &&
        _currentUser.driverApproved &&
        _driverIncomingOrdersEnabled) {
      _startDriverRealtimeTimer();
    }
    unawaited(_pollNotificationsRealtime());
    unawaited(_pollPassengerRealtime());
    if (_currentUser.isDriver &&
        _currentUser.driverApproved &&
        _driverIncomingOrdersEnabled) {
      unawaited(_pollDriverRealtime());
    }
  }

  void _startDriverRealtimeTimer() {
    _stopDriverRealtimePolling();
    _driverRealtimeTimer = Timer.periodic(
      _driverRealtimePollInterval,
      (_) => unawaited(_pollDriverRealtime()),
    );
  }

  void _stopDriverRealtimePolling() {
    _driverRealtimeTimer?.cancel();
    _driverRealtimeTimer = null;
    _driverRealtimeTickRunning = false;
  }

  void _stopRealtimePolling() {
    _userRealtimeTimer?.cancel();
    _stopDriverRealtimePolling();
    _notificationTimer?.cancel();
    _userRealtimeTimer = null;
    _notificationTimer = null;
    _userRealtimeTickRunning = false;
    _notificationTickRunning = false;
  }

  Future<void> _pollPassengerRealtime() async {
    if (!_isAuthenticated) return;
    if (_bootstrapping || _handlingUnauthorizedLogout) return;
    if (_ordersLoadingMore || _userRealtimeTickRunning) return;
    final activeOrders = _orders
        .where(
          (order) =>
              order.status == OrderStatus.pending ||
              order.status == OrderStatus.active,
        )
        .toList();
    if (activeOrders.isEmpty) return;

    _userRealtimeTickRunning = true;
    try {
      final fetches = <Future<AppOrder?>>[];
      for (final order in activeOrders) {
        final numericId = int.tryParse(order.id);
        if (numericId == null) continue;
        fetches.add(
          _api
              .fetchOrder(id: numericId, type: order.type)
              .then(
                (json) => AppOrder.fromJson(
                  json,
                  resolveRegionName: _regionDisplayNameById,
                  resolveDistrictName: _districtDisplayNameById,
                  fallbackType: order.type,
                ),
              )
              .catchError((_) => null),
        );
      }
      if (fetches.isEmpty) return;
      final results = await Future.wait(fetches);
      var changed = false;
      for (final updated in results) {
        if (updated == null) continue;
        if (_mergePassengerOrderFromDriverContext(updated)) {
          changed = true;
        }
      }
      if (changed) {
        notifyListeners();
      }
    } catch (_) {
      // Swallow background passenger poll errors.
    } finally {
      _userRealtimeTickRunning = false;
    }
  }

  Future<void> _pollNotificationsRealtime() async {
    if (_notificationsMuted) return;
    if (!_isAuthenticated || _handlingUnauthorizedLogout) return;
    if (_notificationTickRunning) return;
    _notificationTickRunning = true;
    try {
      await refreshNotifications();
      final shouldSyncDriverStatus =
          _driverApplicationSubmitted ||
          (_currentUser.isDriver && !_currentUser.driverApproved);
      if (shouldSyncDriverStatus && !_driverContextLoading) {
        try {
          await _syncDriverContext(
            loadDashboard: false,
            refreshRealtime: false,
          );
        } catch (_) {
          // Ignore driver status polling failures; will retry on next tick.
        }
      }
    } catch (_) {
      // Ignore notification refresh failures during background polling.
    } finally {
      _notificationTickRunning = false;
    }
  }

  Future<void> _pollDriverRealtime() async {
    _releaseExpiredDriverPreviews();
    if (!_isAuthenticated ||
        !_currentUser.isDriver ||
        !_currentUser.driverApproved) {
      return;
    }
    if (!_driverIncomingOrdersEnabled) return;
    if (_bootstrapping) return;
    if (_driverContextLoading ||
        _driverAvailableLoadingMore ||
        _driverActiveLoadingMore ||
        _driverCompletedLoadingMore ||
        _driverRealtimeTickRunning) {
      return;
    }

    _driverRealtimeTickRunning = true;
    try {
      final previousAvailableIds = _driverAvailableOrders
          .map((order) => order.id)
          .toSet();
      final pendingFuture = _loadDriverNewOrders(
        offset: 0,
        limit: _driverRealtimePollLimit,
        orderType: _driverIncomingTypeFilter,
        fromRegionId: _driverIncomingFromRegionFilter,
        toRegionIds: _driverIncomingToRegionFilters,
      );
      final assignedFuture = _api.fetchDriverAssignedOrders(
        limit: _driverRealtimePollLimit,
        offset: 0,
      );
      final statsFuture = _loadDriverStatistics();
      final results = await Future.wait([
        pendingFuture,
        assignedFuture,
        statsFuture,
      ]);
      final pending = results[0] as _PaginatedDriverOrders;
      final assignedPayload = results[1] as Map<String, dynamic>;
      final stats = results[2] as DriverStats;
      final newAvailableOrders = pending.orders
          .where((order) => !previousAvailableIds.contains(order.id))
          .toList();
      final assignedOrders = _mapDriverOrders(
        assignedPayload,
        usePayloadStatus: true,
      );

      _driverAvailableOrders = pending.orders;
      _driverAvailableHasMore = pending.hasMore;
      _driverAvailableOffset = _driverAvailableOrders.length;

      final assignedHasMore = _hasMoreFromPayload(
        assignedPayload,
        returned: assignedOrders.length,
        limit: _driverRealtimePollLimit,
        offset: 0,
      );
      final activeOrders = <AppOrder>[];
      final completedOrders = <AppOrder>[];
      for (final order in assignedOrders) {
        switch (order.status) {
          case OrderStatus.completed:
          case OrderStatus.cancelled:
            completedOrders.add(order);
            break;
          case OrderStatus.active:
          case OrderStatus.pending:
            activeOrders.add(order);
            break;
        }
        _mergePassengerOrderFromDriverContext(order);
      }

      _driverActiveOrders = activeOrders;
      _driverCompletedOrders = _mergeDriverOrders(
        _driverCompletedOrders,
        completedOrders,
      );
      _driverActiveHasMore = assignedHasMore || _driverActiveHasMore;
      _driverCompletedHasMore = assignedHasMore || _driverCompletedHasMore;
      _recomputeDriverPaginationOffsets();
      _pruneUnaffordableAvailableOrders();
      await _hydrateDriverServiceFees(_driverAvailableOrders);

      for (final order in newAvailableOrders) {
        _announceDriverNewOrder(order);
      }

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
      notifyListeners();
    } on ApiException {
      // Ignore driver poll failures; next tick will retry.
    } catch (_) {
      // Swallow unexpected polling errors.
    } finally {
      _driverRealtimeTickRunning = false;
    }
  }

  Future<DriverStats> _loadDriverStatistics() async {
    final response = await _api.fetchDriverStatistics();
    return DriverStats.fromJson(response);
  }

  Future<_PaginatedDriverOrders> _loadDriverNewOrders({
    int offset = 0,
    int limit = _driverOrdersPageSize,
    OrderType? orderType,
    int? fromRegionId,
    Set<int>? toRegionIds,
  }) async {
    // Backend now exposes available orders via the active endpoint
    // so new/pending orders are fetched from `/driver/orders/active`.
    final response = await _api.fetchDriverActiveOrders(
      limit: limit,
      offset: offset,
      orderType: orderType,
      fromRegionId: fromRegionId,
      toRegionIds: toRegionIds?.toList(growable: false),
    );
    final orders = _mapDriverNewOrders(response);
    return _PaginatedDriverOrders(
      orders: orders,
      hasMore: _hasMoreFromPayload(
        response,
        returned: orders.length,
        limit: limit,
        offset: offset,
      ),
    );
  }

  Future<_PaginatedDriverOrders> _loadDriverActiveOrders({
    int offset = 0,
    int limit = _driverOrdersPageSize,
  }) async {
    final response = await _api.fetchDriverAssignedOrders(
      status: 'accepted',
      limit: limit,
      offset: offset,
    );
    final orders = _mapDriverOrders(
      response,
      status: OrderStatus.active,
      usePayloadStatus: true,
    );
    return _PaginatedDriverOrders(
      orders: orders,
      hasMore: _hasMoreFromPayload(
        response,
        returned: orders.length,
        limit: limit,
        offset: offset,
      ),
    );
  }

  Future<_PaginatedDriverOrders> _loadDriverCompletedOrders({
    int offset = 0,
    int limit = _driverOrdersPageSize,
  }) async {
    final response = await _api.fetchDriverAssignedOrders(
      status: 'completed',
      limit: limit,
      offset: offset,
    );
    final orders = _mapDriverOrders(
      response,
      status: OrderStatus.completed,
      usePayloadStatus: true,
    );
    return _PaginatedDriverOrders(
      orders: orders,
      hasMore: _hasMoreFromPayload(
        response,
        returned: orders.length,
        limit: limit,
        offset: offset,
      ),
    );
  }

  DriverProfile _mapDriverProfile(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    final license = normalized['license_photo']?.toString() ?? '';
    final carPhoto = normalized['car_photo']?.toString() ?? '';
    final texPas = normalized['tex_pas']?.toString() ?? '';
    if (license.isNotEmpty) {
      normalized['license_photo'] = _resolveAssetUrl(license);
    }
    if (carPhoto.isNotEmpty) {
      normalized['car_photo'] = _resolveAssetUrl(carPhoto);
    }
    if (texPas.isNotEmpty) {
      normalized['tex_pas'] = _resolveAssetUrl(texPas);
    }
    return DriverProfile.fromJson(normalized);
  }

  List<AppOrder> _mapDriverNewOrders(Map<String, dynamic> payload) {
    return _mapDriverOrders(
      payload,
      status: OrderStatus.pending,
      usePayloadStatus: true,
    );
  }

  List<AppOrder> _mapDriverOrders(
    Map<String, dynamic> payload, {
    OrderStatus? status,
    bool usePayloadStatus = false,
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
            usePayloadStatus: usePayloadStatus,
          ),
          Map data => _driverOrderFromMap(
            Map<String, dynamic>.from(data),
            OrderType.taxi,
            status: status,
            usePayloadStatus: usePayloadStatus,
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
            usePayloadStatus: usePayloadStatus,
          ),
          Map data => _driverOrderFromMap(
            Map<String, dynamic>.from(data),
            OrderType.delivery,
            status: status,
            usePayloadStatus: usePayloadStatus,
          ),
          _ => null,
        };
        if (order != null) results.add(order);
      }
    }
    results.sort(_driverOrderComparator);
    return results;
  }

  bool _hasMoreFromPayload(
    Map<String, dynamic> payload, {
    required int returned,
    required int limit,
    required int offset,
  }) {
    final meta = payload['pagination'];
    if (meta is Map<String, dynamic>) {
      final hasMoreRaw = meta['has_more'];
      if (hasMoreRaw is bool) return hasMoreRaw;
      final totalRaw = meta['total'] ?? meta['count'];
      if (totalRaw is num) {
        return totalRaw.toInt() > offset + returned;
      }
      if (totalRaw is String) {
        final parsed = int.tryParse(totalRaw);
        if (parsed != null) return parsed > offset + returned;
      }
    }
    return returned >= limit;
  }

  AppOrder? _driverOrderFromMap(
    Map<String, dynamic> json,
    OrderType type, {
    OrderStatus? status,
    bool usePayloadStatus = false,
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

    bool parseBool(Object? value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final normalized = value?.toString().trim().toLowerCase() ?? '';
      if (normalized.isEmpty) return false;
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'ha';
    }

    String? parseGender(Object? value) {
      final normalized = value?.toString().trim().toLowerCase() ?? '';
      switch (normalized) {
        case 'male':
          return 'male';
        case 'female':
          return 'female';
        case 'both':
          return 'both';
        default:
          return null;
      }
    }

    final fromRegionId = parseInt(json['from_region_id']);
    final fromDistrictId = parseInt(json['from_district_id']);
    final toRegionId = parseInt(json['to_region_id']);
    final toDistrictId = parseInt(json['to_district_id']);
    final passengers = parseInt(json['passengers'] ?? 1).clamp(1, 4);
    final date = _parseDriverDate(json['date']?.toString()) ?? DateTime.now();
    final start =
        _parseDriverTime(json['time_start']?.toString()) ??
        const TimeOfDay(hour: 0, minute: 0);
    final end =
        _parseDriverTime(json['time_end']?.toString()) ??
        const TimeOfDay(hour: 0, minute: 0);
    var fromRegion = _regionDisplayNameById(fromRegionId);
    fromRegion = _preferInlineLocationLabel(
      json: json,
      keys: const [
        'from_region_label',
        'from_region_name',
        'from_region',
        'from_region_title',
        'from_region_text',
        'region_from',
        'region_from_name',
        'region_from_label',
      ],
      current: fromRegion,
      fallback: _fallbackRegionName(fromRegionId),
    );
    var fromDistrict = _districtDisplayNameById(fromDistrictId);
    fromDistrict = _preferInlineLocationLabel(
      json: json,
      keys: const [
        'from_district_label',
        'from_district_name',
        'from_district',
        'from_district_title',
        'from_city',
        'from_city_name',
        'from_city_label',
        'pickup_district',
        'pickup_district_name',
        'district_from',
        'district_from_name',
        'district_from_label',
        'from_district_text',
      ],
      current: fromDistrict,
      fallback: _fallbackDistrictName(fromDistrictId),
    );
    var toRegion = _regionDisplayNameById(toRegionId);
    toRegion = _preferInlineLocationLabel(
      json: json,
      keys: const [
        'to_region_label',
        'to_region_name',
        'to_region',
        'to_region_title',
        'to_region_text',
        'region_to',
        'region_to_name',
        'region_to_label',
      ],
      current: toRegion,
      fallback: _fallbackRegionName(toRegionId),
    );
    var toDistrict = _districtDisplayNameById(toDistrictId);
    toDistrict = _preferInlineLocationLabel(
      json: json,
      keys: const [
        'to_district_label',
        'to_district_name',
        'to_district',
        'to_district_title',
        'to_city',
        'to_city_name',
        'to_city_label',
        'dropoff_district',
        'dropoff_district_name',
        'district_to',
        'district_to_name',
        'district_to_label',
        'to_district_text',
      ],
      current: toDistrict,
      fallback: _fallbackDistrictName(toDistrictId),
    );
    final note = type == OrderType.delivery
        ? json['item_type']?.toString()
        : json['note']?.toString();
    final createdAt = _normalizeServerTimestamp(json['created_at']?.toString());
    final rawPrice = json['price'];
    final hasPrice = rawPrice != null && rawPrice.toString().trim().isNotEmpty;
    final parsedPrice = hasPrice ? parseDouble(rawPrice) : 0.0;
    final rawServiceFee =
        json['service_fee'] ?? json['serviceFee'] ?? json['service_fee_amount'];
    var serviceFee = rawServiceFee == null ? 0.0 : parseDouble(rawServiceFee);
    if (serviceFee <= 0 && parsedPrice > 0) {
      final driverEarningsRaw = json['driver_earnings'];
      if (driverEarningsRaw != null) {
        final driverEarnings = parseDouble(driverEarningsRaw);
        final inferred = parsedPrice - driverEarnings;
        if (driverEarnings > 0 && inferred > 0) {
          serviceFee = inferred;
        }
      }
    }
    if (serviceFee <= 0 && parsedPrice > 0) {
      serviceFee = parsedPrice * 0.1; // Fallback to 10% if fee missing
    }
    final customerName =
        json['username']?.toString() ??
        json['customer_name']?.toString() ??
        json['user_name']?.toString();
    final customerPhone =
        json['telephone']?.toString() ??
        json['phone_number']?.toString() ??
        json['user_phone']?.toString() ??
        (type == OrderType.delivery
            ? (json['sender_telephone'] ?? json['receiver_telephone'])
                  ?.toString()
            : null);
    final confirmedAt = _normalizeServerTimestamp(
      json['confirmed_at']?.toString(),
    );
    final isConfirmed = parseBool(json['is_confirmed']);
    final rawGender =
        json['client_gender'] ??
        json['clientGender'] ??
        json['passenger_gender'] ??
        json['gender'] ??
        json['gender_preference'] ??
        json['genderPreference'] ??
        json['passenger_gender_preference'] ??
        json['passengerGenderPreference'];
    final clientGender = parseGender(rawGender) ?? 'both';

    final parsedStatus = usePayloadStatus
        ? (_orderStatusFromValue(json['status']) ??
              _orderStatusFromValue(json['order_status']))
        : null;
    final resolvedStatus = parsedStatus ?? status ?? OrderStatus.pending;

    return AppOrder(
      id: (json['id'] ?? '').toString(),
      ownerId: (json['user_id'] ?? json['customer_id'] ?? '').toString(),
      createdAt: createdAt,
      type: type,
      fromRegion: fromRegion,
      fromDistrict: fromDistrict,
      toRegion: toRegion,
      toDistrict: toDistrict,
      passengers: type == OrderType.taxi ? passengers : 1,
      date: date,
      startTime: start,
      endTime: end,
      price: parsedPrice,
      serviceFee: serviceFee,
      priceAvailable: hasPrice,
      status: resolvedStatus,
      fromRegionId: fromRegionId,
      fromDistrictId: fromDistrictId,
      toRegionId: toRegionId,
      toDistrictId: toDistrictId,
      note: note,
      customerName: customerName,
      customerPhone: customerPhone,
      clientGender: clientGender,
      isConfirmed: isConfirmed,
      confirmedAt: confirmedAt,
    );
  }

  String _preferInlineLocationLabel({
    required Map<String, dynamic> json,
    required List<String> keys,
    required String current,
    required String fallback,
  }) {
    final normalizedCurrent = current.trim();
    final normalizedFallback = fallback.trim();
    final hasMeaningfulCurrent =
        normalizedCurrent.isNotEmpty &&
        (normalizedFallback.isEmpty ||
            normalizedCurrent.toLowerCase() !=
                normalizedFallback.toLowerCase());
    if (hasMeaningfulCurrent) return normalizedCurrent;
    for (final key in keys) {
      final value = json[key];
      final label = _extractLabel(value);
      if (label != null && label.isNotEmpty) return label;
    }
    return normalizedCurrent.isNotEmpty
        ? normalizedCurrent
        : normalizedFallback;
  }

  String? _extractLabel(Object? value) {
    if (value == null) return null;
    if (value is String) return value.trim();
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in const [
        'label',
        'name',
        'name_uz',
        'name_ru',
        'name_uz_lat',
        'name_uz_cyr',
        'title',
        'text',
        'value',
      ]) {
        final nested = map[key];
        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim();
        }
      }
    }
    return value.toString().trim();
  }

  List<AppOrder> _mergeDriverOrders(
    List<AppOrder> current,
    List<AppOrder> incoming,
  ) {
    if (incoming.isEmpty) return current;
    final merged = <String, AppOrder>{};
    for (final order in current) {
      merged[order.id] = order;
    }
    for (final order in incoming) {
      merged[order.id] = order;
    }
    final list = merged.values.toList();
    list.sort(_driverOrderComparator);
    return list;
  }

  void _bucketDriverOrders(Iterable<AppOrder> orders) {
    for (final order in orders) {
      _upsertDriverOrderBucket(order);
    }
  }

  void _upsertDriverOrderBucket(AppOrder order) {
    switch (order.status) {
      case OrderStatus.pending:
        _driverAvailableOrders = _mergeDriverOrders(_driverAvailableOrders, [
          order,
        ]);
        _driverActiveOrders = _driverActiveOrders
            .where((item) => item.id != order.id)
            .toList();
        _driverCompletedOrders = _driverCompletedOrders
            .where((item) => item.id != order.id)
            .toList();
        break;
      case OrderStatus.active:
        _driverActiveOrders = _mergeDriverOrders(_driverActiveOrders, [order]);
        _removeDriverPendingOrder(order.id);
        _driverCompletedOrders = _driverCompletedOrders
            .where((item) => item.id != order.id)
            .toList();
        break;
      case OrderStatus.completed:
      case OrderStatus.cancelled:
        _driverCompletedOrders = _mergeDriverOrders(_driverCompletedOrders, [
          order,
        ]);
        _removeDriverPendingOrder(order.id);
        _driverActiveOrders = _driverActiveOrders
            .where((item) => item.id != order.id)
            .toList();
        break;
    }
  }

  void _recomputeDriverPaginationOffsets() {
    _driverAvailableOffset = _driverAvailableOrders.length;
    _driverActiveOffset = _driverActiveOrders.length;
    _driverCompletedOffset = _driverCompletedOrders.length;
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

  void _pruneDriverPreviewAnchors() {
    if (_driverOrderPreviewAnchors.isEmpty) return;
    _releaseExpiredDriverPreviews();
  }

  Duration _sanitizeDriverPreviewWindow(Duration window) {
    if (window.inSeconds <= 0) {
      return const Duration(minutes: _defaultDriverOrderPreviewMinutes);
    }
    return window;
  }

  void _releaseExpiredDriverPreviews() {
    if (!_isAuthenticated || !_currentUser.isDriver || !_currentUser.driverApproved) {
      return;
    }
    if (_driverOrderPreviewAnchors.isEmpty) return;
    final window = driverOrderPreviewWindow;
    final now = DateTime.now();
    final expired = _driverOrderPreviewAnchors.entries
        .where(
          (entry) =>
              entry.value.add(window).isBefore(now),
        )
        .map((entry) => entry.key)
        .toList(growable: false);
    if (expired.isEmpty) return;
    for (final orderId in expired) {
      final orderType = _resolveDriverPreviewOrderType(orderId);
      if (orderType != null) {
        releaseDriverOrderPreview(
          orderId,
          type: orderType,
          reason: 'expired',
        );
      }
    }
  }

  void _emitDriverRealtimeCommand({
    required String type,
    required String orderId,
    required OrderType orderType,
  }) {
    final numericId = int.tryParse(orderId);
    if (numericId == null) return;
    _realtime.sendDriverEvent({
      'type': type,
      'order_id': numericId,
      'order_type': orderType.name,
    });
  }

  void _persistDriverPreviewAnchors() async {
    if (!_isAuthenticated) return;
    await _ensureStorage();
    await _sessionStorage?.saveDriverPreviewAnchors(_driverOrderPreviewAnchors);
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
      _pruneUnaffordableAvailableOrders();
      await _saveSessionSnapshot();
      notifyListeners();
    } on ApiException {
      // Ignore stat refresh failures.
    }
  }

  void _prependRealtimeNotification(String title, String message) {
    if (_notificationsMuted) return;
    if (title.isEmpty && message.isEmpty) return;
    final notification = AppNotification(
      id: 'rt-${DateTime.now().microsecondsSinceEpoch}',
      title: title.isEmpty ? 'Update' : title,
      message: message,
      timestamp: DateTime.now(),
      category: NotificationCategory.system,
      isRead: false,
    );
    final isDuplicate = _notifications.any(
      (item) => _isSameNotificationContent(item, notification),
    );
    _notifications = [
      notification,
      ..._notifications.where(
        (item) => !_isSameNotificationContent(item, notification),
      ),
    ];
    if (!isDuplicate) {
      _bumpNotificationSignal();
    }
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
    _stopRealtimePolling();
    _realtime.dispose();
    _api.dispose();
    unawaited(_driverIncomingPlayer?.dispose());
    super.dispose();
  }
}

class _PaginatedDriverOrders {
  const _PaginatedDriverOrders({required this.orders, required this.hasMore});

  final List<AppOrder> orders;
  final bool hasMore;
}

typedef _DriverInfo = ({
  int? id,
  String? name,
  String? phone,
  String? vehicle,
  String? plate,
});
