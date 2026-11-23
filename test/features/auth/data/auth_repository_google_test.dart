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

const _idToken = 'google-id-token-secret';

class _FakeUser implements User {
  _FakeUser({this.displayName});

  @override
  final String? displayName;

  @override
  String get uid => 'uid-123';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserCredential implements UserCredential {
  _FakeUserCredential(this.user, this.additionalUserInfo);

  @override
  final User? user;

  @override
  final AdditionalUserInfo? additionalUserInfo;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  AuthCredential? credential;
  FirebaseAuthException? error;
  UserCredential? result;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    this.credential = credential;
    if (error != null) throw error!;
    return result!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccount implements GoogleSignInAccount {
  _FakeAccount({this.idToken = _idToken, this.displayName});

  final String? idToken;

  @override
  final String? displayName;

  @override
  GoogleSignInAuthentication get authentication => GoogleSignInAuthentication(idToken: idToken);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoogleSignIn implements GoogleSignIn {
  Future<GoogleSignInAccount> Function() onAuthenticate = () async => _FakeAccount();
  int signOuts = 0;

  @override
  Future<GoogleSignInAccount> authenticate({List<String> scopeHint = const <String>[]}) =>
      onAuthenticate();

  @override
  Future<void> signOut() async => signOuts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Unused implements AuthService, SignOutService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LinesOutput extends LogOutput {
  final List<String> lines = [];

  @override
  void output(OutputEvent event) => lines.addAll(event.lines);
}

/// Logs everything, so the checks below see every line the repository writes.
class _EverythingFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => true;
}

void main() {
  late _FakeFirebaseAuth firebaseAuth;
  late _FakeGoogleSignIn googleSignIn;
  late ProfileCreationService draftStore;
  late ProfileCreationNotifier draft;
  late _LinesOutput logs;
  late AuthRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    draftStore = ProfileCreationService(prefs);
    draft = ProfileCreationNotifier(draftStore);
    firebaseAuth = _FakeFirebaseAuth()
      ..result = _FakeUserCredential(
        _FakeUser(displayName: 'Ada Lovelace'),
        AdditionalUserInfo(isNewUser: true, providerId: 'google.com'),
      );
    googleSignIn = _FakeGoogleSignIn();
    logs = _LinesOutput();
    repository = AuthRepository(
      firebaseAuth,
      _Unused(),
      _Unused(),
      googleSignIn: googleSignIn,
      profileDraft: () => draft,
      logger: Logger(filter: _EverythingFilter(), printer: SimplePrinter(), output: logs),
    );
  });

  /// The name in the saved draft, which `NameInputScreen` starts from.
  ProviderNameFields names() {
    final saved = draftStore.loadDraft();
    return (first: saved?.firstName, last: saved?.lastName);
  }

  group('signInWithGoogle', () {
    test('exchanges the Google ID token with Firebase and returns the user', () async {
      final result = await repository.signInWithGoogle();

      expect(result!.isSuccess, isTrue);
      expect(result.user!.uid, 'uid-123');
      final credential = firebaseAuth.credential as OAuthCredential;
      expect(credential.providerId, 'google.com');
      expect(credential.idToken, _idToken);
      // No access token: we use no Google APIs (RFC-011 D-6).
      expect(credential.accessToken, isNull);
    });

    test('returns null when the user closes the Google sheet, and never calls Firebase', () async {
      googleSignIn.onAuthenticate = () async =>
          throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);

      expect(await repository.signInWithGoogle(), isNull);
      expect(firebaseAuth.credential, isNull);
    });

    test('a Google configuration error says Google is unavailable', () async {
      googleSignIn.onAuthenticate = () async => throw const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
            description: 'serverClientId missing',
          );

      final result = await repository.signInWithGoogle();

      expect(result!.isSuccess, isFalse);
      expect(result.errorMessage, googleUnavailableMessage);
    });

    test('an error thrown before Google sign-in is initialised says Google is unavailable',
        () async {
      googleSignIn.onAuthenticate = () async => throw StateError('not initialized');

      final result = await repository.signInWithGoogle();

      expect(result!.errorMessage, googleUnavailableMessage);
    });

    test('no ID token from Google says Google is unavailable', () async {
      googleSignIn.onAuthenticate = () async => _FakeAccount(idToken: null);

      final result = await repository.signInWithGoogle();

      expect(result!.errorMessage, googleUnavailableMessage);
      expect(firebaseAuth.credential, isNull);
    });

    test('a Firebase network error maps to the network message', () async {
      firebaseAuth.error = FirebaseAuthException(code: 'network-request-failed');

      final result = await repository.signInWithGoogle();

      expect(result!.isSuccess, isFalse);
      expect(result.errorMessage, 'Network error. Please check your connection and try again.');
    });

    test('Google turned off in Firebase says Google is unavailable, not email/password', () async {
      firebaseAuth.error = FirebaseAuthException(code: 'operation-not-allowed');

      final result = await repository.signInWithGoogle();

      expect(result!.errorMessage, googleUnavailableMessage);
    });

    test('an existing account with another sign-in method gets the generic message', () async {
      firebaseAuth.error = FirebaseAuthException(
        code: 'account-exists-with-different-credential',
        email: 'ada@example.com',
      );

      final result = await repository.signInWithGoogle();

      // Never says how the email signs in (RFC-011 D-10). SI-F3 adds the linking flow.
      expect(result!.errorMessage, googleFailedMessage);
    });

    test('a Firebase failure signs out of Google so the next try shows the account picker',
        () async {
      firebaseAuth.error = FirebaseAuthException(code: 'user-disabled');

      final result = await repository.signInWithGoogle();

      expect(result!.errorMessage, 'This account has been disabled. Please contact support.');
      expect(googleSignIn.signOuts, 1);
    });
  });

  group('name prefill (RFC-011 D-7)', () {
    test('an empty draft gets the given and family names from the Google profile', () async {
      firebaseAuth.result = _FakeUserCredential(
        _FakeUser(displayName: 'Ada King'),
        AdditionalUserInfo(
          isNewUser: true,
          profile: {'given_name': 'Ada', 'family_name': 'Lovelace'},
        ),
      );

      await repository.signInWithGoogle();

      expect(names(), (first: 'Ada', last: 'Lovelace'));
    });

    test('without given and family names, the display name is split on its first space',
        () async {
      googleSignIn.onAuthenticate = () async => _FakeAccount(displayName: 'Mary Ann Smith');

      await repository.signInWithGoogle();

      expect(names(), (first: 'Mary', last: 'Ann Smith'));
    });

    test("falls back to the Firebase user's display name", () async {
      await repository.signInWithGoogle();

      expect(names(), (first: 'Ada', last: 'Lovelace'));
    });

    test('a name already in the draft is kept', () async {
      await draft.updateFields(firstName: 'Augusta');
      googleSignIn.onAuthenticate = () async => _FakeAccount(displayName: 'Ada Lovelace');

      await repository.signInWithGoogle();

      expect(names(), (first: 'Augusta', last: null));
    });

    test('a failed sign-in leaves the draft alone', () async {
      firebaseAuth.error = FirebaseAuthException(code: 'network-request-failed');

      await repository.signInWithGoogle();

      expect(names(), (first: null, last: null));
    });
  });

  test('logs no token, email or name (RFC-011 primer rule 10)', () async {
    googleSignIn.onAuthenticate = () async => _FakeAccount(displayName: 'Ada Lovelace');
    await repository.signInWithGoogle();

    googleSignIn.onAuthenticate = () async => throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
          description: 'ada@example.com',
        );
    await repository.signInWithGoogle();

    googleSignIn.onAuthenticate = () async => _FakeAccount();
    firebaseAuth.error = FirebaseAuthException(
      code: 'account-exists-with-different-credential',
      email: 'ada@example.com',
      message: 'ada@example.com',
    );
    await repository.signInWithGoogle();

    final logged = logs.lines.join('\n');
    expect(logs.lines, isNotEmpty);
    expect(logged, contains('uid-123'));
    expect(logged, isNot(contains(_idToken)));
    expect(logged, isNot(contains('ada@example.com')));
    expect(logged, isNot(contains('Ada')));
    expect(logged, isNot(contains('Lovelace')));
  });
}

typedef ProviderNameFields = ({String? first, String? last});
