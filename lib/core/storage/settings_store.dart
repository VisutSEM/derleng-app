import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_settings.dart';

class SettingsStore {
  SettingsStore(this._prefs);

  static const _themeKey = 'derleng.settings.theme';
  static const _demoKey = 'derleng.settings.demo_mode';
  static const _baseUrlKey = 'derleng.settings.baseUrl';

  final SharedPreferences _prefs;

  AppSettings read() {
    final themeName = _prefs.getString(_themeKey);
    final savedBaseUrl = _prefs.getString(_baseUrlKey);
    // Ignore legacy loopback address if stored in preferences so real devices connect to the LAN IP
    final baseUrl = (savedBaseUrl == null ||
            savedBaseUrl.contains('127.0.0.1') ||
            savedBaseUrl.contains('localhost'))
        ? const AppSettings().apiBaseUrl
        : savedBaseUrl;

    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == themeName,
        orElse: () => ThemeMode.system,
      ),
      demoMode: false,
      apiBaseUrl: baseUrl,
    );
  }

  Future<void> write(AppSettings settings) async {
    await Future.wait([
      _prefs.setString(_themeKey, settings.themeMode.name),
      _prefs.setBool(_demoKey, false),
      _prefs.setString(_baseUrlKey, settings.apiBaseUrl),
    ]);
  }
}
