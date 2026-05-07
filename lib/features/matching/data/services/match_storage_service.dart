import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

/// Local storage service for match-related data
/// Primarily used to cache the daily batch limit reset time
class MatchStorageService {
  static const String _keyBatchLimitResetAt = 'match_batch_limit_reset_at';

  final SharedPreferences _prefs;
  final Logger _logger = Logger();

  MatchStorageService(this._prefs);

  /// Save the daily batch limit reset time to local storage
  /// This is used to avoid unnecessary API calls when the limit is exceeded
  Future<void> saveBatchLimitResetTime(DateTime resetAt) async {
    try {
      await _prefs.setString(
        _keyBatchLimitResetAt,
        resetAt.toIso8601String(),
      );
      _logger.d('💾 Saved batch limit reset time: $resetAt');
    } catch (e) {
      _logger.e('❌ Failed to save batch limit reset time', error: e);
    }
  }

  /// Get the daily batch limit reset time from local storage
  /// Returns null if not set or expired
  DateTime? getBatchLimitResetTime() {
    try {
      final resetAtString = _prefs.getString(_keyBatchLimitResetAt);
      if (resetAtString == null) {
        return null;
      }

      final resetAt = DateTime.parse(resetAtString);

      // Check if the reset time has passed
      if (DateTime.now().isAfter(resetAt)) {
        // Reset time has passed, clear it and return null
        clearBatchLimitResetTime();
        _logger.d('🕐 Batch limit reset time has passed, cleared');
        return null;
      }

      return resetAt;
    } catch (e) {
      _logger.e('❌ Failed to get batch limit reset time', error: e);
      return null;
    }
  }

  /// Clear the batch limit reset time from local storage
  Future<void> clearBatchLimitResetTime() async {
    try {
      await _prefs.remove(_keyBatchLimitResetAt);
      _logger.d('🗑️  Cleared batch limit reset time');
    } catch (e) {
      _logger.e('❌ Failed to clear batch limit reset time', error: e);
    }
  }

  /// Check if the daily batch limit is currently active (hasn't reset yet)
  bool isBatchLimitActive() {
    final resetAt = getBatchLimitResetTime();
    return resetAt != null && DateTime.now().isBefore(resetAt);
  }

  /// Get the time remaining until the batch limit resets
  /// Returns null if limit is not active or time has passed
  Duration? getTimeUntilReset() {
    final resetAt = getBatchLimitResetTime();
    if (resetAt == null) {
      return null;
    }

    final now = DateTime.now();
    if (now.isAfter(resetAt)) {
      return null;
    }

    return resetAt.difference(now);
  }
}
