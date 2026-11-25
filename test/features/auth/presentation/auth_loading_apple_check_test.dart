import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/auth/data/repositories/auth_repository.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/auth/presentation/screens/auth_loading_screen.dart';
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

/// Signed in, with the answer to the launch check on Apple's credential (RFC-011 §5.3).
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.revoked);

  final Future<bool> Function() revoked;
  int signOuts = 0;

  @override
  User? get currentUser => _FakeUser();

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<bool> hasRevokedAppleCredential() => revoked();

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
  int checks = 0;

  @override
  Future<UserExistsResponse> checkUserExists() async {
    checks++;
    return UserExistsResponse(exists: false, userId: 'user1');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeProfileRepository profiles;

  Future<_FakeAuthRepository> launch(WidgetTester tester, Future<bool> Function() revoked) async {
    final auth = _FakeAuthRepository(revoked);
    profiles = _FakeProfileRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        authStateProvider.overrideWith((ref) => AuthStateNotifier(auth)),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
      child: MaterialApp(
        home: const AuthLoadingScreen(),
        routes: {
          '/welcome': (_) => const Text('Welcome'),
          '/profile-creation/name': (_) => const Text('Profile creation'),
        },
      ),
    ));
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('a revoked Apple ID signs out to the welcome screen', (tester) async {
    final auth = await launch(tester, () async => true);

    expect(auth.signOuts, 1);
    expect(find.text('Welcome'), findsOneWidget);
    expect(profiles.checks, 0);
  });

  testWidgets('an Apple ID that still authorises Muse carries on to the profile check',
      (tester) async {
    final auth = await launch(tester, () async => false);

    expect(auth.signOuts, 0);
    expect(profiles.checks, 1);
    expect(find.text('Profile creation'), findsOneWidget);
  });

  testWidgets('a failed check carries on: nobody is signed out because Apple was unreachable',
      (tester) async {
    final auth = await launch(tester, () async => throw StateError('Apple unreachable'));

    expect(auth.signOuts, 0);
    expect(profiles.checks, 1);
    expect(find.text('Profile creation'), findsOneWidget);
  });
}
