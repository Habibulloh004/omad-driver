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
    ]);
  }
}
