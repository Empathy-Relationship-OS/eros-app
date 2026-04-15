import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/auth/auth_service.dart';

/// Provider for FirebaseAuth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(firebaseAuthProvider),
    ref.read(authServiceProvider),
  );
});

/// Result class for auth operations
class AuthResult {
  final User? user;
  final String? errorMessage;
  final bool isSuccess;

  AuthResult({this.user, this.errorMessage, required this.isSuccess});

  factory AuthResult.success(User user) {
    return AuthResult(user: user, isSuccess: true);
  }

  factory AuthResult.failure(String errorMessage) {
    return AuthResult(errorMessage: errorMessage, isSuccess: false);
  }
}

/// Repository for Firebase Authentication
///
/// Handles authentication operations (sign up, sign in, sign out, password reset).
/// For token management and current user access, delegates to AuthService.
class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final AuthService _authService;

  AuthRepository(this._firebaseAuth, this._authService);

  /// Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Sign up with email and password
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return AuthResult.success(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_handleFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.failure(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return AuthResult.success(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_handleFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.failure(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Get Firebase ID token for backend API calls
  /// Delegates to AuthService for consistent token management
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      return await _authService.getIdToken(forceRefresh: forceRefresh);
    } catch (e) {
      return null;
    }
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      return AuthResult(isSuccess: true, errorMessage: null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_handleFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.failure(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Reload current user data
  /// Delegates to AuthService for consistent user management
  Future<void> reloadUser() async {
    await _authService.reloadUser();
  }

  /// Delete current user account
  Future<AuthResult> deleteAccount() async {
    try {
      await currentUser?.delete();
      return AuthResult(isSuccess: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_handleFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.failure(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Handle Firebase Auth errors and return user-friendly messages
  String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Please contact support.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 8 characters.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'requires-recent-login':
        return 'Please sign in again to complete this action.';
      default:
        return 'Authentication failed: ${e.message ?? "Unknown error"}';
    }
  }
}
