import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:eros_app/core/auth/apple_sign_in.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/auth/google_sign_in_config.dart';
import 'package:eros_app/core/auth/sign_out_service.dart';
import 'package:eros_app/core/notifications/push_service.dart';
import 'package:eros_app/features/auth/domain/models/account_link.dart';
import 'package:eros_app/features/auth/domain/models/delete_account_result.dart';
import 'package:eros_app/features/auth/domain/models/provider_name.dart';
import 'package:eros_app/features/legal/data/account_repository.dart';
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
/// Typed, not inferred: through the API client it depends on itself (via the auth state).
final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(firebaseAuthProvider),
    ref.read(authServiceProvider),
    ref.read(signOutServiceProvider),
    googleSignIn: ref.read(googleSignInProvider),
    appleSignIn: ref.read(appleSignInClientProvider),
    profileDraft: () => ref.read(profileCreationProvider.notifier),
    // Read when used: the API client watches the auth state, which reads this provider.
    accountRepository: () => ref.read(accountRepositoryProvider),
  );
});

/// Result class for auth operations
class AuthResult {
  final User? user;
  final String? errorMessage;
  final bool isSuccess;

  /// Set when the email already has an account: the user signs in with their password, then the
  /// app adds this sign-in to it (RFC-011 §5.4). Not a success, and carries no message.
  final PendingAccountLink? pendingLink;

  AuthResult({this.user, this.errorMessage, required this.isSuccess, this.pendingLink});

  /// True when the screen should ask for the password and then link [pendingLink].
  bool get needsLink => pendingLink != null;

  factory AuthResult.success(User user) {
    return AuthResult(user: user, isSuccess: true);
  }

  factory AuthResult.failure(String errorMessage) {
    return AuthResult(errorMessage: errorMessage, isSuccess: false);
  }

  factory AuthResult.needsLink(PendingAccountLink link) {
    return AuthResult(pendingLink: link, isSuccess: false);
  }
}

/// What the user sees when Google sign-in is misconfigured or unavailable on the device.
const googleUnavailableMessage = "Google sign-in isn't available right now. Try again or use email.";

/// Any other Google sign-in failure. It never says which way an email signs in (RFC-011 D-10).
const googleFailedMessage = "We couldn't sign you in with Google. Try again or use email.";

/// What the user sees when Sign in with Apple is unavailable or not set up on the device.
const appleUnavailableMessage = "Apple sign-in isn't available right now. Try again or use email.";

/// Any other Apple sign-in failure. It never says which way an email signs in (RFC-011 D-10).
const appleFailedMessage = "We couldn't sign you in with Apple. Try again or use email.";

/// The user signed in with their password, but adding Google or Apple to the account failed.
String accountLinkFailedMessage(LinkingProvider provider) =>
    "Signed in. We couldn't add ${provider.label} this time.";

/// Email sign-up with an address that already has an account, of any kind. It never says which
/// (D-10). Apple is named only where the app offers it (D-2).
String emailAlreadyRegisteredMessage({required bool appleOffered}) => appleOffered
    ? 'This email is already registered. Sign in, or try Continue with Google or Apple.'
    : 'This email is already registered. Sign in, or try Continue with Google.';

/// A failed email sign-in. Also covers an account whose password Google removed when it took
/// over the Gmail address (RFC-011 §5.4), which the app can't tell apart without a lookup.
String incorrectEmailOrPasswordMessage({required bool appleOffered}) => appleOffered
    ? 'Incorrect email or password. If you signed up with Google or Apple, use that button instead.'
    : 'Incorrect email or password. If you signed up with Google, use that button instead.';

/// Firebase's code when the email already has an account that signs in another way.
const _accountExistsCode = 'account-exists-with-different-credential';

/// Repository for Firebase Authentication
///
/// Handles authentication operations (sign up, sign in, sign out, password reset).
/// For token management and current user access, delegates to AuthService.
class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final AuthService _authService;
  final SignOutService _signOutService;
  final GoogleSignIn _googleSignIn;
  final AppleSignInClient _appleSignIn;

  /// True where Apple is offered: iOS only (D-2). Every Apple call checks it first.
  final bool Function() _appleSupported;

  /// The onboarding draft, which a provider's name prefills (RFC-011 D-7).
  final ProfileCreationNotifier Function() _profileDraft;

  /// `DELETE /users/me` for [deleteAccount]. The provider always passes it.
  final AccountRepository Function()? _accountRepository;

  /// Logs error codes and uids only: never a token, an email or a name (RFC-011 primer rule 10).
  final Logger _logger;

  AuthRepository(
    this._firebaseAuth,
    this._authService,
    this._signOutService, {
    required GoogleSignIn googleSignIn,
    required AppleSignInClient appleSignIn,
    required ProfileCreationNotifier Function() profileDraft,
    bool Function() appleSupported = appleSignInSupported,
    AccountRepository Function()? accountRepository,
    Logger? logger,
  })  : _googleSignIn = googleSignIn,
        _appleSignIn = appleSignIn,
        _appleSupported = appleSupported,
        _profileDraft = profileDraft,
        _accountRepository = accountRepository,
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
      if (e.code == 'email-already-in-use') {
        return AuthResult.failure(emailAlreadyRegisteredMessage(appleOffered: _appleSupported()));
      }
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
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return AuthResult.failure(incorrectEmailOrPasswordMessage(appleOffered: _appleSupported()));
      }
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

    final googleCredential = GoogleAuthProvider.credential(idToken: idToken);
    final UserCredential userCredential;
    try {
      userCredential = await _firebaseAuth.signInWithCredential(googleCredential);
    } on FirebaseAuthException catch (e) {
      _logger.w('Firebase rejected the Google credential (${e.code})');
      // So that trying again shows Google's account picker rather than the same account.
      await _signOutOfGoogle();
      if (e.code == _accountExistsCode) {
        final link = _pendingLink(
          e,
          LinkingProvider.google,
          fallbackEmail: () => account.email,
          fallbackCredential: googleCredential,
        );
        if (link != null) return AuthResult.needsLink(link);
      }
      return AuthResult.failure(_handleProviderFirebaseAuthError(
        e,
        unavailable: googleUnavailableMessage,
        failed: googleFailedMessage,
      ));
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

  /// Continue with Apple (RFC-011 §5.3), iOS only (D-2): one call for both sign-up and sign-in,
  /// like [signInWithGoogle].
  ///
  /// Returns null when the user closes Apple's sheet (primer rule 12). Apple sends the user's name
  /// only on their first authorisation of Muse, so it goes into the onboarding draft before the
  /// Firebase call and onto the Firebase user straight after it, before anything else (rule 13).
  /// The email may be an Apple relay address; it's used like any other (rule 14).
  Future<AuthResult?> signInWithApple() async {
    if (!_appleSupported()) return AuthResult.failure(appleUnavailableMessage);

    final AppleAuthorization? apple;
    try {
      apple = await requestAppleAuthorization();
    } on SignInWithAppleAuthorizationException catch (e) {
      // The code only: the message is Apple's and isn't ours to log.
      _logger.w('Apple sign-in failed (${e.code.name})');
      return AuthResult.failure(_appleErrorMessage(e.code));
    } catch (e) {
      // Not supported on this device, or the plugin isn't set up.
      _logger.w('Apple sign-in failed (${e.runtimeType})');
      return AuthResult.failure(appleUnavailableMessage);
    }
    if (apple == null) return null;

    // Kept before anything else can fail: Apple won't send it again (D-7).
    final appleName = ProviderName.from(givenName: apple.givenName, familyName: apple.familyName);
    if (appleName != null) await _saveAppleNameToDraft(appleName);

    final credential = apple.firebaseCredential;
    if (credential == null) {
      _logger.w('Apple sign-in returned no identity token');
      return AuthResult.failure(appleUnavailableMessage);
    }

    final UserCredential userCredential;
    try {
      userCredential = await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      _logger.w('Firebase rejected the Apple credential (${e.code})');
      if (e.code == _accountExistsCode) {
        final link = _pendingLink(e, LinkingProvider.apple, fallbackCredential: credential);
        if (link != null) return AuthResult.needsLink(link);
      }
      return AuthResult.failure(_handleProviderFirebaseAuthError(
        e,
        unavailable: appleUnavailableMessage,
        failed: appleFailedMessage,
      ));
    } catch (e) {
      _logger.w('Firebase rejected the Apple credential (${e.runtimeType})');
      return AuthResult.failure(appleFailedMessage);
    }

    final user = userCredential.user;
    if (user == null) return AuthResult.failure(appleFailedMessage);

    if (appleName != null) {
      // The first await after signing in, so the name is on the account before anything else.
      await _saveDisplayName(user, appleName);
    } else {
      // A later sign-in: no name from Apple. Keep the draft's, else use the account's.
      await _prefillDraftName(ProviderName.from(displayName: user.displayName));
    }
    _logger.i('Signed in with Apple: ${user.uid}');
    return AuthResult.success(user);
  }

  /// Adds a Google or Apple sign-in to the account the user has just signed in to with their
  /// password (RFC-011 §5.4). A failure leaves them signed in: the screen says so and carries on.
  Future<AuthResult> linkPendingCredential(PendingAccountLink link) async {
    final user = currentUser;
    if (user == null) {
      _logger.w('Nobody signed in to add ${link.provider.name} to');
      return AuthResult.failure(accountLinkFailedMessage(link.provider));
    }
    try {
      final userCredential = await user.linkWithCredential(link.credential);
      final linked = userCredential.user ?? user;
      _logger.i('Added ${link.provider.name} sign-in to ${linked.uid}');
      return AuthResult.success(linked);
    } on FirebaseAuthException catch (e) {
      _logger.w('Could not add ${link.provider.name} sign-in to ${user.uid} (${e.code})');
      return AuthResult.failure(accountLinkFailedMessage(link.provider));
    } catch (e) {
      _logger.w('Could not add ${link.provider.name} sign-in to ${user.uid} (${e.runtimeType})');
      return AuthResult.failure(accountLinkFailedMessage(link.provider));
    }
  }

  /// What `account-exists-with-different-credential` needs for the password-then-link flow: the
  /// email and pending credential Firebase reports, else the ones this sign-in had. Null when
  /// either is missing; the caller then shows its generic message. Never looks the email up
  /// (primer rule 11) and never logs it or the credential (rule 10).
  PendingAccountLink? _pendingLink(
    FirebaseAuthException e,
    LinkingProvider provider, {
    String? Function()? fallbackEmail,
    AuthCredential? fallbackCredential,
  }) {
    String? email = e.email;
    if (email == null || email.trim().isEmpty) {
      try {
        email = fallbackEmail?.call();
      } catch (_) {
        email = null;
      }
    }
    final credential = e.credential ?? fallbackCredential;
    if (email == null || email.trim().isEmpty || credential == null) {
      _logger.w('The email has an account, but there is nothing to link (${provider.name})');
      return null;
    }
    _logger.i('The email has an account: asking for its password to add ${provider.name}');
    return PendingAccountLink(email: email.trim(), credential: credential, provider: provider);
  }

  /// Runs Sign in with Apple once with a fresh nonce: Apple's sheet, then everything Firebase
  /// needs. [signInWithApple] uses it, and so does Delete account (SI-F4, RFC-011 §5.6), which
  /// needs a fresh authorization code to revoke Muse's Apple tokens; that flow can pass no
  /// [scopes].
  ///
  /// Returns null when the user closes the sheet. Throws the plugin's
  /// [SignInWithAppleException]s for anything else. iOS only: callers check the platform first.
  /// Logs nothing: the result holds secrets (primer rule 10).
  Future<AppleAuthorization?> requestAppleAuthorization({
    List<AppleIDAuthorizationScopes> scopes = const [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
  }) async {
    final rawNonce = generateAppleNonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await _appleSignIn.getAppleIDCredential(
        scopes: scopes,
        nonce: sha256OfNonce(rawNonce),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
    return AppleAuthorization(
      rawNonce: rawNonce,
      identityToken: credential.identityToken,
      authorizationCode: credential.authorizationCode,
      givenName: credential.givenName,
      familyName: credential.familyName,
    );
  }

  /// How long the launch check waits for Apple before letting the user in.
  static const appleCredentialCheckTimeout = Duration(seconds: 5);

  /// True when the signed-in user signed in with Apple and their Apple ID no longer lets Muse in:
  /// they removed Muse in their Apple ID settings (`revoked`), or Apple doesn't know the user
  /// (`notFound`). The caller signs them out (RFC-011 §5.3).
  ///
  /// False on Android, for users without Apple, and whenever the check fails or takes longer than
  /// [appleCredentialCheckTimeout]: nobody is signed out because Apple couldn't be reached.
  Future<bool> hasRevokedAppleCredential() async {
    if (!_appleSupported()) return false;
    final user = currentUser;
    if (user == null) return false;

    String? appleUserId;
    for (final info in user.providerData) {
      if (info.providerId == appleProviderId) appleUserId = info.uid;
    }
    if (appleUserId == null || appleUserId.isEmpty) return false;

    try {
      final state =
          await _appleSignIn.getCredentialState(appleUserId).timeout(appleCredentialCheckTimeout);
      final revoked = state == CredentialState.revoked || state == CredentialState.notFound;
      if (revoked) _logger.i('Apple no longer authorises ${user.uid} (${state.name})');
      return revoked;
    } catch (e) {
      _logger.w('Apple credential check skipped (${e.runtimeType})');
      return false;
    }
  }

  /// Apple's first-time name into the onboarding draft, replacing what's there: this is the only
  /// time Apple sends it. A failure doesn't stop the sign-in.
  Future<void> _saveAppleNameToDraft(ProviderName name) async {
    try {
      await _profileDraft().updateFields(
        firstName: name.firstName.isEmpty ? null : name.firstName,
        lastName: name.lastName.isEmpty ? null : name.lastName,
      );
    } catch (e) {
      _logger.w('Could not save the name from Apple to the draft (${e.runtimeType})');
    }
  }

  /// Apple's first-time name onto the Firebase user, so it outlives the draft (D-7).
  Future<void> _saveDisplayName(User user, ProviderName name) async {
    final displayName =
        [name.firstName, name.lastName].where((part) => part.isNotEmpty).join(' ');
    try {
      await user.updateDisplayName(displayName);
    } catch (e) {
      _logger.w('Could not save the name from Apple to the account (${e.runtimeType})');
    }
  }

  String _appleErrorMessage(AuthorizationErrorCode code) {
    switch (code) {
      // `unknown` is what iOS reports when the app lacks the Sign in with Apple capability, or
      // the device has no Apple ID.
      case AuthorizationErrorCode.unknown:
      case AuthorizationErrorCode.notHandled:
        return appleUnavailableMessage;
      default:
        return appleFailedMessage;
    }
  }

  /// Puts a provider's name in the onboarding draft when the draft has no name yet, so
  /// `NameInputScreen` starts from it. A name the user typed is never replaced. A failure here
  /// doesn't fail the sign-in: the user can still type a name.
  Future<void> _prefillDraftName(ProviderName? name) async {
    if (name == null) return;
    try {
      await _profileDraft().prefillName(firstName: name.firstName, lastName: name.lastName);
    } catch (e) {
      _logger.w('Could not prefill the name from the provider (${e.runtimeType})');
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

  /// Firebase's errors for a Google or Apple credential, with that provider's [unavailable] and
  /// [failed] messages. The email and password wording of [_handleFirebaseAuthError] doesn't fit
  /// some of them.
  String _handleProviderFirebaseAuthError(
    FirebaseAuthException e, {
    required String unavailable,
    required String failed,
  }) {
    switch (e.code) {
      // The provider is off in the Firebase project, or its client is wrong (SI-C1).
      case 'operation-not-allowed':
      case 'invalid-credential':
      case 'app-not-authorized':
        return unavailable;
      // Another sign-in method already has this email, and Firebase gave nothing to link (the
      // sign-in methods handle the usual case). A message that doesn't say how it signs in (D-10).
      case 'account-exists-with-different-credential':
        return failed;
      case 'user-disabled':
      case 'too-many-requests':
      case 'network-request-failed':
        return _handleFirebaseAuthError(e);
      default:
        return failed;
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

  /// How long Delete account waits for Google's disconnect before going ahead.
  static const googleDisconnectTimeout = Duration(seconds: 3);

  /// Delete account (RFC-011 §5.6, SI-F4), in this order:
  /// 1. An Apple user: Apple's sheet again with no scopes for a fresh authorization code, then
  ///    `revokeTokenWithAuthorizationCode`. Cancelling or a failure doesn't stop the deletion
  ///    (D-9); the result's `appleRevoked` says so.
  /// 2. A Google user: `GoogleSignIn.disconnect`, best-effort.
  /// 3. `DELETE /users/me`, the step that must succeed. On failure nothing else happens and the
  ///    user stays signed in.
  /// 4. Sign-out through [SignOutService].
  ///
  /// The Firebase user is never deleted here: RFC-009's erasure deletes it after the grace
  /// period, and until then the same Apple or Google account can't open a fresh account.
  /// The screen checks for active dates first (D-14). Logs the uid and error codes only.
  Future<DeleteAccountResult> deleteAccount() async {
    final user = currentUser;
    final accountRepository = _accountRepository;
    if (user == null || accountRepository == null) {
      return const DeleteAccountResult.failure(deleteAccountFailedMessage);
    }
    final providers = {for (final info in user.providerData) info.providerId};
    _logger.i('Deleting account ${user.uid}');

    var appleRevoked = true;
    if (providers.contains(appleProviderId)) {
      appleRevoked = _appleSupported() && await _revokeApple();
    }
    if (providers.contains(GoogleAuthProvider.PROVIDER_ID)) await _disconnectGoogle();

    try {
      await accountRepository().closeAccount();
    } catch (e) {
      _logger.w('Account deletion failed for ${user.uid} (${e.runtimeType})');
      return const DeleteAccountResult.failure(deleteAccountFailedMessage);
    }

    var signedOut = true;
    try {
      await _signOutService.signOut();
    } catch (e) {
      _logger.w('Sign-out after deleting ${user.uid} failed (${e.runtimeType})');
      signedOut = false;
    }
    return DeleteAccountResult.deleted(appleRevoked: appleRevoked, signedOut: signedOut);
  }

  /// Revokes Muse's Apple tokens with a fresh authorization code. False when the user closed
  /// Apple's sheet or anything failed. Logs codes only: never the authorization code.
  Future<bool> _revokeApple() async {
    try {
      final apple = await requestAppleAuthorization(scopes: const []);
      if (apple == null) {
        _logger.i('Apple revocation skipped: the user closed the sheet');
        return false;
      }
      await _firebaseAuth.revokeTokenWithAuthorizationCode(apple.authorizationCode);
      _logger.i('Apple tokens revoked');
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      _logger.w('Apple revocation failed (${e.code.name})');
    } on FirebaseAuthException catch (e) {
      _logger.w('Apple revocation failed (${e.code})');
    } catch (e) {
      _logger.w('Apple revocation failed (${e.runtimeType})');
    }
    return false;
  }

  /// Removes Muse's access to the Google account, best-effort.
  Future<void> _disconnectGoogle() async {
    try {
      await _googleSignIn.disconnect().timeout(googleDisconnectTimeout);
    } catch (e) {
      _logger.w('Google disconnect did not finish, deleting anyway (${e.runtimeType})');
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
