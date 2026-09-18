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
  /// 1. Clears all user-specific SharedPreferences data
  /// 2. Signs out from Firebase Authentication
  /// 3. Logs the cleanup process for debugging
  ///
  /// Note: Riverpod providers will automatically reset when Firebase auth state changes
  Future<void> signOut() async {
    try {
      _logger.i('🚪 Starting complete sign-out process...');

      // Step 1: Clear user-specific SharedPreferences data
      await _clearUserData();

      // Step 2: Sign out from Firebase
      await _firebaseAuth.signOut();
      _logger.i('✅ Firebase sign-out successful');

      _logger.i('🎉 Complete sign-out successful');
    } catch (e, stackTrace) {
      _logger.e('❌ Error during sign-out', error: e, stackTrace: stackTrace);
      // Still attempt Firebase sign-out even if clearing data fails
      try {
        await _firebaseAuth.signOut();
      } catch (authError) {
        _logger.e('❌ Firebase sign-out also failed', error: authError);
      }
      rethrow;
    }
  }

  /// Clear all user-specific data from SharedPreferences
  Future<void> _clearUserData() async {
    try {
      _logger.d('🗑️  Clearing user-specific SharedPreferences data...');

      // Get all keys
      final allKeys = _sharedPrefs.getKeys();
      int clearedCount = 0;
      int preservedCount = 0;

      // Clear all keys except preserved ones
      for (final key in allKeys) {
        if (_shouldPreserveKey(key)) {
          _logger.d('📌 Preserving key: $key');
          preservedCount++;
          continue;
        }

        final removed = await _sharedPrefs.remove(key);
        if (!removed) {
          throw SignOutException('Failed to remove preference: $key');
        }
        _logger.d('🗑️  Cleared key: $key');
        clearedCount++;
      }

      _logger.i('✅ Cleared $clearedCount keys, preserved $preservedCount keys');
    } catch (e) {
      _logger.e('❌ Error clearing SharedPreferences', error: e);
      rethrow;
    }
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
