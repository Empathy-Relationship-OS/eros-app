import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/legal/data/services/age_signal_service.dart';
import 'package:eros_app/features/legal/domain/models/store_age_signal.dart';
import 'package:eros_app/features/legal/presentation/age_signal_copy.dart';
import 'package:eros_app/features/legal/presentation/providers/age_signal_providers.dart';
import 'package:eros_app/features/legal/presentation/screens/store_age_check_gate.dart';
import 'package:eros_app/features/legal/presentation/screens/underage_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_age_signals_platform.dart';

class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthService implements AuthService {
  String uid = 'user1';

  @override
  User? get currentUser => _FakeUser(uid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness(StoreAgeSignal? signal) : service = FixedAgeSignalService(signal);

  final FixedAgeSignalService service;
  final auth = _FakeAuthService();
  int signOuts = 0;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ageSignalServiceProvider.overrideWithValue(service),
        authServiceProvider.overrideWithValue(auth),
        underageSignOutProvider.overrideWithValue(() async => signOuts++),
      ],
      child: MaterialApp(
        initialRoute: '/dob',
        routes: {
          '/': (_) => const Text('Before'),
          '/dob': (_) => const StoreAgeCheckGate(child: Text('Date of birth')),
          '/welcome': (_) => const Text('Welcome'),
        },
      ),
    ));
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.byType(Navigator)));
  }
}

void main() {
  testWidgets('a minor band stops sign-up on the underage screen and signs out', (tester) async {
    final harness = _Harness(minorSignal);
    await harness.pump(tester);

    expect(find.text('Date of birth'), findsNothing);
    expect(find.text(AgeSignalCopy.underageTitle), findsOneWidget);
    expect(harness.signOuts, 1);
    expect(harness.container.read(signupAgeCheckProvider), isNull);

    // Nothing behind it to go back to.
    expect(find.text('Before'), findsNothing);
    await tester.tap(find.text(AgeSignalCopy.underageDone));
    await tester.pumpAndSettle();
    expect(find.text('Welcome'), findsOneWidget);
  });

  testWidgets('an adult band continues and keeps the signal for POST /users', (tester) async {
    final harness = _Harness(adultSignal);
    await harness.pump(tester);

    expect(find.text('Date of birth'), findsOneWidget);
    expect(harness.signOuts, 0);
    final check = harness.container.read(signupAgeCheckProvider)!;
    expect(check.uid, 'user1');
    expect(check.signal, adultSignal);
  });

  testWidgets('no signal continues and records that the store was asked', (tester) async {
    final harness = _Harness(null);
    await harness.pump(tester);

    expect(find.text('Date of birth'), findsOneWidget);
    final check = harness.container.read(signupAgeCheckProvider)!;
    expect(check.signal, isNull);
  });

  testWidgets('asks once per sign-up, not each time the step opens', (tester) async {
    final harness = _Harness(adultSignal);
    await harness.pump(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    navigator.pop();
    await tester.pumpAndSettle();
    navigator.pushNamed('/dob');
    await tester.pumpAndSettle();

    expect(find.text('Date of birth'), findsOneWidget);
    expect(harness.service.reads, 1);
  });

  testWidgets('asks again for another user in the same app session', (tester) async {
    final harness = _Harness(adultSignal);
    await harness.pump(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    navigator.pop();
    await tester.pumpAndSettle();
    harness.auth.uid = 'user2';
    navigator.pushNamed('/dob');
    await tester.pumpAndSettle();

    expect(harness.service.reads, 2);
    expect(harness.container.read(signupAgeCheckProvider)!.uid, 'user2');
  });
}
