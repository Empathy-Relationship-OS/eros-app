import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/auth/data/repositories/auth_repository.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/auth/presentation/screens/auth_loading_screen.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_status_pill.dart';
import 'package:eros_app/features/devtools/data/devtools_api.dart';
import 'package:eros_app/features/devtools/data/models/devtools_models.dart';
import 'package:eros_app/features/devtools/data/persona_session_service.dart';
import 'package:eros_app/features/devtools/presentation/providers/devtools_providers.dart';
import 'package:eros_app/features/devtools/presentation/scenario_navigation.dart';
import 'package:eros_app/features/devtools/presentation/tabs/scenarios_tab.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import '../fake_devtools_api.dart';

// ====================
// FAKES
// ====================

class _FakeSessionService implements PersonaSessionService {
  final List<String> signedInAs = [];
  int signOuts = 0;
  Object? signInError;

  @override
  Future<void> signInAs(String uid) async {
    signedInAs.add(uid);
    if (signInError != null) throw signInError!;
  }

  @override
  Future<void> signOut() async => signOuts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  @override
  final String uid;

  _FakeUser(this.uid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Signed in from the start; Firebase itself is never touched.
class _FakeAuthRepository implements AuthRepository {
  @override
  final User? currentUser;

  _FakeAuthRepository(this.currentUser);

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers `AuthLoadingScreen`'s `/users/exists` check. Each call takes the
/// next answer from [answers]; once they run out, "profile exists".
class _FakeProfileRepository implements ProfileRepository {
  final List<Future<UserExistsResponse> Function()> answers = [];
  int checks = 0;

  @override
  Future<UserExistsResponse> checkUserExists() {
    checks++;
    if (answers.isNotEmpty) return answers.removeAt(0)();
    return Future.value(UserExistsResponse(exists: true, userId: 'u'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ====================
// HARNESS
// ====================

const _matchMarker = 'MATCH SCREEN';
const _profileCreationMarker = 'PROFILE CREATION';
const _devRoute = '/dev';

/// The real `AuthLoadingScreen` at '/', placeholders for the screens it
/// routes to, and `/dates/detail` built exactly as `main.dart`'s
/// `onGenerateRoute` does (the argument is cast to `String`).
class _Harness {
  final FakeDevtoolsApi api = FakeDevtoolsApi(personas: standardCast());
  final _FakeSessionService session = _FakeSessionService();
  final _FakeProfileRepository profile = _FakeProfileRepository();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final List<Object?> dateDetailArguments = [];
  late SharedPreferences prefs;

  /// devtoolsHealthProvider is in timeSensitiveProviders, so counting its
  /// builds shows whether invalidateTimeSensitiveState ran.
  int healthBuilds = 0;

  NavigatorState get navigator => navigatorKey.currentState!;

  /// Launches the app (which lands on the match screen) and opens the
  /// Scenarios tab on top of it, as the dev menu would.
  Future<void> pump(WidgetTester tester, {String? signedInUid}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          devtoolsApiProvider.overrideWithValue(api),
          sharedPreferencesProvider.overrideWithValue(prefs),
          devtoolsSignedInUidProvider.overrideWithValue(signedInUid),
          personaSessionServiceProvider.overrideWithValue(session),
          authStateProvider.overrideWith(
            (ref) => AuthStateNotifier(
              _FakeAuthRepository(_FakeUser(signedInUid ?? 'real-user')),
            ),
          ),
          profileRepositoryProvider.overrideWithValue(profile),
          devtoolsHealthProvider.overrideWith((ref) async {
            healthBuilds++;
            return DevtoolsHealth(
              enabled: true,
              serverTime: DateTime.utc(2026, 10, 17, 13),
              offsetSeconds: 0,
            );
          }),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const AuthLoadingScreen(),
          routes: {
            matchRoute: (_) => const Scaffold(body: Text(_matchMarker)),
            '/profile-creation/name': (_) =>
                const Scaffold(body: Text(_profileCreationMarker)),
            _devRoute: (_) => Scaffold(
              body: Column(
                children: [
                  // Keeps devtoolsHealthProvider alive, like the dev menu
                  // header.
                  Consumer(
                    builder: (context, ref, _) {
                      ref.watch(devtoolsHealthProvider);
                      return const SizedBox.shrink();
                    },
                  ),
                  const Expanded(child: ScenariosTab()),
                ],
              ),
            ),
          },
          onGenerateRoute: (settings) {
            if (settings.name == dateDetailRoute) {
              dateDetailArguments.add(settings.arguments);
              final dateId = settings.arguments as String;
              return MaterialPageRoute(
                builder: (_) => Scaffold(body: Text('DATE DETAIL $dateId')),
              );
            }
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_matchMarker), findsOneWidget);

    await openTab(tester);
  }

  Future<void> openTab(WidgetTester tester) async {
    unawaited(navigator.pushNamed(_devRoute));
    await tester.pumpAndSettle();
  }

  /// Runs [name] with fresh personas through the bottom sheet.
  Future<void> run(WidgetTester tester, String name) async {
    await tap(tester, find.byKey(ValueKey('scenario-$name')));
    await tap(tester, find.byKey(const Key('scenarioRunButton')));
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// [tap] for when a spinner keeps animating afterwards, so the frame never
/// settles: pumps long enough for route transitions to finish.
Future<void> tapWhileBusy(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Finder _personaRow(String uid) => find.byKey(ValueKey('scenarioPersona-$uid'));

final _logInAndOpen = find.byKey(const Key('scenarioLogInAndOpen'));

void main() {
  group('scenario list', () {
    testWidgets('renders the backend list in order, with end states', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);

      expect(h.api.calls, contains('listScenarios'));
      final names = ['zz-match-only', 'zz-deposit-partner-paid', 'zz-booked'];
      final tops = [
        for (final name in names) tester.getTopLeft(find.text(name)).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(find.text('B has paid the deposit, A has not.'), findsOneWidget);

      // Date states use the dates feature's pill; others a plain chip.
      expect(
        find.widgetWithText(DateStatusPill, 'AWAITING_DEPOSIT'),
        findsOneWidget,
      );
      expect(find.widgetWithText(DateStatusPill, 'BOOKED'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'MATCH'), findsOneWidget);
    });

    testWidgets('shows a scenario the app has never heard of', (tester) async {
      final h = _Harness();
      h.api.scenarios = [
        const ScenarioInfo(
          name: 'brand-new-backend-scenario',
          description: 'Added on the backend only.',
          endState: 'SOMETHING_NEW',
        ),
      ];
      await h.pump(tester);

      expect(find.text('brand-new-backend-scenario'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'SOMETHING_NEW'), findsOneWidget);
      expect(find.text('zz-booked'), findsNothing);
    });

    testWidgets('shows the backend message when the list fails', (
      tester,
    ) async {
      final h = _Harness();
      h.api.scenariosError = const NotFoundException('Resource not found');
      await h.pump(tester);

      expect(
        find.text('Could not load scenarios: Resource not found'),
        findsOneWidget,
      );
    });
  });

  group('running a scenario', () {
    testWidgets('runs with fresh personas and shows the result card', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);

      await h.run(tester, 'zz-booked');

      expect(h.api.calls, contains('runScenario:zz-booked'));
      expect(h.api.lastHandles, isNull);

      // Notes verbatim.
      expect(
        find.descendant(
          of: find.byKey(const Key('scenarioNotes')),
          matching: find.text(
            'Date starts 2026-10-18T19:00:00Z. Advance the clock 25h to open '
            'the presence window.',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Match 42 | Date 17'), findsOneWidget);

      // A button per persona, ops included, and the primary button.
      for (final uid in ['dev_s1a2b3_a', 'dev_s1a2b3_b', 'dev_ops']) {
        expect(
          find.descendant(
            of: _personaRow(uid),
            matching: find.widgetWithText(TextButton, 'Log in as'),
          ),
          findsOneWidget,
          reason: uid,
        );
      }
      expect(find.text('Ops (ops)'), findsOneWidget);
      expect(find.text('Log in as Ava and open date'), findsOneWidget);
    });

    testWidgets('refreshes time-sensitive state after a run', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      expect(h.healthBuilds, 1);

      await h.run(tester, 'zz-booked');

      expect(h.healthBuilds, 2);
    });

    testWidgets('passes the two chosen personas as handles', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await tap(tester, find.byKey(const ValueKey('scenario-zz-booked')));

      await tap(tester, find.byKey(const Key('scenarioPersonaA')));
      await tap(tester, find.text('Alice (dev_alice)').last);

      // Only one chosen: cannot run.
      expect(find.text('Pick both personas, or neither'), findsOneWidget);
      final run = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('scenarioRunButton')),
      );
      expect(run.onPressed, isNull);

      await tap(tester, find.byKey(const Key('scenarioPersonaB')));
      await tap(tester, find.text('Bob (dev_bob)').last);
      // The admin persona is not offered.
      expect(find.text('Ops (dev_ops)'), findsNothing);

      await tap(tester, find.byKey(const Key('scenarioRunButton')));

      expect(h.api.lastHandles, ['alice', 'bob']);
    });

    testWidgets('shows progress and blocks a second run meanwhile', (
      tester,
    ) async {
      final h = _Harness();
      final gate = Completer<void>();
      h.api.runGate = gate;
      await h.pump(tester);

      await tap(tester, find.byKey(const ValueKey('scenario-zz-booked')));
      await tapWhileBusy(tester, find.byKey(const Key('scenarioRunButton')));

      expect(find.text('Running zz-booked...'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scenario-zz-match-only')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ScenarioRunSheet), findsNothing);
      final reset = tester.widget<ButtonStyleButton>(
        find.widgetWithText(OutlinedButton, 'Reset all dev data'),
      );
      expect(reset.onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Running zz-booked...'), findsNothing);
      expect(find.byKey(const Key('scenarioResult')), findsOneWidget);
      expect(
        h.api.calls.where((c) => c.startsWith('runScenario')),
        hasLength(1),
      );
    });

    testWidgets('a 500 shows the backend message in full', (tester) async {
      final h = _Harness();
      const message =
          'Scenario zz-booked failed at step "pay deposit (B)": '
          'InsufficientTokensException: dev_s1a2b3_b has 0 tokens, needs 5';
      h.api.runError = const ServerException(message, statusCode: 500);
      await h.pump(tester);

      await h.run(tester, 'zz-booked');

      expect(find.text('zz-booked failed'), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.byKey(const Key('scenarioResult')), findsNothing);
    });

    testWidgets('the last result survives closing and reopening the menu', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await h.run(tester, 'zz-booked');

      h.navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ScenariosTab), findsNothing);
      await h.openTab(tester);

      expect(find.byKey(const Key('scenarioResult')), findsOneWidget);
      expect(find.text('Log in as Ava and open date'), findsOneWidget);
    });
  });

  group('log in as A and open date', () {
    testWidgets('signs in as loginAs, then opens /dates/detail with the id', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await h.run(tester, 'zz-booked');

      await tap(tester, _logInAndOpen);

      expect(h.session.signedInAs, ['dev_s1a2b3_a']);
      // AuthLoadingScreen ran again for the new user.
      expect(h.profile.checks, 2);
      expect(h.dateDetailArguments, ['17']);
      expect(find.text('DATE DETAIL 17'), findsOneWidget);
      expect(find.byType(ScenariosTab), findsNothing);

      // The date sits on top of the match screen, not instead of it.
      h.navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text(_matchMarker), findsOneWidget);
    });

    testWidgets('waits for AuthLoadingScreen to route before opening it', (
      tester,
    ) async {
      final h = _Harness();
      final profileCheck = Completer<UserExistsResponse>();
      await h.pump(tester);
      await h.run(tester, 'zz-booked');
      h.profile.answers.add(() => profileCheck.future);

      await tapWhileBusy(tester, _logInAndOpen);

      expect(find.byType(AuthLoadingScreen), findsOneWidget);
      expect(h.dateDetailArguments, isEmpty);

      profileCheck.complete(UserExistsResponse(exists: true, userId: 'u'));
      await tester.pumpAndSettle();

      expect(h.dateDetailArguments, ['17']);
      expect(find.text('DATE DETAIL 17'), findsOneWidget);
    });

    testWidgets('does not open the date when routing lands elsewhere', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await h.run(tester, 'zz-booked');
      h.profile.answers.add(
        () async => UserExistsResponse(exists: false, userId: 'u'),
      );

      await tap(tester, _logInAndOpen);

      expect(find.text(_profileCreationMarker), findsOneWidget);
      expect(h.dateDetailArguments, isEmpty);
      expect(
        find.text(
          'Signed in as dev_s1a2b3_a, but the app went to '
          '/profile-creation/name instead of /match, so date 17 was not '
          'opened.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('gives up after the timeout if routing never finishes', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await h.run(tester, 'zz-booked');
      h.profile.answers.add(() => Completer<UserExistsResponse>().future);

      await tapWhileBusy(tester, _logInAndOpen);
      expect(find.byType(AuthLoadingScreen), findsOneWidget);
      await tester.pump(authRoutingTimeout);
      await tester.pump(const Duration(seconds: 1));

      expect(h.dateDetailArguments, isEmpty);
      expect(find.textContaining('still loading after 30s'), findsOneWidget);
    });

    testWidgets('a match scenario opens the match screen', (tester) async {
      final h = _Harness();
      h.api.scenarioResult = ScenarioResult.fromJson(matchScenarioResultJson);
      await h.pump(tester);
      await h.run(tester, 'zz-match-only');

      expect(find.text('Log in as Ava and open match'), findsOneWidget);
      await tap(tester, _logInAndOpen);

      expect(h.session.signedInAs, ['dev_s9_a']);
      expect(find.text(_matchMarker), findsOneWidget);
      expect(h.dateDetailArguments, isEmpty);
    });

    testWidgets('shows the error and stays put when sign-in fails', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await h.run(tester, 'zz-booked');
      h.session.signInError = const NotFoundException(
        'No such persona: dev_s1a2b3_a',
      );

      await tap(tester, _logInAndOpen);

      expect(find.text('No such persona: dev_s1a2b3_a'), findsOneWidget);
      expect(find.byType(ScenariosTab), findsOneWidget);
      expect(h.profile.checks, 1);
    });

    testWidgets('a persona row signs in and restarts without opening a date', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await h.run(tester, 'zz-booked');

      await tap(
        tester,
        find.descendant(
          of: _personaRow('dev_ops'),
          matching: find.text('Log in as'),
        ),
      );

      expect(h.session.signedInAs, ['dev_ops']);
      expect(find.text(_matchMarker), findsOneWidget);
      expect(h.dateDetailArguments, isEmpty);
    });
  });

  group('reset all dev data', () {
    testWidgets('asks for confirmation and does nothing on cancel', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester, signedInUid: 'dev_alice');

      await tap(tester, find.text('Reset all dev data'));

      expect(find.text('Reset all dev data?'), findsOneWidget);
      expect(find.text(resetConfirmationText), findsOneWidget);
      expect(resetConfirmationText, contains('dev_'));
      expect(resetConfirmationText, contains('clock'));

      await tap(tester, find.widgetWithText(TextButton, 'Cancel'));
      expect(h.api.calls, isNot(contains('reset')));
      expect(h.session.signOuts, 0);
    });

    testWidgets('resets, then signs out a signed-in persona', (tester) async {
      final h = _Harness();
      await h.pump(tester, signedInUid: 'dev_alice');
      await h.run(tester, 'zz-booked');

      await tap(tester, find.text('Reset all dev data'));
      await tap(tester, find.widgetWithText(TextButton, 'Reset'));

      expect(h.api.calls, contains('reset'));
      expect(h.session.signOuts, 1);
      expect(find.byType(ScenariosTab), findsNothing);
      expect(
        find.text(
          'Reset: deleted 6 personas, 4 matches and 2 dates. Clock reset. '
          'Signed out of dev_alice.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('keeps a real user signed in and clears the last result', (
      tester,
    ) async {
      final h = _Harness();
      h.api.resetResult = ResetResult.fromJson({
        ...resetResultJson,
        'skippedDates': [9],
      });
      await h.pump(tester, signedInUid: 'firebase-uid-123');
      await h.run(tester, 'zz-booked');

      await tap(tester, find.text('Reset all dev data'));
      await tap(tester, find.widgetWithText(TextButton, 'Reset'));

      expect(h.api.calls, contains('reset'));
      expect(h.session.signOuts, 0);
      expect(find.byType(ScenariosTab), findsOneWidget);
      expect(find.byKey(const Key('scenarioResult')), findsNothing);
      expect(
        find.textContaining('Kept 1 date(s) that include a real user: 9.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the backend message when reset fails', (tester) async {
      final h = _Harness();
      h.api.resetError = const ServerException('Reset failed: db down');
      await h.pump(tester, signedInUid: 'dev_alice');

      await tap(tester, find.text('Reset all dev data'));
      await tap(tester, find.widgetWithText(TextButton, 'Reset'));

      expect(find.text('Reset failed: db down'), findsOneWidget);
      expect(h.session.signOuts, 0);
    });
  });

  group('dateStateFromWire', () {
    test('maps date states and rejects everything else', () {
      expect(dateStateFromWire('AWAITING_DEPOSIT'), DateState.awaitingDeposit);
      expect(
        dateStateFromWire('AWAITING_PRESENCE_CONFIRMATION'),
        DateState.awaitingPresenceConfirmation,
      );
      expect(dateStateFromWire('MATCH'), isNull);
      expect(dateStateFromWire(null), isNull);
    });
  });
}
