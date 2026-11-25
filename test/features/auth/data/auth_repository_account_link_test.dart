import 'package:eros_app/core/auth/apple_sign_in.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/auth/sign_out_service.dart';
import 'package:eros_app/features/auth/data/repositories/auth_repository.dart';
import 'package:eros_app/features/auth/domain/models/account_link.dart';
import 'package:eros_app/features/profile/data/services/profile_creation_service.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// RFC-011 §5.4: one account per email. Google or Apple meeting an email that already has an
// account becomes a password sign-in followed by `linkWithCredential`.

const _email = 'ada@example.com';
const _googleIdToken = 'google-id-token-secret';
const _appleIdentityToken = 'apple-identity-token-secret';
const _appleCode = 'apple-authorization-code-secret';
const _pendingToken = 'pending-credential-secret';
const _password = 'correct horse battery staple';

class _FakeUser implements User {
  /// Thrown by [linkWithCredential] when set.
  FirebaseAuthException? linkError;
  final linked = <AuthCredential>[];

  @override
  String get uid => 'uid-123';

  @override
  String? get displayName => null;

  @override
  List<UserInfo> get providerData => const [];

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    linked.add(credential);
    if (linkError != null) throw linkError!;
    return _FakeUserCredential(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserCredential implements UserCredential {
  _FakeUserCredential(this.user);

  @override
  final User? user;

  @override
  AdditionalUserInfo? get additionalUserInfo => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  final user = _FakeUser();

  /// What Firebase throws for a Google or Apple credential.
  FirebaseAuthException? providerError;

  /// What Firebase throws for an email sign-in or sign-up.
  FirebaseAuthException? emailError;

  final passwordSignIns = <String>[];

  @override
  User? currentUser;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    if (providerError != null) throw providerError!;
    currentUser = user;
    return _FakeUserCredential(user);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (emailError != null) throw emailError!;
    passwordSignIns.add(email);
    currentUser = user;
    return _FakeUserCredential(user);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (emailError != null) throw emailError!;
    currentUser = user;
    return _FakeUserCredential(user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccount implements GoogleSignInAccount {
  @override
  String get email => _email;

  @override
  String? get displayName => null;

  @override
  GoogleSignInAuthentication get authentication =>
      const GoogleSignInAuthentication(idToken: _googleIdToken);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoogleSignIn implements GoogleSignIn {
  @override
  Future<GoogleSignInAccount> authenticate({List<String> scopeHint = const <String>[]}) async =>
      _FakeAccount();

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAppleClient implements AppleSignInClient {
  @override
  Future<AuthorizationCredentialAppleID> getAppleIDCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    required String nonce,
  }) async =>
      const AuthorizationCredentialAppleID(
        userIdentifier: '001234.apple-user-id',
        givenName: null,
        familyName: null,
        authorizationCode: _appleCode,
        email: null,
        identityToken: _appleIdentityToken,
        state: null,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Throws if called: signing out would mean a failed link took the user out of the app.
class _Unused implements AuthService, SignOutService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LinesOutput extends LogOutput {
  final List<String> lines = [];

  @override
  void output(OutputEvent event) => lines.addAll(event.lines);
}

class _EverythingFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => true;
}

FirebaseAuthException _accountExists({String? email = _email, AuthCredential? credential}) =>
    FirebaseAuthException(
      code: 'account-exists-with-different-credential',
      email: email,
      credential: credential,
      message: 'An account already exists with the same email address: $_email',
    );

void main() {
  late _FakeFirebaseAuth firebaseAuth;
  late _LinesOutput logs;
  late bool onIOS;
  late AuthRepository repository;
  final pending = GoogleAuthProvider.credential(idToken: _pendingToken);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final draft = ProfileCreationNotifier(ProfileCreationService(prefs));
    firebaseAuth = _FakeFirebaseAuth();
    logs = _LinesOutput();
    onIOS = true;
    repository = AuthRepository(
      firebaseAuth,
      _Unused(),
      _Unused(),
      googleSignIn: _FakeGoogleSignIn(),
      appleSignIn: _FakeAppleClient(),
      appleSupported: () => onIOS,
      profileDraft: () => draft,
      logger: Logger(filter: _EverythingFilter(), printer: SimplePrinter(), output: logs),
    );
  });

  group('an email that already has an account', () {
    for (final (provider, signIn) in [
      (LinkingProvider.google, () => repository.signInWithGoogle()),
      (LinkingProvider.apple, () => repository.signInWithApple()),
    ]) {
      test('from ${provider.label}: a link result with the email and the pending credential',
          () async {
        firebaseAuth.providerError = _accountExists(credential: pending);

        final result = (await signIn())!;

        expect(result.isSuccess, isFalse);
        expect(result.needsLink, isTrue);
        expect(result.errorMessage, isNull);
        expect(result.pendingLink!.email, _email);
        expect(result.pendingLink!.credential, same(pending));
        expect(result.pendingLink!.provider, provider);
        expect(firebaseAuth.currentUser, isNull);
      });
    }

    test("without Firebase's credential, Google's own credential is the one to link", () async {
      firebaseAuth.providerError = _accountExists();

      final link = (await repository.signInWithGoogle())!.pendingLink!;

      final credential = link.credential as OAuthCredential;
      expect(credential.providerId, 'google.com');
      expect(credential.idToken, _googleIdToken);
    });

    test("without Firebase's email, Google's account email is used", () async {
      firebaseAuth.providerError = _accountExists(email: null, credential: pending);

      final link = (await repository.signInWithGoogle())!.pendingLink!;

      expect(link.email, _email);
    });

    test("without Firebase's credential, Apple's own credential is the one to link", () async {
      firebaseAuth.providerError = _accountExists();

      final link = (await repository.signInWithApple())!.pendingLink!;

      final credential = link.credential as OAuthCredential;
      expect(credential.providerId, 'apple.com');
      expect(credential.idToken, _appleIdentityToken);
    });

    test('from Apple with no email to show: the generic message, naming no other method',
        () async {
      firebaseAuth.providerError = _accountExists(email: null, credential: pending);

      final result = (await repository.signInWithApple())!;

      expect(result.needsLink, isFalse);
      expect(result.errorMessage, appleFailedMessage);
      expect(result.errorMessage, isNot(contains('Google')));
    });

    test("the pending link's description shows neither the email nor the credential", () async {
      firebaseAuth.providerError = _accountExists(credential: pending);

      final link = (await repository.signInWithGoogle())!.pendingLink!;

      expect('$link', isNot(contains(_email)));
      expect('$link', isNot(contains(_pendingToken)));
    });
  });

  group('after the password sign-in', () {
    Future<PendingAccountLink> passwordSignIn(LinkingProvider provider) async {
      firebaseAuth.providerError = _accountExists(credential: pending);
      final result = provider == LinkingProvider.google
          ? await repository.signInWithGoogle()
          : await repository.signInWithApple();
      final link = result!.pendingLink!;
      final signedIn = await repository.signInWithEmail(email: link.email, password: _password);
      expect(signedIn.isSuccess, isTrue);
      return link;
    }

    test('links the pending credential to the signed-in account', () async {
      final link = await passwordSignIn(LinkingProvider.apple);

      final result = await repository.linkPendingCredential(link);

      expect(result.isSuccess, isTrue);
      expect(result.user!.uid, 'uid-123');
      expect(firebaseAuth.passwordSignIns, [_email]);
      expect(firebaseAuth.user.linked, [same(pending)]);
    });

    test('a failed link leaves the user signed in, and says so', () async {
      final link = await passwordSignIn(LinkingProvider.apple);
      firebaseAuth.user.linkError = FirebaseAuthException(code: 'credential-already-in-use');

      final result = await repository.linkPendingCredential(link);

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, "Signed in. We couldn't add Apple this time.");
      // Still signed in: SignOutService (a throwing fake here) was never called.
      expect(repository.currentUser, same(firebaseAuth.user));
    });

    test('a failed Google link names Google', () async {
      final link = await passwordSignIn(LinkingProvider.google);
      firebaseAuth.user.linkError = FirebaseAuthException(code: 'provider-already-linked');

      final result = await repository.linkPendingCredential(link);

      expect(result.errorMessage, "Signed in. We couldn't add Google this time.");
      expect(repository.currentUser, isNotNull);
    });

    test('with nobody signed in, nothing is linked', () async {
      final link = PendingAccountLink(
        email: _email,
        credential: pending,
        provider: LinkingProvider.google,
      );

      final result = await repository.linkPendingCredential(link);

      expect(result.isSuccess, isFalse);
      expect(firebaseAuth.user.linked, isEmpty);
    });
  });

  group('email messages that point to Google and Apple without naming the account', () {
    test('sign-up with a registered email on iOS', () async {
      firebaseAuth.emailError = FirebaseAuthException(code: 'email-already-in-use');

      final result = await repository.signUpWithEmail(email: _email, password: _password);

      expect(result.errorMessage,
          'This email is already registered. Sign in, or try Continue with Google or Apple.');
    });

    test('sign-up with a registered email on Android leaves Apple out (D-2)', () async {
      onIOS = false;
      firebaseAuth.emailError = FirebaseAuthException(code: 'email-already-in-use');

      final result = await repository.signUpWithEmail(email: _email, password: _password);

      expect(result.errorMessage,
          'This email is already registered. Sign in, or try Continue with Google.');
    });

    for (final code in ['wrong-password', 'invalid-credential']) {
      test('$code on iOS', () async {
        firebaseAuth.emailError = FirebaseAuthException(code: code);

        final result = await repository.signInWithEmail(email: _email, password: _password);

        expect(result.errorMessage,
            'Incorrect email or password. If you signed up with Google or Apple, use that button '
            'instead.');
      });

      test('$code on Android leaves Apple out', () async {
        onIOS = false;
        firebaseAuth.emailError = FirebaseAuthException(code: code);

        final result = await repository.signInWithEmail(email: _email, password: _password);

        expect(result.errorMessage,
            'Incorrect email or password. If you signed up with Google, use that button instead.');
      });
    }
  });

  test('never logs the email, a token or a credential', () async {
    firebaseAuth.providerError = _accountExists(credential: pending);
    final link = (await repository.signInWithGoogle())!.pendingLink!;
    await repository.signInWithApple();
    await repository.signInWithEmail(email: _email, password: _password);
    firebaseAuth.user.linkError = FirebaseAuthException(code: 'credential-already-in-use');
    await repository.linkPendingCredential(link);
    firebaseAuth.user.linkError = null;
    await repository.linkPendingCredential(link);

    final logged = logs.lines.join('\n');
    expect(logged, contains('uid-123'));
    for (final secret in [
      _email,
      _googleIdToken,
      _appleIdentityToken,
      _appleCode,
      _pendingToken,
      _password,
    ]) {
      expect(logged, isNot(contains(secret)));
    }
  });
}
