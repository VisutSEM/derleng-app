import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/session_store.dart';
import '../../models/app_user.dart';

abstract class AuthRepository {
  Future<AuthSession> signIn({
    required String email,
    required String password,
  });

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthSession> signInWithGoogle();

  Future<AuthSession> signInWithTelegram({
    String? username,
    String? name,
    String? photoUrl,
    String? telegramId,
  });

  Future<void> sendPasswordReset(String email);

  Future<AppUser> updateProfile({
    String? name,
    String? photoUrl,
    bool clearPhotoUrl = false,
  });

  Future<void> signOut();
}

class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository(this._store);

  final SessionStore _store;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(AppConfig.demoLatency);
    _validateCredentials(email, password);
    return _persist(
      AppUser(
        id: 'demo-${_fingerprint(email)}',
        email: email.trim().toLowerCase(),
        name: _displayName(email),
        provider: 'password',
      ),
    );
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(AppConfig.demoLatency);
    _validateCredentials(email, password);
    if (name.trim().length < 2) {
      throw const ApiException('Please enter your full name.');
    }
    return _persist(
      AppUser(
        id: 'demo-${_fingerprint(email)}',
        email: email.trim().toLowerCase(),
        name: name.trim(),
        provider: 'password',
      ),
    );
  }

  @override
  Future<AuthSession> signInWithGoogle() async {
    await Future<void>.delayed(AppConfig.demoLatency);
    return _persist(
      const AppUser(
        id: 'demo-google',
        email: 'sokha.chan@gmail.com',
        name: 'Sokha Chan',
        provider: 'google',
      ),
    );
  }

  @override
  Future<AuthSession> signInWithTelegram({
    String? username,
    String? name,
    String? photoUrl,
    String? telegramId,
  }) async {
    await Future<void>.delayed(AppConfig.demoLatency);
    final handle = username?.trim().replaceAll('@', '') ?? 'traveler';
    final displayName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : (handle.isNotEmpty ? handle : 'Telegram User');
    final avatar = photoUrl ??
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80';
    return _persist(
      AppUser(
        id: telegramId ?? 'demo-tg-${_fingerprint(handle)}',
        email: '$handle@telegram.org',
        name: displayName,
        photoUrl: avatar,
        provider: 'telegram',
      ),
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await Future<void>.delayed(AppConfig.demoLatency);
    if (!_isEmail(email)) {
      throw const ApiException('Enter a valid email address first.');
    }
  }

  @override
  Future<AppUser> updateProfile({
    String? name,
    String? photoUrl,
    bool clearPhotoUrl = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final currentSession = _store.read();
    final currentUser = currentSession?.user ??
        const AppUser(
          id: 'demo-user',
          email: 'traveler@derleng.app',
          name: 'Traveler',
        );
    final updatedUser = currentUser.copyWith(
      name: name,
      photoUrl: photoUrl,
      clearPhotoUrl: clearPhotoUrl,
    );
    await _store.save(
      AuthSession(
        user: updatedUser,
        token: currentSession?.token ?? 'demo-token',
      ),
    );
    return updatedUser;
  }

  @override
  Future<void> signOut() => _store.clear();

  Future<AuthSession> _persist(AppUser user) async {
    final session = AuthSession(user: user, token: 'demo-session-token');
    await _store.save(session);
    return session;
  }

  static void _validateCredentials(String email, String password) {
    if (!_isEmail(email)) {
      throw const ApiException('Enter a valid email address.');
    }
    if (password.length < 6) {
      throw const ApiException('Password must be at least 6 characters.');
    }
  }

  static bool _isEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  static String _displayName(String email) {
    return AppUser.fromJson({'email': email.trim()}).name;
  }

  static int _fingerprint(String value) {
    var hash = 0;
    for (final code in value.trim().toLowerCase().codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash;
  }
}

/// Expects `POST /auth/login`, `POST /auth/register`,
/// `POST /auth/forgot-password` and `POST /auth/logout`.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._client, this._store);

  final ApiClient _client;
  final SessionStore _store;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final data = await _client.post('/auth/login', data: {
      'email': email.trim(),
      'password': password,
    });
    return _persist(data);
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _client.post('/auth/register', data: {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'device_name': 'derleng-app',
    });
    return _persist(data);
  }

  @override
  Future<AuthSession> signInWithGoogle() async {
    throw const ApiException(
      'Google sign-in is not wired to the API yet. Add Firebase Auth (see README) or use email sign-in.',
    );
  }

  @override
  Future<AuthSession> signInWithTelegram({
    String? username,
    String? name,
    String? photoUrl,
    String? telegramId,
  }) async {
    try {
      final data = await _client.post('/auth/telegram', data: {
        'username': username,
        'name': name,
        'photo_url': photoUrl,
        'telegram_id': telegramId,
      });
      return await _persist(data);
    } catch (_) {
      final handle = username?.trim().replaceAll('@', '') ?? 'traveler';
      final displayName = (name != null && name.trim().isNotEmpty)
          ? name.trim()
          : (handle.isNotEmpty ? handle : 'Telegram Traveler');
      return await _persist(
        AppUser(
          id: telegramId ?? 'tg-${DateTime.now().millisecondsSinceEpoch}',
          email: '$handle@telegram.org',
          name: displayName,
          photoUrl: photoUrl ??
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
          provider: 'telegram',
        ),
      );
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _client.post('/auth/forgot-password', data: {'email': email.trim()});
  }

  @override
  Future<AppUser> updateProfile({
    String? name,
    String? photoUrl,
    bool clearPhotoUrl = false,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (clearPhotoUrl) {
      payload['photo_url'] = null;
    } else if (photoUrl != null) {
      payload['photo_url'] = photoUrl;
    }
    try {
      final res = await _client.put('/auth/profile', data: payload);
      final map = res is Map
          ? (res['data'] is Map
              ? Map<String, dynamic>.from(res['data'] as Map)
              : Map<String, dynamic>.from(res))
          : null;
      final rawUser = map?['user'] is Map ? map!['user'] : map;
      if (rawUser is Map) {
        final user = AppUser.fromJson(Map<String, dynamic>.from(rawUser));
        final current = _store.read();
        await _store.save(AuthSession(user: user, token: current?.token));
        return user;
      }
    } catch (_) {
      // Fallback to local session update if API profile endpoint is pending
    }
    final current = _store.read();
    final updated = (current?.user ??
            const AppUser(id: 'me', email: '', name: 'Traveler'))
        .copyWith(
      name: name,
      photoUrl: photoUrl,
      clearPhotoUrl: clearPhotoUrl,
    );
    await _store.save(AuthSession(user: updated, token: current?.token));
    return updated;
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.post('/auth/logout');
    } on ApiException {
      // Local sign-out still succeeds when the API is unreachable.
    } finally {
      await _store.clear();
    }
  }

  Future<AuthSession> _persist(dynamic data) async {
    final map = data is Map
        ? (data['data'] is Map
            ? Map<String, dynamic>.from(data['data'] as Map)
            : Map<String, dynamic>.from(data))
        : <String, dynamic>{};
    final rawUser = map['user'];
    if (rawUser is! Map) {
      throw const ApiException('The API did not return a user profile.');
    }
    final token = (map['token'] ?? map['access_token'])?.toString();
    final session = AuthSession(
      user: AppUser.fromJson(Map<String, dynamic>.from(rawUser)),
      token: token,
    );
    await _store.save(session);
    return session;
  }
}
