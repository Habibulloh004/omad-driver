import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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
    final token = json['token']?.toString();
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

class AuthApi {
  AuthApi({
    http.Client? client,
    this.baseUrl = 'https://api.omad-driver.uz/api/v1',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Map<String, String> get _jsonHeaders => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Uri _url(String path) => Uri.parse('$baseUrl$path');

  Future<AuthSession> login({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await _safePost(
      _url('/auth/login'),
      body: {'phone_number': phoneNumber, 'password': password},
    );
    try {
      return AuthSession.fromJson(response);
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
    final response = await _safePost(
      _url('/auth/register'),
      body: {
        'phone_number': phoneNumber,
        'password': password,
        'confirm_password': confirmPassword,
        'name': fullName,
      },
    );
    try {
      return AuthSession.fromJson(response);
    } on FormatException catch (error) {
      throw ApiException(error.message, statusCode: 0);
    }
  }

  Future<Map<String, dynamic>> _safePost(
    Uri uri, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _client
          .post(uri, headers: _jsonHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _parseResponse(response);
    } on SocketException {
      throw const ApiException('No internet connection', statusCode: 0);
    } on http.ClientException catch (error) {
      throw ApiException(error.message, statusCode: 0);
    } on TimeoutException {
      throw const ApiException('Request timed out', statusCode: 0);
    } on FormatException catch (error) {
      throw ApiException(error.message, statusCode: 0);
    }
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    final statusCode = response.statusCode;
    Map<String, dynamic> data = {};

    if (response.body.isNotEmpty) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else {
        throw const FormatException('Unexpected response structure');
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      return data;
    }

    final message =
        data['error']?.toString() ?? 'Request failed with status $statusCode';
    throw ApiException(message, statusCode: statusCode);
  }

  void dispose() {
    _client.close();
  }
}
