import 'package:eros_app/core/auth/apple_sign_in.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/auth/sign_out_service.dart';
import 'package:eros_app/features/auth/data/repositories/auth_repository.dart';
import 'package:eros_app/features/profile/data/services/profile_creation_service.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

const _identityToken = 'apple-identity-token-secret';
const _authorizationCode = 'apple-authorization-code-secret';
const _appleUserId = '001234.apple-user-id';
const _email = 'abc123@privaterelay.appleid.com';

/// Every step that awaits, in order, across the fakes below.
final _events = <String>[];

class _FakeUserInfo implements UserInfo {
  _FakeUserInfo(this.providerId, this.uid);

  @override
  final String providerId;

  @override
  final String? uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  _FakeUser({this.displayName, this.providerData = const []});

  @override
  final String? displayName;

  @override
  final List<UserInfo> providerData;

  final displayNames = <String?>[];

  @override
  String get uid => 'uid-123';

  @override
  Future<void> updateDisplayName(String? displayName) async {
    _events.add('displayName');
    displayNames.add(displayName);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserCredential implements UserCredential {
  _FakeUserCredential(this.user);

  @override
  final User? user;

  @override
  AdditionalUserInfo? get additionalUserInfo =>
      AdditionalUserInfo(isNewUser: true, providerId: appleProviderId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  AuthCredential? credential;
  FirebaseAuthException? error;
  late _FakeUser user;

  @override
  User? currentUser;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    _events.add('firebase');
    this.credential = credential;
    if (error != null) throw error!;
    return _FakeUserCredential(user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAppleClient implements AppleSignInClient {
  /// What the next sheet returns, or throws.
  Future<AuthorizationCredentialAppleID> Function() onCredential = () async => _credential();
  Future<CredentialState> Function() onState = () async => CredentialState.authorized;

  final nonces = <String>[];
  final scopes = <List<AppleIDAuthorizationScopes>>[];
  final stateChecks = <String>[];

  @override
  Future<AuthorizationCredentialAppleID> getAppleIDCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    required String nonce,
  }) {
    _events.add('apple');
    nonces.add(nonce);
    this.scopes.add(scopes);
    return onCredential();
  }

  @override
  Future<CredentialState> getCredentialState(String appleUserId) {
    stateChecks.add(appleUserId);
    return onState();
  }
}

/// Apple's answer: with a name on the first authorisation only.
AuthorizationCredentialAppleID _credential({
  String? givenName,
  String? familyName,
  String? identityToken = _identityToken,
}) =>
    AuthorizationCredentialAppleID(
      userIdentifier: _appleUserId,
      givenName: givenName,
      familyName: familyName,
      authorizationCode: _authorizationCode,
      email: _email,
      identityToken: identityToken,
      state: null,
    );

/// Records when the draft is saved, so the order of saves can be checked.
class _RecordingDraft extends ProfileCreationNotifier {
  _RecordingDraft(super.service);

  @override
  Future<void> updateFields({
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    int? heightCm,
    DateTime? dateOfBirth,
    String? city,
    double? coordinatesLatitude,
    double? coordinatesLongitude,
  }) async {
    _events.add('draft');
    await super.updateFields(firstName: firstName, lastName: lastName);
  }
}

class _Unused implements AuthService, SignOutService, GoogleSignIn {
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

void main() {
  late _FakeFirebaseAuth firebaseAuth;
  late _FakeAppleClient apple;
  late ProfileCreationService draftStore;
  late _RecordingDraft draft;
  late _LinesOutput logs;
  late bool onIOS;
  late AuthRepository repository;

  setUp(() async {
    _events.clear();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    draftStore = ProfileCreationService(prefs);
    draft = _RecordingDraft(draftStore);
    firebaseAuth = _FakeFirebaseAuth()..user = _FakeUser();
    apple = _FakeAppleClient();
    logs = _LinesOutput();
    onIOS = true;
    repository = AuthRepository(
      firebaseAuth,
      _Unused(),
      _Unused(),
      googleSignIn: _Unused(),
      appleSignIn: apple,
      appleSupported: () => onIOS,
      profileDraft: () => draft,
      logger: Logger(filter: _EverythingFilter(), printer: SimplePrinter(), output: logs),
    );
  });

  ({String? first, String? last}) names() {
    final saved = draftStore.loadDraft();
    return (first: saved?.firstName, last: saved?.lastName);
  }

  group('signInWithApple', () {
    test('sends Apple the SHA-256 of the raw nonce it gives Firebase', () async {
      final result = await repository.signInWithApple();

      expect(result!.isSuccess, isTrue);
      expect(result.user!.uid, 'uid-123');
      final credential = firebaseAuth.credential as OAuthCredential;
      expect(credential.providerId, 'apple.com');
      expect(credential.idToken, _identityToken);
      expect(credential.accessToken, _authorizationCode);
      final rawNonce = credential.rawNonce!;
      expect(apple.nonces.single, sha256OfNonce(rawNonce));
      expect(apple.nonces.single, isNot(rawNonce));
      // 64 hex characters: a SHA-256.
      expect(apple.nonces.single, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('asks Apple for the email and the full name only', () async {
      await repository.signInWithApple();

      expect(apple.scopes.single, [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ]);
    });

    test('uses a new nonce every time', () async {
      await repository.signInWithApple();
      final first = (firebaseAuth.credential as OAuthCredential).rawNonce;
      await repository.signInWithApple();
      final second = (firebaseAuth.credential as OAuthCredential).rawNonce;

      expect(first, isNot(second));
      expect(apple.nonces[0], isNot(apple.nonces[1]));
    });

    test('returns null when the user closes the Apple sheet, and never calls Firebase', () async {
      apple.onCredential = () async => throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'The user canceled the authorization attempt.',
          );

      expect(await repository.signInWithApple(), isNull);
      expect(firebaseAuth.credential, isNull);
    });

    test("an unknown Apple error (no capability or no Apple ID) says Apple isn't available",
        () async {
      apple.onCredential = () async => throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.unknown,
            message: 'error 1000',
          );

      final result = await repository.signInWithApple();

      expect(result!.isSuccess, isFalse);
      expect(result.errorMessage, appleUnavailableMessage);
    });

    test('a failed Apple authorisation says it failed', () async {
      apple.onCredential = () async => throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.failed,
            message: 'failed',
          );

      expect((await repository.signInWithApple())!.errorMessage, appleFailedMessage);
    });

    test("a device without Sign in with Apple says Apple isn't available", () async {
      apple.onCredential =
          () async => throw const SignInWithAppleNotSupportedException(message: 'iOS 12');

      expect((await repository.signInWithApple())!.errorMessage, appleUnavailableMessage);
    });

    test('never calls Apple off iOS (D-2)', () async {
      onIOS = false;

      final result = await repository.signInWithApple();

      expect(result!.errorMessage, appleUnavailableMessage);
      expect(apple.nonces, isEmpty);
      expect(firebaseAuth.credential, isNull);
    });

    test("no identity token from Apple says Apple isn't available", () async {
      apple.onCredential = () async => _credential(identityToken: null);

      expect((await repository.signInWithApple())!.errorMessage, appleUnavailableMessage);
      expect(firebaseAuth.credential, isNull);
    });

    test('a Firebase network error maps to the network message', () async {
      firebaseAuth.error = FirebaseAuthException(code: 'network-request-failed');

      final result = await repository.signInWithApple();

      expect(result!.errorMessage, 'Network error. Please check your connection and try again.');
    });

    test("Apple turned off in Firebase says Apple isn't available, not email/password", () async {
      firebaseAuth.error = FirebaseAuthException(code: 'operation-not-allowed');

      expect((await repository.signInWithApple())!.errorMessage, appleUnavailableMessage);
    });

    test('an email that signs in another way gets a message that names no provider', () async {
      firebaseAuth.error = FirebaseAuthException(code: 'account-exists-with-different-credential');

      final message = (await repository.signInWithApple())!.errorMessage!;

      expect(message, appleFailedMessage);
      expect(message, isNot(contains('Google')));
      expect(message.toLowerCase(), isNot(contains('password')));
    });
  });

  group("Apple's name (sent on the first authorisation only)", () {
    test('is saved to the draft before Firebase, and to the account before anything else',
        () async {
      apple.onCredential = () async => _credential(givenName: 'Ada', familyName: 'Lovelace');

      final result = await repository.signInWithApple();

      expect(result!.isSuccess, isTrue);
      expect(_events, ['apple', 'draft', 'firebase', 'displayName']);
      expect(names(), (first: 'Ada', last: 'Lovelace'));
      expect(firebaseAuth.user.displayNames, ['Ada Lovelace']);
    });

    test('replaces a name already in the draft', () async {
      await draft.prefillName(firstName: 'Old', lastName: 'Name');
      _events.clear();
      apple.onCredential = () async => _credential(givenName: 'Ada', familyName: 'Lovelace');

      await repository.signInWithApple();

      expect(names(), (first: 'Ada', last: 'Lovelace'));
    });

    test('a given name alone is saved on its own', () async {
      apple.onCredential = () async => _credential(givenName: 'Ada');

      await repository.signInWithApple();

      expect(names(), (first: 'Ada', last: null));
      expect(firebaseAuth.user.displayNames, ['Ada']);
    });

    test('stays in the draft when Firebase then fails', () async {
      apple.onCredential = () async => _credential(givenName: 'Ada', familyName: 'Lovelace');
      firebaseAuth.error = FirebaseAuthException(code: 'network-request-failed');

      final result = await repository.signInWithApple();

      expect(result!.isSuccess, isFalse);
      expect(names(), (first: 'Ada', last: 'Lovelace'));
    });

    test('a later sign-in without a name keeps the draft and leaves the account alone', () async {
      await draft.prefillName(firstName: 'Typed', lastName: 'Name');
      firebaseAuth.user = _FakeUser(displayName: 'Ada Lovelace');

      final result = await repository.signInWithApple();

      expect(result!.isSuccess, isTrue);
      expect(names(), (first: 'Typed', last: 'Name'));
      expect(firebaseAuth.user.displayNames, isEmpty);
    });

    test("a later sign-in into an empty draft falls back to the account's name", () async {
      firebaseAuth.user = _FakeUser(displayName: 'Ada Lovelace');

      await repository.signInWithApple();

      expect(names(), (first: 'Ada', last: 'Lovelace'));
      expect(firebaseAuth.user.displayNames, isEmpty);
    });
  });

  test('never logs the token, the code, the nonce, the email or the name', () async {
    apple.onCredential = () async => _credential(givenName: 'Ada', familyName: 'Lovelace');
    await repository.signInWithApple();
    final rawNonce = (firebaseAuth.credential as OAuthCredential).rawNonce!;
    firebaseAuth.error = FirebaseAuthException(code: 'invalid-credential', message: _email);
    await repository.signInWithApple();

    final logged = logs.lines.join('\n');
    expect(logs.lines, isNotEmpty);
    for (final secret in [
      _identityToken,
      _authorizationCode,
      rawNonce,
      apple.nonces.first,
      _email,
      'Ada',
      'Lovelace',
      _appleUserId,
    ]) {
      expect(logged, isNot(contains(secret)));
    }
  });

  group('requestAppleAuthorization (also for Delete account, SI-F4)', () {
    test('returns what Firebase needs and the name, and hides it all from toString', () async {
      apple.onCredential = () async => _credential(givenName: 'Ada', familyName: 'Lovelace');

      final authorization = (await repository.requestAppleAuthorization())!;

      expect(authorization.authorizationCode, _authorizationCode);
      expect(authorization.identityToken, _identityToken);
      expect(sha256OfNonce(authorization.rawNonce), apple.nonces.single);
      expect(authorization.givenName, 'Ada');
      expect(authorization.familyName, 'Lovelace');
      expect(authorization.toString(), isNot(contains(_authorizationCode)));
      expect(firebaseAuth.credential, isNull);
    });

    test('asks for no scopes when given none', () async {
      await repository.requestAppleAuthorization(scopes: const []);

      expect(apple.scopes.single, isEmpty);
    });

    test('returns null on cancel and throws other Apple errors', () async {
      apple.onCredential = () async => throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'canceled',
          );
      expect(await repository.requestAppleAuthorization(), isNull);

      apple.onCredential = () async => throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.failed,
            message: 'failed',
          );
      expect(
        repository.requestAppleAuthorization(),
        throwsA(isA<SignInWithAppleAuthorizationException>()),
      );
    });
  });

  group('hasRevokedAppleCredential', () {
    setUp(() {
      firebaseAuth.currentUser = _FakeUser(providerData: [
        _FakeUserInfo('password', 'uid-123'),
        _FakeUserInfo(appleProviderId, _appleUserId),
      ]);
    });

    test('is true when the user removed Muse from their Apple ID', () async {
      apple.onState = () async => CredentialState.revoked;

      expect(await repository.hasRevokedAppleCredential(), isTrue);
      expect(apple.stateChecks, [_appleUserId]);
    });

    test("is true when Apple doesn't know the user", () async {
      apple.onState = () async => CredentialState.notFound;

      expect(await repository.hasRevokedAppleCredential(), isTrue);
    });

    test('is false while the Apple ID still authorises Muse', () async {
      apple.onState = () async => CredentialState.authorized;

      expect(await repository.hasRevokedAppleCredential(), isFalse);
    });

    test("is false when the check fails, so Apple being unreachable signs nobody out", () async {
      apple.onState = () async => throw const SignInWithAppleCredentialsException(message: 'x');

      expect(await repository.hasRevokedAppleCredential(), isFalse);
    });

    test("doesn't ask Apple about a user without Apple", () async {
      firebaseAuth.currentUser = _FakeUser(providerData: [_FakeUserInfo('google.com', 'g-1')]);

      expect(await repository.hasRevokedAppleCredential(), isFalse);
      expect(apple.stateChecks, isEmpty);
    });

    test("doesn't ask Apple off iOS (D-2)", () async {
      onIOS = false;

      expect(await repository.hasRevokedAppleCredential(), isFalse);
      expect(apple.stateChecks, isEmpty);
    });

    test('is false when nobody is signed in', () async {
      firebaseAuth.currentUser = null;

      expect(await repository.hasRevokedAppleCredential(), isFalse);
    });
  });

  test('generateAppleNonce gives 32 random bytes, url-safe', () {
    final nonce = generateAppleNonce();

    expect(nonce, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    expect(generateAppleNonce(), isNot(nonce));
  });
}
