import 'package:eros_app/core/auth/apple_sign_in.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/auth/sign_out_service.dart';
import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/features/auth/data/repositories/auth_repository.dart';
import 'package:eros_app/features/auth/domain/models/account_link.dart';
import 'package:eros_app/features/auth/presentation/screens/account_deleted_screen.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/auth/presentation/screens/auth_loading_screen.dart';
import 'package:eros_app/features/auth/presentation/screens/auth_method_selection_screen.dart';
import 'package:eros_app/features/auth/presentation/screens/password_creation_screen.dart';
import 'package:eros_app/features/auth/presentation/screens/password_sign_in_screen.dart';
import 'package:eros_app/features/auth/presentation/widgets/account_link_banner.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

// RFC-011 §5.4 on screen: Google or Apple meets an email that already has an account, the user
// signs in with their password, and the app adds the new sign-in. Nothing names the account's
// own method (D-10).

const _email = 'ada@example.com';

final _iOS = TargetPlatformVariant.only(TargetPlatform.iOS);
final _android = TargetPlatformVariant.only(TargetPlatform.android);

class _FakeUser implements User {
  @override
  String get uid => 'uid-123';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PendingAccountLink _link(LinkingProvider provider) => PendingAccountLink(
      email: _email,
      credential: GoogleAuthProvider.credential(idToken: 'pending'),
      provider: provider,
    );

/// Google and Apple both meet an existing account; the password is right; linking does
/// [linkResult].
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.linkSucceeds = true});

  final bool linkSucceeds;
  final linked = <PendingAccountLink>[];
  final passwordSignIns = <String>[];

  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<AuthResult?> signInWithGoogle() async =>
      AuthResult.needsLink(_link(LinkingProvider.google));

  @override
  Future<AuthResult?> signInWithApple() async =>
      AuthResult.needsLink(_link(LinkingProvider.apple));

  @override
  Future<AuthResult> signInWithEmail({required String email, required String password}) async {
    passwordSignIns.add(email);
    return AuthResult.success(_FakeUser());
  }

  @override
  Future<AuthResult> linkPendingCredential(PendingAccountLink link) async {
    linked.add(link);
    return linkSucceeds
        ? AuthResult.success(_FakeUser())
        : AuthResult.failure(accountLinkFailedMessage(link.provider));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A user with no profile yet, so the password screen routes to profile creation; or, with
/// [deleted], a deleted account (RFC-011 D-12).
class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.deleted = false});

  final bool deleted;

  @override
  Future<UserExistsResponse> checkUserExists() async =>
      UserExistsResponse(exists: false, userId: 'uid-123', deleted: deleted);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Firebase answering an email sign-in or sign-up with [error], for the real repository.
class _FailingFirebaseAuth implements FirebaseAuth {
  _FailingFirebaseAuth(this.error);

  final FirebaseAuthException error;

  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async =>
      throw error;

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async =>
      throw error;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Unused implements AuthService, SignOutService, GoogleSignIn, AppleSignInClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The real repository, so the platform decides whether Apple is named (D-2).
AuthRepository _realRepository(FirebaseAuthException error) => AuthRepository(
      _FailingFirebaseAuth(error),
      _Unused(),
      _Unused(),
      googleSignIn: _Unused(),
      appleSignIn: _Unused(),
      profileDraft: () => throw UnimplementedError(),
    );

Future<void> _pump(
  WidgetTester tester,
  AuthRepository repository,
  Widget home, {
  bool deleted = false,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => AuthStateNotifier(repository)),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository(deleted: deleted)),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: home,
      routes: {
        AuthLoadingScreen.routeName: (context) => const Scaffold(body: Text('auth loading')),
        '/profile-creation/name': (context) => const Scaffold(body: Text('profile creation')),
      },
    ),
  ));
  await tester.pumpAndSettle();
}

String _bannerText(LinkingProvider provider) =>
    AccountLinkBanner.textFor(provider, appleOffered: defaultTargetPlatform == TargetPlatform.iOS);

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField), 'a-password');
  await tester.pump();
  await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('the method screen', () {
    testWidgets('Apple meeting an existing account opens the password screen with the banner',
        (tester) async {
      await _pump(tester, _FakeAuthRepository(), const AuthMethodSelectionScreen());

      await tester.tap(find.byKey(const Key('auth-apple')));
      await tester.pumpAndSettle();

      expect(find.byType(PasswordSignInScreen), findsOneWidget);
      expect(find.text(_email), findsOneWidget);
      expect(
        find.text('You already have a Muse account with this email. Sign in with your password '
            'to add Apple. Or go back and use the other sign-in option.'),
        findsOneWidget,
      );
      // Not an error: no snackbar.
      expect(find.byType(SnackBar), findsNothing);
    }, variant: _iOS);

    testWidgets('Google meeting an existing account on iOS names Google only', (tester) async {
      await _pump(tester, _FakeAuthRepository(), const AuthMethodSelectionScreen());

      await tester.tap(find.byKey(const Key('auth-google')));
      await tester.pumpAndSettle();

      expect(find.text(_email), findsOneWidget);
      expect(
        find.text('You already have a Muse account with this email. Sign in with your password '
            'to add Google. Or go back and use the other sign-in option.'),
        findsOneWidget,
      );
      expect(find.textContaining('Apple'), findsNothing);
    }, variant: _iOS);

    testWidgets('Google meeting an existing account on Android has no "other option" (D-2)',
        (tester) async {
      await _pump(tester, _FakeAuthRepository(), const AuthMethodSelectionScreen());

      await tester.tap(find.byKey(const Key('auth-google')));
      await tester.pumpAndSettle();

      expect(find.text(_email), findsOneWidget);
      expect(
        find.text('You already have a Muse account with this email. Sign in with your password '
            'to add Google.'),
        findsOneWidget,
      );
      expect(find.textContaining('other sign-in option'), findsNothing);
    }, variant: _android);
  });

  group('the password screen', () {
    testWidgets('shows no banner for an ordinary email sign-in', (tester) async {
      await _pump(tester, _FakeAuthRepository(), const PasswordSignInScreen(email: _email));

      expect(find.text(_email), findsOneWidget);
      expect(find.byType(AccountLinkBanner), findsNothing);
    });

    for (final provider in LinkingProvider.values) {
      testWidgets('shows the banner and the email for ${provider.label}', (tester) async {
        await _pump(
          tester,
          _FakeAuthRepository(),
          PasswordSignInScreen(email: _email, accountLink: _link(provider)),
        );

        expect(find.text(_email), findsOneWidget);
        expect(find.text(_bannerText(provider)), findsOneWidget);
        // "Forgot password?" stays, for an account without a password yet.
        expect(find.text('Forgot password?'), findsOneWidget);
      }, variant: _iOS);
    }

    testWidgets('fits a small phone with the keyboard up, by scrolling', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 667);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.reset);

      await _pump(
        tester,
        _FakeAuthRepository(),
        PasswordSignInScreen(email: _email, accountLink: _link(LinkingProvider.apple)),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AccountLinkBanner), findsOneWidget);
    }, variant: _iOS);

    testWidgets('keeps Sign in at the bottom when there is room', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      await _pump(
        tester,
        _FakeAuthRepository(),
        PasswordSignInScreen(email: _email, accountLink: _link(LinkingProvider.apple)),
      );

      final button = tester.getRect(find.widgetWithText(ElevatedButton, 'Sign in'));
      // 16 below it, then the 24 of padding.
      expect(button.bottom, closeTo(844 - 16 - 24, 1));
    }, variant: _iOS);

    testWidgets('links the pending sign-in after the password, then routes as usual',
        (tester) async {
      final repository = _FakeAuthRepository();
      final link = _link(LinkingProvider.apple);
      await _pump(tester, repository, PasswordSignInScreen(email: _email, accountLink: link));

      await _signIn(tester);
      await tester.pumpAndSettle();

      expect(repository.passwordSignIns, [_email]);
      expect(repository.linked, [same(link)]);
      expect(find.text("Signed in. We couldn't add Apple this time."), findsNothing);
      expect(find.text('profile creation'), findsOneWidget);
    }, variant: _iOS);

    testWidgets('a failed link says so and still routes the signed-in user', (tester) async {
      final repository = _FakeAuthRepository(linkSucceeds: false);
      await _pump(
        tester,
        repository,
        PasswordSignInScreen(email: _email, accountLink: _link(LinkingProvider.apple)),
      );

      await _signIn(tester);

      expect(find.text("Signed in. We couldn't add Apple this time."), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('profile creation'), findsOneWidget);
    }, variant: _iOS);

    testWidgets('a deleted account goes to the deleted screen and links nothing (SI-F4)',
        (tester) async {
      final repository = _FakeAuthRepository();
      await _pump(
        tester,
        repository,
        PasswordSignInScreen(email: _email, accountLink: _link(LinkingProvider.apple)),
        deleted: true,
      );

      await _signIn(tester);
      await tester.pumpAndSettle();

      expect(repository.passwordSignIns, [_email]);
      expect(repository.linked, isEmpty);
      expect(find.byType(AccountDeletedScreen), findsOneWidget);
      expect(find.text('profile creation'), findsNothing);
    }, variant: _iOS);

    testWidgets('a deleted account without a pending link goes to the deleted screen too',
        (tester) async {
      final repository = _FakeAuthRepository();
      await _pump(tester, repository, const PasswordSignInScreen(email: _email), deleted: true);

      await _signIn(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AccountDeletedScreen), findsOneWidget);
      expect(find.text('profile creation'), findsNothing);
    });

    testWidgets('an ordinary email sign-in links nothing', (tester) async {
      final repository = _FakeAuthRepository();
      await _pump(tester, repository, const PasswordSignInScreen(email: _email));

      await _signIn(tester);
      await tester.pumpAndSettle();

      expect(repository.passwordSignIns, [_email]);
      expect(repository.linked, isEmpty);
    });
  });

  group('email messages that point to Google and Apple (RFC-011 §5.4)', () {
    const iOSWrongPassword =
        'Incorrect email or password. If you signed up with Google or Apple, use that button '
        'instead.';
    const androidWrongPassword =
        'Incorrect email or password. If you signed up with Google, use that button instead.';

    testWidgets('a wrong password on iOS', (tester) async {
      final repository = _realRepository(FirebaseAuthException(code: 'invalid-credential'));
      await _pump(tester, repository, const PasswordSignInScreen(email: _email));

      await _signIn(tester);

      expect(find.text(iOSWrongPassword), findsOneWidget);
    }, variant: _iOS);

    testWidgets('a wrong password on Android', (tester) async {
      final repository = _realRepository(FirebaseAuthException(code: 'wrong-password'));
      await _pump(tester, repository, const PasswordSignInScreen(email: _email));

      await _signIn(tester);

      expect(find.text(androidWrongPassword), findsOneWidget);
    }, variant: _android);

    Future<void> signUp(WidgetTester tester) async {
      final repository = _realRepository(FirebaseAuthException(code: 'email-already-in-use'));
      await _pump(tester, repository, const PasswordCreationScreen(email: _email));
      await tester.enterText(find.byType(TextFormField), 'a-long-password');
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('sign-up with a registered email on iOS', (tester) async {
      await signUp(tester);

      expect(
        find.text('This email is already registered. Sign in, or try Continue with Google or '
            'Apple.'),
        findsOneWidget,
      );
    }, variant: _iOS);

    testWidgets('sign-up with a registered email on Android', (tester) async {
      await signUp(tester);

      expect(
        find.text('This email is already registered. Sign in, or try Continue with Google.'),
        findsOneWidget,
      );
    }, variant: _android);
  });
}
