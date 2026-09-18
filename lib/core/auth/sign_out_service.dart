import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

/// Comprehensive sign-out service that clears all user-specific data
///
/// This service ensures complete cleanup when a user signs out:
/// - Firebase authentication session
/// - All SharedPreferences data (except app-level settings if needed)
/// - Cached tokens and user-specific state
///
/// Usage:
/// ```dart
/// final signOutService = SignOutService(firebaseAuth, sharedPrefs);
/// await signOutService.signOut();
/// ```
class SignOutService {
  final FirebaseAuth _firebaseAuth;
  final SharedPreferences _sharedPrefs;
  final Logger _logger;

  SignOutService({
    required FirebaseAuth firebaseAuth,
    required SharedPreferences sharedPrefs,
    Logger? logger,
  })  : _firebaseAuth = firebaseAuth,
        _sharedPrefs = sharedPrefs,
        _logger = logger ??
            Logger(
              printer: PrettyPrinter(
                methodCount: 0,
                errorMethodCount: 5,
                lineLength: 80,
                colors: true,
                printEmojis: true,
                dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
              ),
            );

  /// List of SharedPreferences keys that should NOT be cleared on sign-out
  /// These are app-level settings that should persist across accounts
  static const List<String> _preservedKeys = [
    'app_settings', // App settings (notifications, language preferences)
  ];

  /// Perform complete sign-out and cleanup
  ///
  /// This method:
  /// 1. Attempts to clear all user-specific SharedPreferences data (best-effort)
  /// 2. Always signs out from Firebase Authentication
  /// 3. Logs the cleanup process for debugging
  ///
  /// Local cleanup failures are logged but do not prevent Firebase sign-out.
  /// Only Firebase sign-out failures will throw exceptions.
  ///
  /// Note: Riverpod providers will automatically reset when Firebase auth state changes
  Future<void> signOut() async {
    _logger.i('🚪 Starting complete sign-out process...');

    // Step 1: Best-effort clear user-specific SharedPreferences data
    // Failures are logged but don't prevent Firebase sign-out
    final cleanupResult = await _clearUserData();

    if (cleanupResult.hasFailures) {
      _logger.w('⚠️  Local cleanup incomplete: ${cleanupResult.failedKeys.length} keys failed to clear');
      for (final key in cleanupResult.failedKeys) {
        _logger.w('  - Failed to clear: $key');
      }
    }

    // Step 2: Sign out from Firebase (always attempted, failure throws)
    try {
      await _firebaseAuth.signOut();
      _logger.i('✅ Firebase sign-out successful');

      if (cleanupResult.hasFailures) {
        _logger.w('⚠️  Sign-out complete but local cleanup was incomplete');
      } else {
        _logger.i('🎉 Complete sign-out successful');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Firebase sign-out failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Clear all user-specific data from SharedPreferences
  ///
  /// Returns a [_CleanupResult] indicating success/failure for each key.
  /// Continues processing all keys even if some fail.
  Future<_CleanupResult> _clearUserData() async {
    _logger.d('🗑️  Clearing user-specific SharedPreferences data...');

    final allKeys = _sharedPrefs.getKeys();
    int clearedCount = 0;
    int preservedCount = 0;
    final List<String> failedKeys = [];

    // Clear all keys except preserved ones, continue even if some fail
    for (final key in allKeys) {
      if (_shouldPreserveKey(key)) {
        _logger.d('📌 Preserving key: $key');
        preservedCount++;
        continue;
      }

      try {
        final removed = await _sharedPrefs.remove(key);
        if (!removed) {
          _logger.w('⚠️  Failed to remove preference: $key');
          failedKeys.add(key);
        } else {
          _logger.d('🗑️  Cleared key: $key');
          clearedCount++;
        }
      } catch (e) {
        _logger.w('⚠️  Exception removing preference: $key', error: e);
        failedKeys.add(key);
      }
    }

    if (failedKeys.isEmpty) {
      _logger.i('✅ Cleared $clearedCount keys, preserved $preservedCount keys');
    } else {
      _logger.w('⚠️  Cleared $clearedCount keys, preserved $preservedCount keys, failed ${failedKeys.length} keys');
    }

    return _CleanupResult(
      clearedCount: clearedCount,
      preservedCount: preservedCount,
      failedKeys: failedKeys,
    );
  }

  /// Check if a key should be preserved during sign-out
  bool _shouldPreserveKey(String key) {
    return _preservedKeys.contains(key);
  }

  /// Clear ALL data including app settings (use with caution)
  /// This is typically only used for debugging or complete app reset
  Future<void> clearAllData() async {
    try {
      _logger.w('⚠️  Clearing ALL SharedPreferences data (including app settings)...');
      final cleared = await _sharedPrefs.clear();
      if (!cleared) {
        throw SignOutException('Failed to clear SharedPreferences');
      }
      await _firebaseAuth.signOut();
      _logger.i('✅ All data cleared');
    } catch (e, stackTrace) {
      _logger.e('❌ Error clearing all data', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}

/// Exception thrown when sign-out fails
class SignOutException implements Exception {
  final String message;
  final dynamic originalError;

  SignOutException(this.message, {this.originalError});

  @override
  String toString() => 'SignOutException: $message';
}

/// Result of SharedPreferences cleanup operation
class _CleanupResult {
  final int clearedCount;
  final int preservedCount;
  final List<String> failedKeys;

  _CleanupResult({
    required this.clearedCount,
    required this.preservedCount,
    required this.failedKeys,
  });

  bool get hasFailures => failedKeys.isNotEmpty;
}
