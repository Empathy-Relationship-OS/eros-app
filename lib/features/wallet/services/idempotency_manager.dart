import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';

/// Manages idempotency keys for wallet operations
///
/// Idempotency keys prevent duplicate charges if a user retries a failed payment.
/// The same key should be used for retries of the same purchase attempt.
class IdempotencyManager {
  static const String _keyPrefix = 'idempotency_';
  static const String _currentPurchaseKey = 'current_purchase_idempotency';

  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  /// Get or create an idempotency key for the current purchase flow
  ///
  /// This key persists across app restarts to handle network failures.
  /// Returns the same key if called multiple times for the same purchase attempt.
  Future<String> getCurrentPurchaseKey() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if we have an existing key
    final existingKey = prefs.getString(_currentPurchaseKey);

    if (existingKey != null) {
      _logger.d('♻️  Reusing existing purchase idempotency key');
      return existingKey;
    }

    // Generate new key
    final newKey = _uuid.v4();
    await prefs.setString(_currentPurchaseKey, newKey);
    _logger.d('🔑 Generated new purchase idempotency key');

    return newKey;
  }

  /// Clear the current purchase idempotency key after successful completion
  ///
  /// Call this after a successful purchase to allow new purchases.
  Future<void> clearCurrentPurchaseKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentPurchaseKey);
    _logger.d('🗑️  Cleared purchase idempotency key');
  }

  /// Generate a new idempotency key for a specific operation
  ///
  /// Use this for operations other than purchases (e.g., refunds, spends).
  String generateKey() {
    return _uuid.v4();
  }

  /// Store an idempotency key for a specific operation
  ///
  /// Parameters:
  /// - [operationId]: Unique identifier for the operation (e.g., 'refund_123')
  /// - [key]: The idempotency key to store (optional, generates new if not provided)
  ///
  /// Returns the stored key.
  Future<String> getOrCreateKey(String operationId) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_keyPrefix$operationId';

    // Check if we have an existing key
    final existingKey = prefs.getString(storageKey);

    if (existingKey != null) {
      _logger.d('♻️  Reusing idempotency key for $operationId');
      return existingKey;
    }

    // Generate and store new key
    final newKey = _uuid.v4();
    await prefs.setString(storageKey, newKey);
    _logger.d('🔑 Generated new idempotency key for $operationId');

    return newKey;
  }

  /// Clear an operation-specific idempotency key
  Future<void> clearKey(String operationId) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_keyPrefix$operationId';
    await prefs.remove(storageKey);
    _logger.d('🗑️  Cleared idempotency key for $operationId');
  }

  /// Clear all stored idempotency keys
  ///
  /// Use with caution - typically only needed for cleanup or logout.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_keyPrefix) || key == _currentPurchaseKey) {
        await prefs.remove(key);
      }
    }

    _logger.d('🗑️  Cleared all idempotency keys');
  }
}
