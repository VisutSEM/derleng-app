import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bootstrap.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/session_store.dart';
import '../../data/providers.dart';
import '../../models/app_user.dart';

enum AuthStatus { authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.busy = false,
    this.error,
  });

  final AuthStatus status;
  final AppUser? user;
  final bool busy;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final session = ref.watch(initialSessionProvider);
    return AuthState(
      status: session == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated,
      user: session?.user,
    );
  }

  Future<bool> signIn({required String email, required String password}) {
    return _run(
      () => ref.read(authRepositoryProvider).signIn(
            email: email,
            password: password,
          ),
    );
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _run(
      () => ref.read(authRepositoryProvider).register(
            name: name,
            email: email,
            password: password,
          ),
    );
  }

  Future<bool> signInWithGoogle() {
    return _run(() => ref.read(authRepositoryProvider).signInWithGoogle());
  }

  Future<bool> signInWithTelegram({
    String? username,
    String? name,
    String? photoUrl,
    String? telegramId,
  }) {
    return _run(
      () => ref.read(authRepositoryProvider).signInWithTelegram(
            username: username,
            name: name,
            photoUrl: photoUrl,
            telegramId: telegramId,
          ),
    );
  }

  /// Returns an error message, or `null` on success.
  Future<String?> sendPasswordReset(String email) async {
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      return null;
    } on ApiException catch (error) {
      return error.message;
    } on Object {
      return 'Could not send the reset email. Try again.';
    }
  }

  Future<void> updateProfilePhoto(String? photoUrl) async {
    final updated = await ref.read(authRepositoryProvider).updateProfile(
          photoUrl: photoUrl,
          clearPhotoUrl: photoUrl == null || photoUrl.isEmpty,
        );
    if (!ref.mounted) return;
    state = state.copyWith(user: updated);
  }

  Future<void> updateProfile({String? name, String? photoUrl}) async {
    final updated = await ref.read(authRepositoryProvider).updateProfile(
          name: name,
          photoUrl: photoUrl,
        );
    if (!ref.mounted) return;
    state = state.copyWith(user: updated);
  }

  Future<void> signOut() async {
    state = state.copyWith(busy: true, clearError: true);
    await ref.read(authRepositoryProvider).signOut();
    if (!ref.mounted) return;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(clearError: true);
  }

  Future<bool> _run(Future<AuthSession> Function() action) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final session = await action();
      if (!ref.mounted) return false;
      state = AuthState(
        status: AuthStatus.authenticated,
        user: session.user,
      );
      return true;
    } on ApiException catch (error) {
      if (!ref.mounted) return false;
      state = state.copyWith(busy: false, error: error.message);
      return false;
    } on Object {
      if (!ref.mounted) return false;
      state = state.copyWith(
        busy: false,
        error: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
