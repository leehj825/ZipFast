import 'package:intl/intl.dart';

/// Formats a byte count as a short human-readable string (`1.4 MB`).
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024.0;
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  final digits = value >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[i]}';
}

/// Formats a date as a short locale-aware string.
String formatDate(DateTime date, String localeName) =>
    DateFormat.yMMMd(localeName).format(date);
