import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/auth/google_sign_in_config.dart';
import 'package:eros_app/core/auth/sign_out_service.dart';
import 'package:eros_app/core/notifications/push_service.dart';
import 'package:eros_app/features/auth/domain/models/provider_name.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// Provider for FirebaseAuth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Provider for SignOutService
final signOutServiceProvider = Provider<SignOutService>((ref) {
  return SignOutService(
    firebaseAuth: ref.read(firebaseAuthProvider),
    sharedPrefs: ref.read(sharedPreferencesProvider),
    pushService: ref.read(pushServiceProvider),
    googleSignIn: ref.read(googleSignInProvider),
  );
});

/// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(firebaseAuthProvider),
    ref.read(authServiceProvider),
    ref.read(signOutServiceProvider),
    googleSignIn: ref.read(googleSignInProvider),
    profileDraft: () => ref.read(profileCreationProvider.notifier),
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

/// What the user sees when Google sign-in is misconfigured or unavailable on the device.
const googleUnavailableMessage = "Google sign-in isn't available right now. Try again or use email.";

/// Any other Google sign-in failure. It never says which way an email signs in (RFC-011 D-10).
const googleFailedMessage = "We couldn't sign you in with Google. Try again or use email.";

/// Repository for Firebase Authentication
///
/// Handles authentication operations (sign up, sign in, sign out, password reset).
/// For token management and current user access, delegates to AuthService.
class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final AuthService _authService;
  final SignOutService _signOutService;
  final GoogleSignIn _googleSignIn;

  /// The onboarding draft, which a provider's name prefills (RFC-011 D-7).
  final ProfileCreationNotifier Function() _profileDraft;

  /// Logs error codes and uids only: never a token, an email or a name (RFC-011 primer rule 10).
  final Logger _logger;

  AuthRepository(
    this._firebaseAuth,
    this._authService,
    this._signOutService, {
    required GoogleSignIn googleSignIn,
    required ProfileCreationNotifier Function() profileDraft,
    Logger? logger,
  })  : _googleSignIn = googleSignIn,
        _profileDraft = profileDraft,
        _logger = logger ?? Logger(printer: PrettyPrinter(methodCount: 0));

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

  /// Continue with Google (RFC-011 §5.2): one call for both sign-up and sign-in. `AuthLoadingScreen`
  /// then decides between the app and profile creation.
  ///
  /// Returns null when the user closes Google's sheet, so the screen shows nothing (primer
  /// rule 12). Asks Google for no access token and no extra scopes (D-6).
  Future<AuthResult?> signInWithGoogle() async {
    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      // The code only: the exception's description can carry account details.
      _logger.w('Google sign-in failed (${e.code.name})');
      return AuthResult.failure(_googleErrorMessage(e.code));
    } catch (e) {
      // Thrown before `initialize` has finished, or by a platform without Google sign-in.
      _logger.w('Google sign-in failed (${e.runtimeType})');
      return AuthResult.failure(googleUnavailableMessage);
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      // Android returns no ID token without a server client id: a configuration problem.
      _logger.w('Google sign-in returned no ID token');
      await _signOutOfGoogle();
      return AuthResult.failure(googleUnavailableMessage);
    }

    final UserCredential userCredential;
    try {
      userCredential = await _firebaseAuth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on FirebaseAuthException catch (e) {
      _logger.w('Firebase rejected the Google credential (${e.code})');
      // So that trying again shows Google's account picker rather than the same account.
      await _signOutOfGoogle();
      return AuthResult.failure(_handleGoogleFirebaseAuthError(e));
    } catch (e) {
      _logger.w('Firebase rejected the Google credential (${e.runtimeType})');
      await _signOutOfGoogle();
      return AuthResult.failure(googleFailedMessage);
    }

    final user = userCredential.user;
    if (user == null) return AuthResult.failure(googleFailedMessage);
    _logger.i('Signed in with Google: ${user.uid}');

    final profile = userCredential.additionalUserInfo?.profile;
    await _prefillDraftName(ProviderName.from(
      givenName: _stringOrNull(profile?['given_name']),
      familyName: _stringOrNull(profile?['family_name']),
      displayName: account.displayName ?? user.displayName,
    ));
    return AuthResult.success(user);
  }

  /// Puts a provider's name in the onboarding draft when the draft has no name yet, so
  /// `NameInputScreen` starts from it. A name the user typed is never replaced. A failure here
  /// doesn't fail the sign-in: the user can still type a name.
  Future<void> _prefillDraftName(ProviderName? name) async {
    if (name == null) return;
    try {
      await _profileDraft().prefillName(firstName: name.firstName, lastName: name.lastName);
    } catch (e) {
      _logger.w('Could not prefill the name from Google (${e.runtimeType})');
    }
  }

  Future<void> _signOutOfGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Best-effort: at worst the next attempt offers the same Google account first.
    }
  }

  static String? _stringOrNull(Object? value) => value is String ? value : null;

  String _googleErrorMessage(GoogleSignInExceptionCode code) {
    switch (code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
      case GoogleSignInExceptionCode.uiUnavailable:
        return googleUnavailableMessage;
      case GoogleSignInExceptionCode.interrupted:
        return 'Google sign-in was interrupted. Please try again.';
      default:
        return googleFailedMessage;
    }
  }

  /// Firebase's errors for a Google credential. The email and password wording of
  /// [_handleFirebaseAuthError] doesn't fit some of them.
  String _handleGoogleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      // The Google provider is off in the Firebase project, or the client is wrong (SI-C1).
      case 'operation-not-allowed':
      case 'invalid-credential':
      case 'app-not-authorized':
        return googleUnavailableMessage;
      // An Apple or password account already has this email. SI-F3 adds the flow that links them;
      // until then a message that doesn't say how that email signs in (D-10).
      case 'account-exists-with-different-credential':
        return googleFailedMessage;
      case 'user-disabled':
      case 'too-many-requests':
      case 'network-request-failed':
        return _handleFirebaseAuthError(e);
      default:
        return googleFailedMessage;
    }
  }

  /// Sign out
  /// Performs complete sign-out including clearing all user-specific data
  Future<void> signOut() async {
    await _signOutService.signOut();
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
