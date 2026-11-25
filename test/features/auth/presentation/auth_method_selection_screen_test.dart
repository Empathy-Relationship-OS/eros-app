import 'dart:async';

import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/features/auth/data/repositories/auth_repository.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/auth/presentation/screens/auth_loading_screen.dart';
import 'package:eros_app/features/auth/presentation/screens/auth_method_selection_screen.dart';
import 'package:eros_app/features/auth/presentation/screens/email_entry_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUser implements User {
  @override
  String get uid => 'uid-123';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Signed out, with a Google sign-in each test finishes by hand.
class _FakeAuthRepository implements AuthRepository {
  int googleCalls = 0;

  /// Made inside each test: a completer from `setUp` sits outside the test's fake async zone, and
  /// its completion would never reach the screen.
  late Completer<AuthResult?> google;

  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<AuthResult?> signInWithGoogle() {
    googleCalls++;
    return google.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeAuthRepository repository;

  setUp(() => repository = _FakeAuthRepository());

  Future<void> pumpScreen(WidgetTester tester) async {
    repository.google = Completer<AuthResult?>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => AuthStateNotifier(repository)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AuthMethodSelectionScreen(),
        routes: {
          AuthLoadingScreen.routeName: (context) => const Scaffold(body: Text('auth loading')),
        },
      ),
    ));
  }

  Finder google() => find.byKey(const Key('auth-google'));
  Finder email() => find.byKey(const Key('auth-email'));

  testWidgets('shows Continue with Google above Continue with Email', (tester) async {
    await pumpScreen(tester);

    expect(find.text('How would you like to\ncontinue?'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Email'), findsOneWidget);
    expect(tester.getTopLeft(google()).dy, lessThan(tester.getTopLeft(email()).dy));
    // Same height (RFC-011 primer rule 15).
    expect(tester.getSize(google()).height, tester.getSize(email()).height);
    // Apple is SI-F2's, and never on Android.
    expect(find.textContaining('Apple'), findsNothing);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('a tap while signing in with Google does nothing', (tester) async {
    await pumpScreen(tester);

    await tester.tap(google());
    await tester.pump();

    expect(repository.googleCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);

    await tester.tap(google(), warnIfMissed: false);
    await tester.tap(email(), warnIfMissed: false);
    // The spinner never settles: pump past a page transition instead.
    await tester.pump(const Duration(seconds: 1));

    expect(repository.googleCalls, 1);
    expect(find.byType(EmailEntryScreen), findsNothing);
  });

  testWidgets('closing the Google sheet goes back to the buttons with no message', (tester) async {
    await pumpScreen(tester);

    await tester.tap(google());
    await tester.pump();
    repository.google.complete(null);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(AuthMethodSelectionScreen), findsOneWidget);
  });

  testWidgets('a failure shows its message and turns the buttons back on', (tester) async {
    await pumpScreen(tester);

    await tester.tap(google());
    await tester.pump();
    repository.google.complete(AuthResult.failure(googleUnavailableMessage));
    await tester.pumpAndSettle();

    expect(find.text(googleUnavailableMessage), findsOneWidget);

    repository.google = Completer<AuthResult?>();
    await tester.tap(google());
    await tester.pump();
    expect(repository.googleCalls, 2);
  });

  testWidgets('success hands over to the auth loading route', (tester) async {
    await pumpScreen(tester);

    await tester.tap(google());
    await tester.pump();
    repository.google.complete(AuthResult.success(_FakeUser()));
    await tester.pumpAndSettle();

    expect(find.text('auth loading'), findsOneWidget);
    expect(find.byType(AuthMethodSelectionScreen), findsNothing);
  });
}
