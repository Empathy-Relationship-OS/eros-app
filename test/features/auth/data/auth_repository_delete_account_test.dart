import 'package:eros_app/core/auth/apple_sign_in.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/auth/sign_out_service.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/auth/data/repositories/auth_repository.dart';
import 'package:eros_app/features/auth/domain/models/delete_account_result.dart';
import 'package:eros_app/features/legal/data/account_repository.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

const _authorizationCode = 'apple-authorization-code-secret';
const _identityToken = 'apple-identity-token-secret';

/// Every step, in order, across the fakes below (RFC-011 §5.6).
final _events = <String>[];

class _FakeUserInfo implements UserInfo {
  _FakeUserInfo(this.providerId);

  @override
  final String providerId;

  @override
  String? get uid => 'provider-uid';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  _FakeUser(List<String> providers)
      : providerData = [for (final id in providers) _FakeUserInfo(id)];

  @override
  final List<UserInfo> providerData;

  @override
  String get uid => 'uid-123';

  /// SI-F4 never deletes the Firebase user: RFC-009's erasure does, after the grace period.
  @override
  Future<void> delete() async => _events.add('firebase user deleted');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  User? currentUser;

  Object? revokeError;
  final revokedCodes = <String>[];

  @override
  Future<void> revokeTokenWithAuthorizationCode(String authorizationCode) async {
    _events.add('revoke');
    revokedCodes.add(authorizationCode);
    if (revokeError != null) throw revokeError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAppleClient implements AppleSignInClient {
  Future<AuthorizationCredentialAppleID> Function() onCredential = () async =>
      const AuthorizationCredentialAppleID(
        userIdentifier: 'apple-user',
        givenName: null,
        familyName: null,
        authorizationCode: _authorizationCode,
        email: null,
        identityToken: _identityToken,
        state: null,
      );

  final scopes = <List<AppleIDAuthorizationScopes>>[];

  @override
  Future<AuthorizationCredentialAppleID> getAppleIDCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    required String nonce,
  }) {
    _events.add('apple sheet');
    this.scopes.add(scopes);
    return onCredential();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoogleSignIn implements GoogleSignIn {
  Object? disconnectError;

  @override
  Future<void> disconnect() async {
    _events.add('google disconnect');
    if (disconnectError != null) throw disconnectError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccountRepository implements AccountRepository {
  Object? error;

  @override
  Future<void> closeAccount() async {
    _events.add('DELETE /users/me');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSignOutService implements SignOutService {
  Object? error;

  @override
  Future<void> signOut() async {
    _events.add('sign out');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Unused implements AuthService, ProfileCreationNotifier {
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
  late _FakeGoogleSignIn google;
  late _FakeAccountRepository account;
  late _FakeSignOutService signOut;
  late _LinesOutput logs;
  late bool onIOS;
  late AuthRepository repository;

  setUp(() {
    _events.clear();
    firebaseAuth = _FakeFirebaseAuth();
    apple = _FakeAppleClient();
    google = _FakeGoogleSignIn();
    account = _FakeAccountRepository();
    signOut = _FakeSignOutService();
    logs = _LinesOutput();
    onIOS = true;
    repository = AuthRepository(
      firebaseAuth,
      _Unused(),
      signOut,
      googleSignIn: google,
      appleSignIn: apple,
      appleSupported: () => onIOS,
      profileDraft: () => _Unused(),
      accountRepository: () => account,
      logger: Logger(
        filter: _EverythingFilter(),
        printer: SimplePrinter(colors: false),
        output: logs,
      ),
    );
  });

  void signedInWith(List<String> providers) => firebaseAuth.currentUser = _FakeUser(providers);

  group('an Apple user', () {
    setUp(() => signedInWith(['apple.com']));

    test('revokes with a fresh code, then deletes, then signs out, in that order', () async {
      final result = await repository.deleteAccount();

      expect(_events, ['apple sheet', 'revoke', 'DELETE /users/me', 'sign out']);
      expect(apple.scopes.single, isEmpty, reason: 'revoking asks Apple for no scopes');
      expect(firebaseAuth.revokedCodes, [_authorizationCode]);
      expect(result.isSuccess, isTrue);
      expect(result.appleRevoked, isTrue);
      expect(result.signedOut, isTrue);
    });

    test('closing Apple\'s sheet still deletes, and flags the Apple step', () async {
      apple.onCredential = () async => throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'cancelled',
          );

      final result = await repository.deleteAccount();

      expect(_events, ['apple sheet', 'DELETE /users/me', 'sign out']);
      expect(result.isSuccess, isTrue);
      expect(result.appleRevoked, isFalse);
    });

    test('a failing Apple sheet still deletes, and flags the Apple step', () async {
      apple.onCredential = () async => throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.failed,
            message: 'failed',
          );

      final result = await repository.deleteAccount();

      expect(_events, ['apple sheet', 'DELETE /users/me', 'sign out']);
      expect(result.isSuccess, isTrue);
      expect(result.appleRevoked, isFalse);
    });

    test('a failing revocation still deletes, and flags the Apple step', () async {
      firebaseAuth.revokeError = FirebaseAuthException(code: 'invalid-credential');

      final result = await repository.deleteAccount();

      expect(_events, ['apple sheet', 'revoke', 'DELETE /users/me', 'sign out']);
      expect(result.isSuccess, isTrue);
      expect(result.appleRevoked, isFalse);
    });

    test('on Android shows no Apple sheet, deletes, and flags the Apple step', () async {
      onIOS = false;

      final result = await repository.deleteAccount();

      expect(_events, ['DELETE /users/me', 'sign out']);
      expect(result.isSuccess, isTrue);
      expect(result.appleRevoked, isFalse);
    });

    test('never logs the authorization code or the identity token', () async {
      await repository.deleteAccount();

      final logged = logs.lines.join('\n');
      expect(logged, isNot(contains(_authorizationCode)));
      expect(logged, isNot(contains(_identityToken)));
      expect(logged, contains('uid-123'));
    });
  });

  group('a Google user', () {
    setUp(() => signedInWith(['google.com']));

    test('disconnects Google, then deletes, then signs out', () async {
      final result = await repository.deleteAccount();

      expect(_events, ['google disconnect', 'DELETE /users/me', 'sign out']);
      expect(result.isSuccess, isTrue);
      expect(result.appleRevoked, isTrue);
    });

    test('a failing disconnect still deletes', () async {
      google.disconnectError = StateError('not initialised');

      final result = await repository.deleteAccount();

      expect(_events, ['google disconnect', 'DELETE /users/me', 'sign out']);
      expect(result.isSuccess, isTrue);
    });
  });

  test('a user with Apple and Google takes both provider steps first', () async {
    signedInWith(['apple.com', 'google.com', 'password']);

    await repository.deleteAccount();

    expect(_events, [
      'apple sheet',
      'revoke',
      'google disconnect',
      'DELETE /users/me',
      'sign out',
    ]);
  });

  test('an email-only user skips both provider steps', () async {
    signedInWith(['password']);

    final result = await repository.deleteAccount();

    expect(_events, ['DELETE /users/me', 'sign out']);
    expect(result.isSuccess, isTrue);
    expect(result.appleRevoked, isTrue);
  });

  test('a failed DELETE /users/me stops before sign-out and keeps the user signed in', () async {
    signedInWith(['password']);
    account.error = const ServerException('down');

    final result = await repository.deleteAccount();

    expect(_events, ['DELETE /users/me']);
    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, deleteAccountFailedMessage);
    expect(firebaseAuth.currentUser, isNotNull);
  });

  test('a failed sign-out after deleting still counts as deleted', () async {
    signedInWith(['password']);
    signOut.error = StateError('Firebase sign-out failed');

    final result = await repository.deleteAccount();

    expect(_events, ['DELETE /users/me', 'sign out']);
    expect(result.isSuccess, isTrue);
    expect(result.signedOut, isFalse);
  });

  test('never deletes the Firebase user, whatever the providers', () async {
    for (final providers in [
      ['apple.com'],
      ['google.com'],
      ['password'],
    ]) {
      signedInWith(providers);
      await repository.deleteAccount();
    }

    expect(_events, isNot(contains('firebase user deleted')));
  });

  test('nobody signed in: fails without calling anything', () async {
    final result = await repository.deleteAccount();

    expect(_events, isEmpty);
    expect(result.isSuccess, isFalse);
  });
}
