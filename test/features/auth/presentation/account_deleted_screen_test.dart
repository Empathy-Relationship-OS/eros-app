import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/config/support_config.dart';
import 'package:eros_app/features/auth/data/repositories/auth_repository.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/auth/presentation/screens/account_deleted_screen.dart';
import 'package:eros_app/features/auth/presentation/screens/auth_loading_screen.dart';
import 'package:eros_app/features/legal/data/support_email.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUser implements User {
  @override
  String get uid => 'user1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Signed in, with an Apple credential that still authorises Muse.
class _FakeAuthRepository implements AuthRepository {
  int signOuts = 0;

  @override
  User? get currentUser => _FakeUser();

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<bool> hasRevokedAppleCredential() async => false;

  @override
  Future<void> signOut() async => signOuts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthService implements AuthService {
  @override
  User? get currentUser => _FakeUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.response);

  final UserExistsResponse response;

  @override
  Future<UserExistsResponse> checkUserExists() async => response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLinks implements LegalLinks {
  final emails = <Uri>[];

  @override
  Future<bool> openDocument(Uri url) async => true;

  @override
  Future<bool> openEmail(Uri email) async {
    emails.add(email);
    return true;
  }
}

void main() {
  late _FakeAuthRepository auth;
  late _FakeLinks links;

  Future<void> launch(WidgetTester tester, UserExistsResponse response) async {
    auth = _FakeAuthRepository();
    links = _FakeLinks();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        authStateProvider.overrideWith((ref) => AuthStateNotifier(auth)),
        profileRepositoryProvider.overrideWithValue(_FakeProfileRepository(response)),
        legalLinksProvider.overrideWithValue(links),
      ],
      child: MaterialApp(
        home: const AuthLoadingScreen(),
        routes: {
          '/welcome': (_) => const Text('Welcome'),
          '/profile-creation/name': (_) => const Text('Profile creation'),
          '/match': (_) => const Text('Match'),
        },
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('AuthLoadingScreen', () {
    testWidgets('a deleted account goes to the deleted screen, not profile creation',
        (tester) async {
      await launch(tester, UserExistsResponse(exists: false, userId: 'user1', deleted: true));

      expect(find.byType(AccountDeletedScreen), findsOneWidget);
      expect(find.text(AccountDeletedCopy.body), findsOneWidget);
      expect(find.text('Profile creation'), findsNothing);
      expect(auth.signOuts, 0, reason: 'the user signs out themselves');
    });

    testWidgets('without deleted, a new user still goes to profile creation', (tester) async {
      await launch(tester, UserExistsResponse(exists: false, userId: 'user1'));

      expect(find.text('Profile creation'), findsOneWidget);
      expect(find.byType(AccountDeletedScreen), findsNothing);
    });
  });

  group('AccountDeletedScreen', () {
    testWidgets('contact support emails the support address with the account id only',
        (tester) async {
      await launch(tester, UserExistsResponse(exists: false, userId: 'user1', deleted: true));

      expect(find.text(SupportConfig.supportEmail), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('account-deleted-contact')));
      await tester.pumpAndSettle();

      final email = links.emails.single;
      expect(email.scheme, 'mailto');
      expect(email.path, SupportConfig.supportEmail);
      expect(email.queryParameters['subject'], 'Deleted account');
      expect(email.queryParameters['body']!.trim(), 'Account id: user1');
    });

    testWidgets('Sign out signs out and goes to the welcome screen', (tester) async {
      await launch(tester, UserExistsResponse(exists: false, userId: 'user1', deleted: true));

      await tester.tap(find.byKey(const ValueKey('account-deleted-sign-out')));
      await tester.pumpAndSettle();

      expect(auth.signOuts, 1);
      expect(find.text('Welcome'), findsOneWidget);
    });
  });
}
