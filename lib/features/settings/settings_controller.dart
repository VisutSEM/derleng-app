import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bootstrap.dart';
import '../../core/storage/settings_store.dart';
import '../../models/app_settings.dart';

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  SettingsStore get _store => SettingsStore(ref.read(sharedPreferencesProvider));

  Future<void> setThemeMode(ThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));

  Future<void> setDemoMode(bool enabled) =>
      _update(state.copyWith(demoMode: enabled));

  Future<void> setApiBaseUrl(String value) =>
      _update(state.copyWith(apiBaseUrl: value.trim()));

  Future<void> resetApiBaseUrl() => _update(
        state.copyWith(apiBaseUrl: const AppSettings().apiBaseUrl),
      );

  Future<void> _update(AppSettings next) async {
    state = next;
    try {
      await _store.write(next);
    } on Object {
      // Preferences are best-effort; the in-memory value still applies.
    }
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
