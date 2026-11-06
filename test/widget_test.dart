import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/notifications/messaging_client.dart';
import 'package:eros_app/features/auth/data/repositories/auth_repository.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/main.dart';

import 'core/notifications/fake_messaging.dart';

/// Signed out from the start; Firebase itself is never touched.
class _SignedOutAuthRepository implements AuthRepository {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The real [ErosApp] for someone signed out. Tests have no Firebase app, so
/// auth and push are faked; `AuthLoadingScreen` then routes to `/welcome`.
Future<void> _pumpSignedOutApp(WidgetTester tester) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => AuthStateNotifier(_SignedOutAuthRepository())),
      messagingClientProvider.overrideWithValue(FakeMessagingClient()),
    ],
    child: const ErosApp(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('App loads welcome screen', (WidgetTester tester) async {
    await _pumpSignedOutApp(tester);

    // Verify that the welcome screen loads with the "Start Dating" button
    expect(find.text('Muse'), findsOneWidget);
    expect(find.text('Start Dating'), findsOneWidget);
    expect(
      find.text('Skip the small talk,\ngo straight to the date'),
      findsOneWidget,
    );
  });

  testWidgets('Navigate to auth method selection', (WidgetTester tester) async {
    await _pumpSignedOutApp(tester);

    // Tap the "Start Dating" button
    await tester.tap(find.text('Start Dating'));
    await tester.pumpAndSettle();

    // Verify that we navigate to auth method selection screen
    expect(find.text('How would you like to\nsign up?'), findsOneWidget);
    expect(find.text('Continue with Email'), findsOneWidget);
  });
}
