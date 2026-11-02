import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ui.dart';

/// Safely attempts to open an external media URL (e.g., video or web link)
/// using multiple fallback launch modes to maximize device compatibility.
Future<bool> launchMediaUrlSafely(
  BuildContext context,
  String rawUrl, {
  String failureMessage = 'Could not open video.',
}) async {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return false;

  final isNetwork =
      trimmed.startsWith('http://') || trimmed.startsWith('https://');

  if (!isNetwork) {
    // If it's a local file on Android/iOS/Desktop, raw file paths cannot be
    // launched directly with url_launcher due to OS sandbox constraints.
    if (!kIsWeb && File(trimmed).existsSync()) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          'Playing local video directly in the app.',
        );
      }
      return false;
    }

    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.hasScheme) {
      if (context.mounted) {
        showAppSnackBar(context, failureMessage, isError: true);
      }
      return false;
    }
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    if (context.mounted) {
      showAppSnackBar(context, 'Invalid video address.', isError: true);
    }
    return false;
  }

  // Fallback 1: external application (system browser / media player)
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return true;
  } catch (_) {}

  // Fallback 2: in-app browser view / custom tab
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (opened) return true;
  } catch (_) {}

  // Fallback 3: platform default
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (opened) return true;
  } catch (_) {}

  if (context.mounted) {
    showAppSnackBar(context, failureMessage, isError: true);
  }
  return false;
}
