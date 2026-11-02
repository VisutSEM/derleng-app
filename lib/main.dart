import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/bootstrap.dart';
import 'core/storage/session_store.dart';
import 'core/storage/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final session = SessionStore(preferences).read();
  final settings = SettingsStore(preferences).read();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionProvider.overrideWithValue(session),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const DerlengApp(),
    ),
  );
}
