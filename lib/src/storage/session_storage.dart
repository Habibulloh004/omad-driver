import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

class StoredSession {
  StoredSession({
    required this.token,
    required this.userJson,
    required this.savedAt,
  });

  final String token;
  final Map<String, dynamic> userJson;
  final DateTime savedAt;
}

class SessionStorage {
  SessionStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _tokenKey = 'session_token';
  static const _userKey = 'session_user';
  static const _savedAtKey = 'session_saved_at';
  static const _driverPreviewAnchorsKey = 'driver_preview_anchors';
  static const _ratedOrdersKey = 'rated_orders';

  static Future<SessionStorage> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    return SessionStorage(prefs);
  }

  Future<void> saveSession({
    required String token,
    required AppUser user,
    DateTime? savedAt,
  }) async {
    final timestamp = (savedAt ?? DateTime.now()).toIso8601String();
    final encodedUser = jsonEncode(user.toJson());
    await Future.wait<bool>([
      _prefs.setString(_tokenKey, token),
      _prefs.setString(_userKey, encodedUser),
      _prefs.setString(_savedAtKey, timestamp),
    ]);
  }

  Future<void> updateUser(AppUser user) async {
    if (!_prefs.containsKey(_tokenKey)) return;
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<StoredSession?> read() async {
    final token = _prefs.getString(_tokenKey);
    final userString = _prefs.getString(_userKey);
    final savedAtRaw = _prefs.getString(_savedAtKey);
    if (token == null || userString == null || savedAtRaw == null) {
      return null;
    }
    final savedAt = DateTime.tryParse(savedAtRaw);
    if (savedAt == null) return null;
    try {
      final decoded = jsonDecode(userString);
      if (decoded is! Map<String, dynamic>) return null;
      return StoredSession(
        token: token,
        userJson: Map<String, dynamic>.from(decoded),
        savedAt: savedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await Future.wait<bool?>([
      _prefs.remove(_tokenKey),
      _prefs.remove(_userKey),
      _prefs.remove(_savedAtKey),
      _prefs.remove(_driverPreviewAnchorsKey),
      _prefs.remove(_ratedOrdersKey),
    ]);
  }

  Future<void> saveDriverPreviewAnchors(Map<String, DateTime> anchors) async {
    if (anchors.isEmpty) {
      await _prefs.remove(_driverPreviewAnchorsKey);
      return;
    }
    final encoded = anchors.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );
    await _prefs.setString(_driverPreviewAnchorsKey, jsonEncode(encoded));
  }

  Future<Map<String, DateTime>> readDriverPreviewAnchors() async {
    final raw = _prefs.getString(_driverPreviewAnchorsKey);
    if (raw == null || raw.isEmpty) return <String, DateTime>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, DateTime>{};
      final parsed = <String, DateTime>{};
      decoded.forEach((key, value) {
        if (key is! String) return;
        final iso = value?.toString() ?? '';
        final ts = DateTime.tryParse(iso);
        if (ts != null) parsed[key] = ts;
      });
      return parsed;
    } catch (_) {
      return <String, DateTime>{};
    }
  }

  Future<Set<String>> readRatedOrders() async {
    final raw = _prefs.getStringList(_ratedOrdersKey);
    if (raw == null) return <String>{};
    return raw.where((id) => id.isNotEmpty).toSet();
  }

  Future<void> saveRatedOrders(Set<String> orderIds) async {
    if (orderIds.isEmpty) {
      await _prefs.remove(_ratedOrdersKey);
      return;
    }
    await _prefs.setStringList(_ratedOrdersKey, orderIds.toList());
  }
}
