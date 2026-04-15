import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: FirebaseAuth.instance,
  );
});

/// Core authentication service that provides authentication primitives
/// to be used across all repositories requiring authenticated API calls.
///
/// This service is responsible for:
/// - Managing Firebase authentication state
/// - Providing ID tokens for API authentication
/// - Handling token refresh logic
/// - Centralizing auth error handling
///
/// Usage:
/// ```dart
/// class MyRepository {
///   final AuthService _authService;
///
///   MyRepository(this._authService);
///
///   Future<void> makeApiCall() async {
///     final token = await _authService.getIdToken();
///     // Use token in Authorization header
///   }
/// }
/// ```
class AuthService {
  final FirebaseAuth _auth;
  final Logger _logger;

  AuthService({
    required FirebaseAuth auth,
    Logger? logger,
  })  : _auth = auth,
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

  /// Get the current authenticated user
  /// Returns null if no user is signed in
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes
  /// Emits the current user whenever auth state changes (sign in, sign out, token refresh)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get Firebase ID token for API authentication
  ///
  /// This token should be included in the Authorization header as:
  /// `Authorization: Bearer <token>`
  ///
  /// Parameters:
  /// - [forceRefresh]: If true, forces Firebase to refresh the token.
  ///   Use this after operations that update custom claims (e.g., user role changes)
  ///
  /// Throws:
  /// - [AuthServiceException] if user is not authenticated or token retrieval fails
  Future<String> getIdToken({bool forceRefresh = false}) async {
    _logger.d('Getting Firebase ID token (forceRefresh: $forceRefresh)...');

    final user = _auth.currentUser;
    if (user == null) {
      _logger.e('No authenticated user found');
      throw AuthServiceException('User not authenticated');
    }

    _logger.d('User authenticated: ${user.uid}');

    try {
      final token = await user.getIdToken(forceRefresh);
      if (token == null) {
        _logger.e('Failed to retrieve ID token');
        throw AuthServiceException('Failed to get authentication token');
      }

      _logger.d('Successfully retrieved ID token (length: ${token.length})');
      return token;
    } catch (e) {
      if (e is AuthServiceException) rethrow;
      _logger.e('Error getting ID token', error: e);
      throw AuthServiceException('Failed to get authentication token');
    }
  }

  /// Get the current user's UID
  ///
  /// Throws:
  /// - [AuthServiceException] if user is not authenticated
  String getUserId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthServiceException('User not authenticated');
    }
    return user.uid;
  }

  /// Reload the current user's data from Firebase
  ///
  /// Useful for fetching updated user metadata or custom claims
  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
    }
  }

  /// Check if a user is currently authenticated
  bool isAuthenticated() {
    return _auth.currentUser != null;
  }
}

/// Exception thrown by AuthService when authentication operations fail
class AuthServiceException implements Exception {
  final String message;

  AuthServiceException(this.message);

  @override
  String toString() => 'AuthServiceException: $message';
}
