import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../core/backend_config.dart';
import '../models/order.dart';
import '../models/user.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AppUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = (json['token'] ?? json['access_token'])?.toString();
    final userJson = json['user'];
    if (token == null || token.isEmpty) {
      throw const FormatException('Missing token in auth response');
    }
    if (userJson is! Map<String, dynamic>) {
      throw const FormatException('Missing user in auth response');
    }
    return AuthSession(token: token, user: AppUser.fromJson(userJson));
  }
}

class ApiClient {
  ApiClient({
    http.Client? client,
    this.baseUrl = apiBaseUrl,
    FutureOr<void> Function()? onUnauthorized,
  }) : _client = client ?? http.Client(),
       _onUnauthorized = onUnauthorized;

  final http.Client _client;
  final String baseUrl;
  String? _token;
  FutureOr<void> Function()? _onUnauthorized;

  void updateToken(String? token) {
    _token = token?.isEmpty ?? true ? null : token;
  }

  void setUnauthorizedHandler(FutureOr<void> Function()? handler) {
    _onUnauthorized = handler;
  }

  Future<AuthSession> login({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await _request(
      'POST',
      '/auth/login',
      body: {'telephone': phoneNumber, 'password': password},
    );
    try {
      return AuthSession.fromJson(_ensureMap(response));
    } on FormatException catch (error) {
      throw ApiException(error.message, statusCode: 0);
    }
  }

  Future<AuthSession> register({
    required String phoneNumber,
    required String password,
    required String fullName,
    required String confirmPassword,
  }) async {
    await _request(
      'POST',
      '/auth/register',
      body: {
        'telephone': phoneNumber,
        'password': password,
        'confirm_password': confirmPassword,
        'name': fullName,
      },
    );
    return login(phoneNumber: phoneNumber, password: password);
  }

  Future<AppUser> fetchProfile() async {
    final response = await _request('GET', '/auth/me', authorized: true);
    return AppUser.fromJson(_ensureMap(response));
  }

  Future<AppUser> updateProfile({
    String? name,
    String? language,
    String? phoneNumber,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (language != null) body['language'] = language;
    if (phoneNumber != null) body['telephone'] = phoneNumber;
    if (body.isEmpty) {
      throw const ApiException('Nothing to update', statusCode: 400);
    }
    final response = await _request(
      'PUT',
      '/auth/profile',
      body: body,
      authorized: true,
    );
    return AppUser.fromJson(_ensureMap(response));
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _request(
      'POST',
      '/auth/change-password',
      authorized: true,
      body: {
        'old_password': oldPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchRegions() async {
    final response = await _request('GET', '/regions/');
    return _ensureListOfMaps(response);
  }

  Future<List<Map<String, dynamic>>> fetchDistricts(int regionId) async {
    final response = await _request('GET', '/regions/$regionId/districts');
    return _ensureListOfMaps(response);
  }

  Future<List<Map<String, dynamic>>> fetchPricing({
    int? fromRegionId,
    int? toRegionId,
    String? serviceType,
  }) async {
    final query = <String, dynamic>{};
    if (fromRegionId != null) {
      query['from_region_id'] = fromRegionId;
    }
    if (toRegionId != null) {
      query['to_region_id'] = toRegionId;
    }
    if (serviceType != null && serviceType.isNotEmpty) {
      query['service_type'] = serviceType;
    }
    final response = await _request(
      'GET',
      '/regions/pricing',
      query: query.isEmpty ? null : query,
    );
    return _ensureListOfMaps(response);
  }

  Future<Map<String, dynamic>> calculatePrice({
    required int fromRegionId,
    required int toRegionId,
    required String serviceType,
    int? passengers,
    int? fromDistrictId,
    int? toDistrictId,
    String? seatType,
  }) async {
    final query = <String, dynamic>{
      'from_region_id': fromRegionId,
      'to_region_id': toRegionId,
      'service_type': serviceType,
    };
    if (passengers != null) {
      query['passengers'] = passengers;
    }
    if (fromDistrictId != null) {
      query['from_district_id'] = fromDistrictId;
    }
    if (toDistrictId != null) {
      query['to_district_id'] = toDistrictId;
    }
    final normalizedSeatType = seatType?.trim();
    if (normalizedSeatType != null && normalizedSeatType.isNotEmpty) {
      query['seat_type'] = normalizedSeatType;
    }
    final response = await _request(
      'GET',
      '/regions/pricing/calculate',
      query: query,
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    throw ApiException('Invalid response from price calculation');
  }

  Future<Map<String, dynamic>> uploadProfilePicture(File file) {
    return _uploadMultipart(path: '/auth/upload-profile-picture', file: file);
  }

  Future<Map<String, dynamic>> uploadDriverLicense(File file) {
    return _uploadMultipart(path: '/driver/upload-license', file: file);
  }

  Future<Map<String, dynamic>> uploadDriverCarPhoto(File file) {
    // Backend currently exposes only /driver/upload-license for driver files.
    // Reuse the same endpoint for car photos.
    return _uploadMultipart(path: '/driver/upload-license', file: file);
  }

  Future<Map<String, dynamic>> uploadDriverTexPas(File file) {
    // Backend currently exposes only /driver/upload-license for driver files.
    // Reuse the same endpoint for tex passport photos.
    return _uploadMultipart(path: '/driver/upload-license', file: file);
  }

  Future<List<Map<String, dynamic>>> fetchUserOrders({
    String? status,
    String? type,
    int? limit,
    int? offset,
  }) async {
    final futures = <Future<List<Map<String, dynamic>>>>[];
    final normalizedType = type?.toLowerCase() == 'all'
        ? null
        : type?.toLowerCase();

    if (normalizedType == null || normalizedType == 'taxi') {
      futures.add(
        _fetchOrders(
          path: '/taxi-orders/',
          orderType: 'taxi',
          status: status,
          limit: limit,
          offset: offset,
        ),
      );
    }
    if (normalizedType == null || normalizedType == 'delivery') {
      futures.add(
        _fetchOrders(
          path: '/delivery-orders/',
          orderType: 'delivery',
          status: status,
          limit: limit,
          offset: offset,
        ),
      );
    }

    if (futures.isEmpty) return const <Map<String, dynamic>>[];
    final results = await Future.wait(futures);
    return results.expand((orders) => orders).toList();
  }

  Future<Map<String, dynamic>> fetchOrder({
    required int id,
    required OrderType type,
  }) async {
    final path = type == OrderType.delivery
        ? '/delivery-orders/$id'
        : '/taxi-orders/$id';
    final response = await _request('GET', path, authorized: true);
    final map = _ensureMap(response);
    map['order_type'] = type.name;
    return map;
  }

  Future<List<Map<String, dynamic>>> _fetchOrders({
    required String path,
    required String orderType,
    String? status,
    int? limit,
    int? offset,
  }) async {
    final query = <String, dynamic>{};
    if (status != null) {
      query['status_filter'] = status;
    }
    if (limit != null) query['limit'] = limit;
    if (offset != null) query['offset'] = offset;
    final response = await _request(
      'GET',
      path,
      authorized: true,
      query: query.isEmpty ? null : query,
    );
    final data = _ensureListOfMaps(response);
    return data
        .map(
          (order) =>
              Map<String, dynamic>.from(order)..['order_type'] = orderType,
        )
        .toList();
  }

  Future<Map<String, dynamic>> createTaxiOrder(
    Map<String, dynamic> body,
  ) async {
    final response = await _request(
      'POST',
      '/taxi-orders/',
      authorized: true,
      body: body,
    );
    return _ensureMap(response);
  }

  Future<Map<String, dynamic>> createDeliveryOrder(
    Map<String, dynamic> body,
  ) async {
    final response = await _request(
      'POST',
      '/delivery-orders/',
      authorized: true,
      body: body,
    );
    return _ensureMap(response);
  }

  Future<void> cancelOrder({
    required int id,
    required OrderType orderType,
    required String reason,
  }) async {
    final path = orderType == OrderType.delivery
        ? '/delivery-orders/cancel'
        : '/taxi-orders/cancel';
    await _request(
      'POST',
      path,
      authorized: true,
      body: {
        'order_id': id,
        'order_type': orderType.name,
        'cancellation_reason': reason,
      },
    );
  }

  Future<void> rateDriver({
    required int driverId,
    required int orderId,
    required OrderType orderType,
    required int rating,
    String? comment,
  }) async {
    final body = <String, dynamic>{
      'driver_id': driverId,
      'order_id': orderId,
      'order_type': orderType.name,
      'rating': rating,
    };
    final sanitizedComment = comment?.trim();
    if (sanitizedComment != null && sanitizedComment.isNotEmpty) {
      body['comment'] = sanitizedComment;
    }
    await _request(
      'POST',
      '/ratings/',
      authorized: true,
      body: body,
    );
  }

  Future<List<Map<String, dynamic>>> fetchNotifications({
    bool unreadOnly = false,
  }) async {
    final path = unreadOnly ? '/notifications/unread' : '/notifications/';
    final response = await _request('GET', path, authorized: true);
    return _ensureListOfMaps(response);
  }

  Future<void> markNotificationRead(int id) async {
    await _request('POST', '/notifications/$id/mark-read', authorized: true);
  }

  Future<Map<String, dynamic>> fetchDriverStatus() async {
    final response = await _request('GET', '/driver/status', authorized: true);
    return _ensureMap(response);
  }

  Future<Map<String, dynamic>> fetchDriverProfile() async {
    final response = await _request('GET', '/driver/profile', authorized: true);
    return _ensureMap(response);
  }

  Future<Map<String, dynamic>> submitDriverApplication({
    required String fullName,
    required String carModel,
    required String carNumber,
    required String licensePath,
    required String carPhotoPath,
    required String texPasPath,
  }) async {
    final response = await _request(
      'POST',
      '/driver/apply',
      authorized: true,
      body: {
        'full_name': fullName,
        'car_model': carModel,
        'car_number': carNumber,
        'license_photo': licensePath,
        'car_photo': carPhotoPath,
        'tex_pas': texPasPath,
      },
    );
    return _ensureMap(response);
  }

  Future<Map<String, dynamic>> fetchDriverStatistics() async {
    final response = await _request(
      'GET',
      '/driver/statistics',
      authorized: true,
    );
    return _ensureMap(response);
  }

  Future<Map<String, dynamic>> fetchDriverNewOrders({
    int? fromRegionId,
    int? toRegionId,
    List<int>? toRegionIds,
    int? regionId,
    OrderType? orderType,
    int? limit,
    int? offset,
  }) async {
    final query = <String, dynamic>{};
    if (fromRegionId != null) {
      query['from_region_id'] = fromRegionId;
    }
    final normalizedToIds =
        toRegionIds?.where((id) => id > 0).toList(growable: false);
    if (normalizedToIds != null && normalizedToIds.isNotEmpty) {
      query['to_region_ids'] = normalizedToIds.join(',');
    } else if (toRegionId != null) {
      query['to_region_id'] = toRegionId;
    }
    if (regionId != null) {
      query['region_id'] = regionId;
    }
    if (orderType != null) {
      query['order_type'] = orderType.name;
    }
    if (limit != null) query['limit'] = limit;
    if (offset != null) query['offset'] = offset;
    final response = await _request(
      'GET',
      '/driver/orders/new',
      authorized: true,
      query: query.isEmpty ? null : query,
    );
    return _ensureMap(response);
  }

  Future<Map<String, dynamic>> fetchDriverActiveOrders({
    int? fromRegionId,
    int? toRegionId,
    List<int>? toRegionIds,
    int? regionId,
    OrderType? orderType,
    int? limit,
    int? offset,
  }) async {
    final query = <String, dynamic>{};
    if (fromRegionId != null) {
      query['from_region_id'] = fromRegionId;
    }
    final normalizedToIds =
        toRegionIds?.where((id) => id > 0).toList(growable: false);
    if (normalizedToIds != null && normalizedToIds.isNotEmpty) {
      query['to_region_ids'] = normalizedToIds.join(',');
    } else if (toRegionId != null) {
      query['to_region_id'] = toRegionId;
    }
    if (regionId != null) {
      query['region_id'] = regionId;
    }
    if (orderType != null) {
      query['order_type'] = orderType.name;
    }
    if (limit != null) query['limit'] = limit;
    if (offset != null) query['offset'] = offset;
    final response = await _request(
      'GET',
      '/driver/orders/active',
      authorized: true,
      query: query.isEmpty ? null : query,
    );
    return _ensureMap(response);
  }

  Future<Map<String, dynamic>> fetchDriverAssignedOrders({
    String? status,
    int? limit,
    int? offset,
  }) async {
    final query = <String, dynamic>{};
    final normalized = status?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      query['status_filter'] = normalized;
    }
    if (limit != null) query['limit'] = limit;
    if (offset != null) query['offset'] = offset;
    final response = await _request(
      'GET',
      '/driver/orders/my-orders',
      authorized: true,
      query: query.isEmpty ? null : query,
    );
    return _ensureMap(response);
  }

  Future<void> previewDriverOrder({
    required int id,
    required OrderType type,
  }) async {
    final response = await _request(
      'POST',
      '/driver/orders/preview/${type.name}/$id',
      authorized: true,
    );
    final map = _ensureMap(response);
    if (map['success'] == false) {
      final message = map['message']?.toString().trim();
      throw ApiException(
        message == null || message.isEmpty
            ? 'Failed to start order preview'
            : message,
        statusCode: 400,
      );
    }
  }

  Future<void> releaseDriverOrderPreview({
    required int id,
    required OrderType type,
    String? reason,
  }) async {
    final response = await _request(
      'POST',
      '/driver/orders/preview/release/${type.name}/$id',
      authorized: true,
      body: reason == null ? null : {'reason': reason},
    );
    final map = _ensureMap(response);
    if (map['success'] == false) {
      final message = map['message']?.toString().trim();
      throw ApiException(
        message == null || message.isEmpty
            ? 'Failed to release order preview'
            : message,
        statusCode: 400,
      );
    }
  }

  Future<void> acceptDriverOrder({
    required int id,
    required OrderType type,
  }) async {
    final response = await _request(
      'POST',
      '/driver/orders/accept/${type.name}/$id',
      authorized: true,
    );
    final map = _ensureMap(response);
    if (map['success'] == false) {
      final message = map['message']?.toString().trim();
      throw ApiException(
        message == null || message.isEmpty ? 'Failed to accept order' : message,
        statusCode: 400,
      );
    }
  }

  Future<Map<String, dynamic>> confirmDriverOrder({
    required int id,
    required OrderType type,
  }) async {
    final response = await _request(
      'POST',
      '/driver/orders/confirm/${type.name}/$id',
      authorized: true,
    );
    final map = _ensureMap(response);
    if (map['success'] == false) {
      final message = map['message']?.toString().trim();
      throw ApiException(
        message == null || message.isEmpty
            ? 'Failed to confirm order'
            : message,
        statusCode: 400,
      );
    }
    final order = map['order'];
    if (order is Map<String, dynamic>) {
      return order;
    }
    if (order is Map) {
      return Map<String, dynamic>.from(order);
    }
    return const {};
  }

  Future<void> completeDriverOrder({
    required int id,
    required OrderType type,
  }) async {
    final response = await _request(
      'POST',
      '/driver/orders/complete/${type.name}/$id',
      authorized: true,
    );
    final map = _ensureMap(response);
    if (map['success'] == false) {
      final message = map['message']?.toString().trim();
      throw ApiException(
        message == null || message.isEmpty
            ? 'Failed to complete order'
            : message,
        statusCode: 400,
      );
    }
  }

  Future<dynamic> _request(
    String method,
    String path, {
    bool authorized = false,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path, query);
    try {
      final headers = _headers(
        authorized: authorized,
        includeContentType: body != null,
      );
      final response = await _send(
        method: method,
        uri: uri,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 20));
      return _parseResponse(response);
    } on ApiException catch (error) {
      if (authorized && error.statusCode == 401) {
        _notifyUnauthorized();
      }
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection', statusCode: 0);
    } on TimeoutException {
      throw const ApiException('Request timed out', statusCode: 0);
    } on http.ClientException catch (error) {
      throw ApiException(error.message, statusCode: 0);
    } on FormatException catch (error) {
      throw ApiException(error.message, statusCode: 0);
    }
  }

  Future<http.Response> _send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Map<String, dynamic>? body,
  }) {
    final encodedBody = body == null
        ? null
        : jsonEncode(body, toEncodable: _toEncodable);
    switch (method.toUpperCase()) {
      case 'GET':
        return _client.get(uri, headers: headers);
      case 'POST':
        return _client.post(uri, headers: headers, body: encodedBody);
      case 'PUT':
        return _client.put(uri, headers: headers, body: encodedBody);
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: encodedBody);
      case 'DELETE':
        return _client.delete(uri, headers: headers, body: encodedBody);
      default:
        throw ApiException('Unsupported HTTP method $method', statusCode: 0);
    }
  }

  Uri _uri(String path, Map<String, dynamic>? query) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    Map<String, String>? queryParameters;
    if (query != null && query.isNotEmpty) {
      queryParameters = <String, String>{};
      query.forEach((key, value) {
        if (value == null) return;
        queryParameters![key] = value.toString();
      });
      if (queryParameters.isEmpty) {
        queryParameters = null;
      }
    }
    return Uri.parse(
      '$baseUrl$normalizedPath',
    ).replace(queryParameters: queryParameters);
  }

  Map<String, String> _headers({
    required bool authorized,
    required bool includeContentType,
  }) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }
    if (authorized) {
      final token = _token;
      if (token == null || token.isEmpty) {
        throw const ApiException('Not authenticated', statusCode: 401);
      }
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _uploadMultipart({
    required String path,
    required File file,
    String fieldName = 'file',
  }) async {
    if (!file.existsSync()) {
      throw const ApiException('Selected file does not exist', statusCode: 400);
    }
    final uri = _uri(path, null);
    final request = http.MultipartRequest('POST', uri);
    final headers = _headers(authorized: true, includeContentType: false);
    request.headers.addAll(headers);

    final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
    final parts = mimeType.split('/');
    final mediaType = MediaType(
      parts.first,
      parts.length > 1 ? parts[1] : 'jpeg',
    );
    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        file.path,
        contentType: mediaType,
      ),
    );

    http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const ApiException('No internet connection', statusCode: 0);
    } on TimeoutException {
      throw const ApiException('Request timed out', statusCode: 0);
    }

    final response = await http.Response.fromStream(streamed);
    final parsed = _parseResponse(response);
    return _ensureMap(parsed);
  }

  void _notifyUnauthorized() {
    final handler = _onUnauthorized;
    if (handler == null) return;
    Future.microtask(() async {
      try {
        await handler();
      } catch (_) {}
    });
  }

  dynamic _parseResponse(http.Response response) {
    final statusCode = response.statusCode;
    if (response.body.isEmpty) {
      if (statusCode >= 200 && statusCode < 300) {
        return null;
      }
      throw ApiException(
        'Request failed with status $statusCode',
        statusCode: statusCode,
      );
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ApiException('Invalid response format', statusCode: 0);
    }

    if (statusCode >= 200 && statusCode < 300) {
      return decoded;
    }

    final message = decoded is Map<String, dynamic> && decoded['error'] != null
        ? decoded['error'].toString()
        : 'Request failed with status $statusCode';
    throw ApiException(message, statusCode: statusCode);
  }

  Map<String, dynamic> _ensureMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException('Unexpected response type', statusCode: 0);
  }

  List<Map<String, dynamic>> _ensureListOfMaps(dynamic data) {
    if (data is List) {
      return data.map<Map<String, dynamic>>((item) {
        if (item is Map<String, dynamic>) return item;
        if (item is Map) return Map<String, dynamic>.from(item);
        throw const ApiException('Unexpected response type', statusCode: 0);
      }).toList();
    }
    throw const ApiException('Unexpected response type', statusCode: 0);
  }

  dynamic _toEncodable(Object? value) => value;

  void dispose() {
    _client.close();
  }
}
