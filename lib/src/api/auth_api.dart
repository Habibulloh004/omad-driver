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
  ApiClient({http.Client? client, this.baseUrl = apiBaseUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  String? _token;

  void updateToken(String? token) {
    _token = token?.isEmpty ?? true ? null : token;
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

  Future<AppUser> updateProfile({String? name, String? language}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (language != null) body['language'] = language;
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

  Future<Map<String, dynamic>> uploadProfilePicture(File file) {
    return _uploadMultipart(path: '/auth/upload-profile-picture', file: file);
  }

  Future<Map<String, dynamic>> uploadDriverLicense(File file) {
    return _uploadMultipart(path: '/driver/upload-license', file: file);
  }

  Future<List<Map<String, dynamic>>> fetchUserOrders({
    String? status,
    String? type,
  }) async {
    final futures = <Future<List<Map<String, dynamic>>>>[];
    final normalizedType = type?.toLowerCase() == 'all'
        ? null
        : type?.toLowerCase();

    if (normalizedType == null || normalizedType == 'taxi') {
      futures.add(
        _fetchOrders(path: '/taxi-orders/', orderType: 'taxi', status: status),
      );
    }
    if (normalizedType == null || normalizedType == 'delivery') {
      futures.add(
        _fetchOrders(
          path: '/delivery-orders/',
          orderType: 'delivery',
          status: status,
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
  }) async {
    final response = await _request(
      'GET',
      path,
      authorized: true,
      query: status == null ? null : {'status_filter': status},
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
  }) async {
    final query = <String, dynamic>{};
    if (fromRegionId != null) {
      query['from_region_id'] = fromRegionId;
    }
    if (toRegionId != null) {
      query['to_region_id'] = toRegionId;
    }
    final response = await _request(
      'GET',
      '/driver/orders/new',
      authorized: true,
      query: query.isEmpty ? null : query,
    );
    return _ensureMap(response);
  }

  Future<Map<String, dynamic>> fetchDriverActiveOrders() async {
    final response = await _request(
      'GET',
      '/driver/orders/active',
      authorized: true,
    );
    return _ensureMap(response);
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
    final headers = _headers(
      authorized: authorized,
      includeContentType: body != null,
    );
    try {
      final response = await _send(
        method: method,
        uri: uri,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 20));
      return _parseResponse(response);
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
