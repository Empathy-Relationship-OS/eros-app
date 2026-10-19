import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/devtools/data/devtools_api.dart';
import 'package:eros_app/features/devtools/data/persona_session_service.dart';
import 'package:eros_app/features/devtools/presentation/providers/devtools_providers.dart';
import 'package:eros_app/features/devtools/presentation/tabs/personas_tab.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import '../fake_devtools_api.dart';

class _FakeSessionService implements PersonaSessionService {
  final List<String> signedInAs = [];
  Future<void> Function(String uid)? onSignIn;

  @override
  Future<void> signInAs(String uid) async {
    signedInAs.add(uid);
    await onSignIn?.call(uid);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _homeMarker = 'AUTH LOADING SCREEN';

void main() {
  late FakeDevtoolsApi api;
  late _FakeSessionService session;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    api = FakeDevtoolsApi(personas: standardCast());
    session = _FakeSessionService();
  });

  /// The tab on a route above a stand-in for `AuthLoadingScreen` at '/'.
  Future<void> pumpTab(WidgetTester tester, {String? signedInUid}) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          devtoolsApiProvider.overrideWithValue(api),
          sharedPreferencesProvider.overrideWithValue(prefs),
          devtoolsSignedInUidProvider.overrideWithValue(signedInUid),
          personaSessionServiceProvider.overrideWithValue(session),
        ],
        child: MaterialApp(
          home: const Scaffold(body: Text(_homeMarker)),
          initialRoute: '/personas',
          routes: {'/personas': (_) => const Scaffold(body: PersonasTab())},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String uid) => find.byKey(ValueKey('persona-$uid'));

  Finder logInAs(String uid) =>
      find.descendant(of: row(uid), matching: find.text('Log in as'));

  group('persona list', () {
    testWidgets('renders each persona with name, uid, role and tokens', (
      tester,
    ) async {
      await pumpTab(tester);

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('dev_alice | USER | 100 tokens'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Ops'), findsOneWidget);
      expect(find.text('dev_ops | ADMIN | 0 tokens'), findsOneWidget);
      expect(find.text('Log in as'), findsNWidgets(3));
      expect(find.byTooltip('Delete dev_bob'), findsOneWidget);
    });

    testWidgets('shows the backend message when the list fails', (
      tester,
    ) async {
      api.listError = const UnauthorizedException('Wrong or missing X-Dev-Key');
      await pumpTab(tester);

      expect(
        find.text('Could not load personas: Wrong or missing X-Dev-Key'),
        findsOneWidget,
      );
    });

    testWidgets('pull to refresh reloads the list', (tester) async {
      await pumpTab(tester);
      api.personas = [...api.personas.take(1)];

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(api.calls.where((c) => c == 'listPersonas'), hasLength(2));
      expect(find.text('Bob'), findsNothing);
    });

    testWidgets('create standard cast calls the backend and refreshes', (
      tester,
    ) async {
      api.personas = [];
      await pumpTab(tester);
      expect(find.textContaining('No personas yet'), findsOneWidget);

      await tester.tap(find.text('Create standard cast'));
      await tester.pumpAndSettle();

      expect(api.calls, contains('createStandardPersonas'));
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Standard cast ready: 3 personas'), findsOneWidget);
    });
  });

  group('signed in header', () {
    testWidgets('shows the uid and a dev persona chip for dev_ users', (
      tester,
    ) async {
      await pumpTab(tester, signedInUid: 'dev_alice');

      expect(find.text('Currently signed in as dev_alice'), findsOneWidget);
      expect(find.text('dev persona'), findsOneWidget);
      expect(find.text('Alice (signed in)'), findsOneWidget);
    });

    testWidgets('has no chip for a real user', (tester) async {
      await pumpTab(tester, signedInUid: 'firebase-uid-123');

      expect(
        find.text('Currently signed in as firebase-uid-123'),
        findsOneWidget,
      );
      expect(find.text('dev persona'), findsNothing);
    });

    testWidgets('says signed out when nobody is signed in', (tester) async {
      await pumpTab(tester);

      expect(find.text('Currently signed out'), findsOneWidget);
    });
  });

  group('log in as', () {
    testWidgets('signs in through the session service and restarts at /', (
      tester,
    ) async {
      await pumpTab(tester, signedInUid: 'dev_alice');

      await tester.tap(logInAs('dev_bob'));
      await tester.pumpAndSettle();

      expect(session.signedInAs, ['dev_bob']);
      expect(find.byType(PersonasTab), findsNothing);
      expect(find.text(_homeMarker), findsOneWidget);
    });

    testWidgets('shows a loading state on the row being signed into', (
      tester,
    ) async {
      final pending = Completer<void>();
      session.onSignIn = (_) => pending.future;
      await pumpTab(tester);

      await tester.tap(logInAs('dev_bob'));
      await tester.pump();

      expect(
        find.descendant(
          of: row('dev_bob'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(logInAs('dev_bob'), findsNothing);
      final alice = tester.widget<TextButton>(
        find.ancestor(
          of: logInAs('dev_alice'),
          matching: find.byType(TextButton),
        ),
      );
      expect(alice.onPressed, isNull);

      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text(_homeMarker), findsOneWidget);
    });

    testWidgets('shows the backend message and stays put when it fails', (
      tester,
    ) async {
      session.onSignIn = (uid) async =>
          throw NotFoundException('No persona $uid');
      await pumpTab(tester);

      await tester.tap(logInAs('dev_bob'));
      await tester.pumpAndSettle();

      expect(find.text('No persona dev_bob'), findsOneWidget);
      expect(find.byType(PersonasTab), findsOneWidget);
      expect(logInAs('dev_bob'), findsOneWidget);
    });

    testWidgets('says you are signed out when sign-in failed after sign-out', (
      tester,
    ) async {
      session.onSignIn = (uid) async => throw const PersonaSwitchException(
        'Signed out, but signing in as dev_bob failed: Bad token',
        signedOut: true,
      );
      await pumpTab(tester);

      await tester.tap(logInAs('dev_bob'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Signed out, but signing in as dev_bob failed: Bad token. '
          'You are now signed out.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('recent personas are listed and can be signed into', (
      tester,
    ) async {
      await RecentPersonasStore(prefs).record('dev_cara');
      await RecentPersonasStore(prefs).record('dev_bob');
      await pumpTab(tester);

      expect(find.text('Recent'), findsOneWidget);
      final bob = find.byKey(const ValueKey('recentPersona-dev_bob'));
      expect(bob, findsOneWidget);
      expect(
        find.byKey(const ValueKey('recentPersona-dev_cara')),
        findsOneWidget,
      );

      await tester.tap(bob);
      await tester.pumpAndSettle();

      expect(session.signedInAs, ['dev_bob']);
    });

    testWidgets('no recent row before any switch', (tester) async {
      await pumpTab(tester);

      expect(find.text('Recent'), findsNothing);
    });
  });

  group('create persona form', () {
    Future<void> openForm(WidgetTester tester) async {
      await tester.tap(find.text('Create persona'));
      await tester.pumpAndSettle();
      expect(find.byType(CreatePersonaDialog), findsOneWidget);
    }

    Future<void> submit(WidgetTester tester, String handle) async {
      await tester.enterText(
        find.byKey(const Key('createPersonaHandle')),
        handle,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();
    }

    testWidgets('rejects an empty or invalid handle', (tester) async {
      await pumpTab(tester);
      await openForm(tester);

      await submit(tester, '');
      expect(find.text('Handle is required'), findsOneWidget);

      for (final bad in ['a', 'Zoe', 'zoe-1', 'zo e', 'x' * 33]) {
        await submit(tester, bad);
        expect(
          find.text('Use 2 to 32 of a-z, 0-9 and _'),
          findsOneWidget,
          reason: '"$bad" should be rejected',
        );
      }

      expect(find.byType(CreatePersonaDialog), findsOneWidget);
      expect(api.calls.where((c) => c.startsWith('createPersona')), isEmpty);
    });

    testWidgets('creates a persona from a valid form', (tester) async {
      await pumpTab(tester);
      await openForm(tester);

      await tester.tap(find.byKey(const Key('createPersonaRole')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ADMIN').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('createPersonaTokens')),
        '250',
      );
      await submit(tester, 'zoe_2');

      expect(find.byType(CreatePersonaDialog), findsNothing);
      expect(api.calls, contains('createPersona:zoe_2'));
      expect(find.text('dev_zoe_2 | ADMIN | 250 tokens'), findsOneWidget);
      expect(find.text('Persona ready: dev_zoe_2'), findsOneWidget);
    });

    testWidgets('cancel sends nothing', (tester) async {
      await pumpTab(tester);
      await openForm(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(CreatePersonaDialog), findsNothing);
      expect(api.calls.where((c) => c.startsWith('createPersona')), isEmpty);
    });

    test('validatePersonaHandle', () {
      expect(validatePersonaHandle('al'), isNull);
      expect(validatePersonaHandle('alice_2'), isNull);
      expect(validatePersonaHandle('x' * 32), isNull);
      expect(validatePersonaHandle('x' * 33), isNotNull);
      expect(validatePersonaHandle('dev-alice'), isNotNull);
      expect(validatePersonaHandle(null), 'Handle is required');
    });
  });

  group('delete', () {
    testWidgets('asks for confirmation before deleting', (tester) async {
      await pumpTab(tester);

      await tester.tap(find.byTooltip('Delete dev_alice'));
      await tester.pumpAndSettle();
      expect(find.text('Delete dev_alice?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c.startsWith('deletePersona')), isEmpty);
      expect(row('dev_alice'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete dev_alice'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(api.calls, contains('deletePersona:dev_alice'));
      expect(row('dev_alice'), findsNothing);
      expect(find.text('Deleted dev_alice'), findsOneWidget);
    });

    testWidgets('removes the persona from the recent list', (tester) async {
      await RecentPersonasStore(prefs).record('dev_alice');
      await pumpTab(tester);
      expect(
        find.byKey(const ValueKey('recentPersona-dev_alice')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Delete dev_alice'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('recentPersona-dev_alice')),
        findsNothing,
      );
      expect(RecentPersonasStore(prefs).read(), isEmpty);
    });

    testWidgets('says delete is not available on a 404', (tester) async {
      api.deleteError = const NotFoundException('Resource not found');
      await pumpTab(tester);

      await tester.tap(find.byTooltip('Delete dev_bob'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text(deleteUnavailableMessage), findsOneWidget);
      expect(row('dev_bob'), findsOneWidget);
    });
  });
}
