import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/features/auth/data/repositories/auth_repository.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/legal/data/support_email.dart';
import 'package:eros_app/features/legal/presentation/screens/privacy_settings_screen.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../verification/fake_verification_http.dart' show FakeAuthService;
import '../fake_legal_server.dart';

class _FakeUser implements User {
  @override
  String get uid => 'fixture-user';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Signed in; records sign-outs and never touches Firebase.
class _FakeAuthRepository implements AuthRepository {
  int signOuts = 0;

  @override
  User? get currentUser => _FakeUser();

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<void> signOut() async => signOuts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLinks implements LegalLinks {
  final List<Uri> documents = [];
  final List<Uri> emails = [];

  @override
  Future<bool> openDocument(Uri url) async {
    documents.add(url);
    return true;
  }

  @override
  Future<bool> openEmail(Uri email) async {
    emails.add(email);
    return true;
  }
}

const _welcomeMarker = 'WELCOME SCREEN';

class _Harness {
  _Harness([FakeLegalServer? server]) : server = server ?? FakeLegalServer();

  final FakeLegalServer server;
  final _FakeAuthRepository auth = _FakeAuthRepository();
  final _FakeLinks links = _FakeLinks();

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWith((ref) => apiClientOverLegal(server)),
          authServiceProvider.overrideWithValue(FakeAuthService()),
          authStateProvider.overrideWith((ref) => AuthStateNotifier(auth)),
          legalLinksProvider.overrideWithValue(links),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PrivacySettingsScreen(),
          routes: {'/welcome': (_) => const Scaffold(body: Text(_welcomeMarker))},
        ),
      ),
    );
    await settle(tester);
  }
}

/// Lets the fake's answers and the screen's futures finish. Never `pumpAndSettle`: spinners
/// never settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

bool _switchValue(WidgetTester tester, String kind) =>
    tester.widget<SwitchListTile>(find.byKey(ValueKey('choice-$kind'))).value;

void main() {
  group('loading', () {
    testWidgets("asks for the documents of the user's city region", (tester) async {
      final h = _Harness();
      await h.pump(tester);

      // The profile's "London" matches city 1, "london", case-insensitively.
      expect(h.server.sent('GET', documentsPath).single.query, {'cityId': '1'});
      expect(h.server.sent('GET', consentsPath), hasLength(1));
    });

    testWidgets('falls back to the ALL region when no city matches', (tester) async {
      final h = _Harness(FakeLegalServer(city: 'Atlantis'));
      await h.pump(tester);

      expect(h.server.sent('GET', documentsPath).single.query, isEmpty);
    });

    testWidgets('lists each document and opens its URL', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      expect(find.text('Terms of use'), findsOneWidget);
      expect(find.text('Privacy notice'), findsOneWidget);
      expect(find.text('Safety notice'), findsOneWidget);
      expect(find.text('New York Dating Bill of Rights'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('document-TERMS')));
      await settle(tester);

      expect(h.links.documents, [Uri.parse('https://meetmymuse.com/terms')]);
    });
  });

  group('switches', () {
    testWidgets('reflect the server state', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      expect(_switchValue(tester, 'MARKETING'), isTrue);
      expect(_switchValue(tester, 'LOCATION_PIN'), isFalse);
      expect(find.text(PrivacySettingsCopy.sensitiveDataOn), findsOneWidget);
    });

    testWidgets('post the change with the version shown, then refetch', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(find.byKey(const ValueKey('choice-LOCATION_PIN')));
      await settle(tester);

      expect(h.server.sent('POST', consentsPath).single.body, {
        'consents': [
          {'kind': 'LOCATION_PIN', 'version': 'p-2', 'granted': true},
        ],
        'source': 'SETTINGS',
      });
      expect(h.server.sent('GET', consentsPath), hasLength(2), reason: 'refetched after the change');
      expect(_switchValue(tester, 'LOCATION_PIN'), isTrue);

      await tester.tap(find.byKey(const ValueKey('choice-MARKETING')));
      await settle(tester);

      expect((h.server.sent('POST', consentsPath).last.body! as Map)['consents'], [
        {'kind': 'MARKETING', 'version': 'm-1', 'granted': false},
      ]);
      expect(_switchValue(tester, 'MARKETING'), isFalse);
    });

    testWidgets('is off with no current document to consent to', (tester) async {
      final h = _Harness(FakeLegalServer(documents: [documentJson('TERMS')]));
      await h.pump(tester);

      final tile = tester.widget<SwitchListTile>(find.byKey(const ValueKey('choice-MARKETING')));
      expect(tile.onChanged, isNull);
      expect(find.text(PrivacySettingsCopy.notAvailableYet), findsNWidgets(3));
    });

    testWidgets('a stale version says so and reloads the documents', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      h.server.nextConsentRefusal = (
        status: 400,
        body: {
          'error': 'CONSENT_VERSION_STALE',
          'message': 'A newer version is available',
          'kinds': ['MARKETING'],
        },
      );

      await tester.tap(find.byKey(const ValueKey('choice-MARKETING')));
      await settle(tester);

      expect(find.text(PrivacySettingsCopy.choiceStale), findsOneWidget);
      expect(h.server.sent('GET', documentsPath), hasLength(2));
      expect(_switchValue(tester, 'MARKETING'), isTrue, reason: 'the server state is unchanged');
    });
  });

  group('sensitive data', () {
    testWidgets('asks first, and cancelling sends nothing', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(find.byKey(const ValueKey('choice-SENSITIVE_DATA')));
      await settle(tester);

      expect(find.text(PrivacySettingsCopy.sensitiveDataOffBody), findsOneWidget);

      await tester.tap(find.text(PrivacySettingsCopy.cancel));
      await settle(tester);

      expect(h.server.sent('POST', consentsPath), isEmpty);
      expect(find.text(PrivacySettingsCopy.sensitiveDataOn), findsOneWidget);
    });

    testWidgets('withdraws on confirm and says orientation was kept, with a way to delete',
        (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(find.byKey(const ValueKey('choice-SENSITIVE_DATA')));
      await settle(tester);
      await tester.tap(find.text(PrivacySettingsCopy.sensitiveDataOffConfirm));
      await settle(tester);

      expect((h.server.sent('POST', consentsPath).single.body! as Map)['consents'], [
        {'kind': 'SENSITIVE_DATA', 'version': 's-3', 'granted': false},
      ]);
      expect(find.byKey(const ValueKey('orientation-retained')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('orientation-retained')),
          matching: find.text(PrivacySettingsCopy.sensitiveDataOffBody),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(PrivacySettingsCopy.deleteAccountLink));
      await settle(tester);

      expect(find.text(PrivacySettingsCopy.deleteAccountConfirmBody), findsOneWidget);
      expect(h.server.sent('DELETE', usersMePath), isEmpty, reason: 'delete still asks first');
    });

    testWidgets('closing the retained message leaves sensitive data off', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(find.byKey(const ValueKey('choice-SENSITIVE_DATA')));
      await settle(tester);
      await tester.tap(find.text(PrivacySettingsCopy.sensitiveDataOffConfirm));
      await settle(tester);
      await tester.tap(find.text(PrivacySettingsCopy.close));
      await settle(tester);

      expect(find.text(PrivacySettingsCopy.sensitiveDataOff), findsOneWidget);
      expect(h.server.sent('GET', consentsPath), hasLength(2));
    });

    testWidgets('turning it back on asks first, then grants', (tester) async {
      final h = _Harness(FakeLegalServer(granted: {'SENSITIVE_DATA': false}));
      await h.pump(tester);

      await tester.tap(find.byKey(const ValueKey('choice-SENSITIVE_DATA')));
      await settle(tester);
      expect(find.text(PrivacySettingsCopy.sensitiveDataOnBody), findsOneWidget);

      await tester.tap(find.text(PrivacySettingsCopy.sensitiveDataOnConfirm));
      await settle(tester);

      expect((h.server.sent('POST', consentsPath).single.body! as Map)['consents'], [
        {'kind': 'SENSITIVE_DATA', 'version': 's-3', 'granted': true},
      ]);
      expect(find.text(PrivacySettingsCopy.sensitiveDataOn), findsOneWidget);
      expect(find.byKey(const ValueKey('orientation-retained')), findsNothing);
    });
  });

  group('emails', () {
    testWidgets('"Request my data" carries its subject and the account id only', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(find.byKey(const ValueKey('request-data')));
      await settle(tester);

      final email = h.links.emails.single;
      expect(email.scheme, 'mailto');
      expect(email.queryParameters.keys, unorderedEquals(['subject', 'body']));
      expect(email.queryParameters['subject'], 'Data request');
      expect(email.queryParameters['body']!.trim(), 'Account id: fixture-user');
    });

    testWidgets('"Make a complaint" carries its subject and the account id only', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(find.byKey(const ValueKey('complaint')));
      await settle(tester);

      final email = h.links.emails.single;
      expect(email.queryParameters['subject'], 'Complaint');
      expect(email.queryParameters['body']!.trim(), 'Account id: fixture-user');
    });
  });

  group('delete account', () {
    testWidgets('asks first, and cancelling deletes nothing', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(find.byKey(const ValueKey('delete-account')));
      await settle(tester);

      expect(find.text(PrivacySettingsCopy.deleteAccountConfirmBody), findsOneWidget);

      await tester.tap(find.text(PrivacySettingsCopy.cancel));
      await settle(tester);

      expect(h.server.sent('DELETE', usersMePath), isEmpty);
      expect(h.auth.signOuts, 0);
    });

    testWidgets('on confirm closes the account, then signs out', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(find.byKey(const ValueKey('delete-account')));
      await settle(tester);
      await tester.tap(find.text(PrivacySettingsCopy.deleteAccountConfirm).last);
      await settle(tester);

      expect(h.server.sent('DELETE', usersMePath), hasLength(1));
      expect(h.auth.signOuts, 1);
      expect(find.text(_welcomeMarker), findsOneWidget);
    });

    testWidgets('a failed delete stays signed in and says so', (tester) async {
      final h = _Harness();
      h.server.deleteStatus = 404;
      await h.pump(tester);

      await tester.tap(find.byKey(const ValueKey('delete-account')));
      await settle(tester);
      await tester.tap(find.text(PrivacySettingsCopy.deleteAccountConfirm).last);
      await settle(tester);

      expect(h.auth.signOuts, 0);
      expect(find.text(PrivacySettingsCopy.deleteAccountFailed), findsOneWidget);
      expect(find.text(_welcomeMarker), findsNothing);
    });
  });
}
