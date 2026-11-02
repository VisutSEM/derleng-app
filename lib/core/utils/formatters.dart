import 'dart:math' as math;

/// Human friendly distance, e.g. `850 m`, `2.4 km`, `18 km`.
String formatDistance(num meters) {
  final value = meters.isFinite ? meters : 0;
  if (value < 1000) return '${value.round()} m';
  final km = value / 1000;
  final digits = km < 10 ? 1 : 0;
  return '${km.toStringAsFixed(digits)} km';
}

/// Compact social counts, e.g. `980`, `1.2K`, `18K`, `2.4M`.
String formatCompactCount(num value) {
  final abs = value.abs();
  if (abs < 1000) return '${value.round()}';
  if (abs < 1000000) {
    final k = value / 1000;
    final text = k >= 10 ? '${k.round()}' : k.toStringAsFixed(1);
    return '${text.replaceAll(RegExp(r'\.0$'), '')}K';
  }
  final m = value / 1000000;
  final text = m >= 10 ? '${m.round()}' : m.toStringAsFixed(1);
  return '${text.replaceAll(RegExp(r'\.0$'), '')}M';
}

/// Relative time for feed posts, e.g. `Just now`, `12 min ago`, `3 d ago`.
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(time);
  if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return '${time.day}/${time.month}/${time.year}';
}

/// Human friendly duration, e.g. `<1 min`, `12 min`, `1 h 05 min`.
String formatDuration(num seconds) {
  final value = seconds.isFinite ? seconds.round() : 0;
  if (value < 60) return '<1 min';
  if (value < 3600) return '${(value / 60).round()} min';
  final hours = value ~/ 3600;
  final minutes = (value % 3600) ~/ 60;
  return minutes == 0 ? '$hours h' : '$hours h ${minutes.toString().padLeft(2, '0')} min';
}

/// Parses a Google-style distance string (`"1.2 km"`, `"450 m"`) into meters.
int parseDistanceMeters(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 0;
  final match = RegExp(r'([\d.,]+)\s*(km|m)\b', caseSensitive: false)
      .firstMatch(raw.trim());
  if (match == null) return 0;
  final value = double.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
  final unit = match.group(2)!.toLowerCase();
  return (unit == 'km' ? value * 1000 : value).round();
}

/// Parses a Google-style duration string (`"25 min"`, `"1 hour 10 mins"`).
int parseDurationSeconds(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 0;
  final text = raw.toLowerCase();
  var total = 0;
  final hours = RegExp(r'(\d+)\s*h(?:our|r)?s?').firstMatch(text);
  final minutes = RegExp(r'(\d+)\s*m(?:in|ins|inute|inutes)?\b').firstMatch(text);
  final seconds = RegExp(r'(\d+)\s*s(?:ec|ecs|econd|econds)?\b').firstMatch(text);
  if (hours != null) total += int.parse(hours.group(1)!) * 3600;
  if (minutes != null) total += int.parse(minutes.group(1)!) * 60;
  if (seconds != null) total += int.parse(seconds.group(1)!);
  if (total == 0) {
    final numeric = int.tryParse(text.replaceAll(RegExp(r'[^\d]'), ''));
    if (numeric != null) total = numeric * 60;
  }
  return total;
}

/// Bearing in degrees from [from] to [to], used to bend demo routes.
double bearingDegrees(double fromLat, double fromLng, double toLat, double toLng) {
  final dLng = (toLng - fromLng) * math.pi / 180;
  final lat1 = fromLat * math.pi / 180;
  final lat2 = toLat * math.pi / 180;
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

String formatRating(double rating) => rating.toStringAsFixed(1);
