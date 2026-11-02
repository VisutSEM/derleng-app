import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import 'storage/session_store.dart';

/// Overridden in `main()` with the real instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('sharedPreferencesProvider was not overridden'),
);

/// Restored session, injected before the widget tree is built.
final initialSessionProvider = Provider<AuthSession?>((ref) => null);

/// Persisted settings, injected before the widget tree is built.
final initialSettingsProvider =
    Provider<AppSettings>((ref) => const AppSettings());
