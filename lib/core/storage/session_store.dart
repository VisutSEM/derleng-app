import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';

class AuthSession {
  const AuthSession({required this.user, this.token});

  final AppUser user;
  final String? token;

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        if (token != null) 'token': token,
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return AuthSession(
      user: AppUser.fromJson(
        rawUser is Map ? Map<String, dynamic>.from(rawUser) : const {},
      ),
      token: json['token'] as String?,
    );
  }
}

class SessionStore {
  SessionStore(this._prefs);

  static const _key = 'derleng.session.v1';
  final SharedPreferences _prefs;

  AuthSession? read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AuthSession.fromJson(decoded);
      }
    } catch (_) {
      // Corrupted session — treat as signed out.
    }
    return null;
  }

  Future<void> save(AuthSession session) =>
      _prefs.setString(_key, jsonEncode(session.toJson()));

  Future<void> clear() => _prefs.remove(_key);
}
