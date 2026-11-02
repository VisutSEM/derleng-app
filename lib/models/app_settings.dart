import 'package:flutter/material.dart';

import '../core/config/app_config.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.demoMode = false,
    this.apiBaseUrl = AppConfig.apiBaseUrl,
  });

  final ThemeMode themeMode;

  /// When true the app serves sample data and skips the Laravel API.
  final bool demoMode;

  final String apiBaseUrl;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? demoMode,
    String? apiBaseUrl,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      demoMode: demoMode ?? this.demoMode,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    );
  }
}
