import 'package:intl/intl.dart';

/// Date and time formatting utilities for the dates feature
///
/// All times are shown in the device's local timezone
/// Format: EEE d MMM, HH:mm (e.g., "Sun 20 Sep, 20:00")
class DateFormats {
  DateFormats._();

  /// Format a DateTime to "EEE d MMM, HH:mm" in local timezone
  /// Example: "Sun 20 Sep, 20:00"
  static String formatDateTime(DateTime dateTime) {
    // Convert to local timezone if not already
    final local = dateTime.toLocal();
    return DateFormat('EEE d MMM, HH:mm').format(local);
  }

  /// Format a date range (start to end) in local timezone
  /// Example: "Sun 20 Sep, 19:00 - 21:00"
  static String formatDateTimeRange(DateTime start, DateTime end) {
    final localStart = start.toLocal();
    final localEnd = end.toLocal();

    // Check if same day
    final sameDay = localStart.year == localEnd.year &&
        localStart.month == localEnd.month &&
        localStart.day == localEnd.day;

    if (sameDay) {
      // Same day: show full date once, then time range
      final dateStr = DateFormat('EEE d MMM').format(localStart);
      final startTime = DateFormat('HH:mm').format(localStart);
      final endTime = DateFormat('HH:mm').format(localEnd);
      return '$dateStr, $startTime - $endTime';
    } else {
      // Different days: show full timestamps
      return '${formatDateTime(localStart)} - ${formatDateTime(localEnd)}';
    }
  }

  /// Format just the date part "EEE d MMM"
  /// Example: "Sun 20 Sep"
  static String formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateFormat('EEE d MMM').format(local);
  }

  /// Format just the time part "HH:mm"
  /// Example: "20:00"
  static String formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateFormat('HH:mm').format(local);
  }

  /// Format a relative time difference for countdown display
  /// Examples: "2d 3h left", "5h 12m left", "Under an hour", "Expired"
  static String formatTimeRemaining(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.isNegative) {
      return 'Expired';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    if (days > 0) {
      return '${days}d ${hours}h left';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m left';
    } else if (minutes > 0) {
      return '${minutes}m left';
    } else {
      return 'Under a minute';
    }
  }

  /// Format a duration in a human-readable way
  /// Examples: "2 hours", "30 minutes", "1 day 3 hours"
  static String formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0 && hours > 0) {
      return '$days day${days == 1 ? '' : 's'} $hours hour${hours == 1 ? '' : 's'}';
    } else if (days > 0) {
      return '$days day${days == 1 ? '' : 's'}';
    } else if (hours > 0) {
      return '$hours hour${hours == 1 ? '' : 's'}';
    } else if (minutes > 0) {
      return '$minutes minute${minutes == 1 ? '' : 's'}';
    } else {
      return 'Less than a minute';
    }
  }
}
