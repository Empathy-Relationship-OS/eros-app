import 'package:eros_app/core/auth/sign_out_service.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_prompt_store.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/domain/models/section_patch.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preferences_prompt_providers.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preferences_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/date_preferences_screen.dart';
import 'package:eros_app/features/date_preferences/presentation/widgets/date_preferences_prompts.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/venue_ranking_provider.dart';
import 'package:eros_app/features/dates/presentation/screens/venue_ranking_screen.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_date_preferences_api.dart';

const _preferencesPath = 'GET /users/me/date-preferences';
const _savePath = 'PATCH /users/me/date-preferences';
const _optionsPath = 'GET /date-preferences/options';

const _sheetTitle = 'Set your date preferences?';
const _cardTitle = 'Tell us what dates you like';

FakeDatePreferencesApi _api({required bool isSet}) {
  return FakeDatePreferencesApi(responses: {
    _preferencesPath: dpFixture(
      isSet ? 'get_users_me_date_preferences' : 'get_users_me_date_preferences_defaults',
    ) as Map<String, dynamic>,
    _savePath: dpFixture('get_users_me_date_preferences') as Map<String, dynamic>,
    _optionsPath: dpFixture('get_date_preferences_options_london') as Map<String, dynamic>,
  });
}

int _count(FakeDatePreferencesApi api, String request) =>
    api.requests.where((r) => '${r.method} ${r.path}' == request).length;

/// Pumps [home] in a fresh [ProviderScope], as a new app launch would, signed in as [uid].
Future<void> _pump(
  WidgetTester tester, {
  required Widget home,
  required SharedPreferences prefs,
  required FakeDatePreferencesApi api,
  String? uid = 'alice',
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(ProviderScope(
    // A new key each time, so nothing is carried over from the previous pump.
    key: UniqueKey(),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      datePreferencesPromptUidProvider.overrideWithValue(uid),
      datePreferencesRepositoryProvider.overrideWithValue(
        DatePreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
      ),
      ...overrides,
    ],
    child: MaterialApp(home: home),
  ));
  await tester.pumpAndSettle();
}

const _home = DatePreferencesFirstRunSheet(child: Scaffold(body: Text('Home')));

const _datesTab = Scaffold(body: Column(children: [DatePreferencesPromptCard(), Text('Dates')]));

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('DatePreferencesFirstRunSheet', () {
    testWidgets('asks once per user when preferences aren\'t set', (tester) async {
      final api = _api(isSet: false);
      await _pump(tester, home: _home, prefs: prefs, api: api);

      expect(find.text(_sheetTitle), findsOneWidget);
      expect(find.text('It takes about a minute.'), findsOneWidget);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text(_sheetTitle), findsNothing);
      expect(find.text('Home'), findsOneWidget);

      // The next launch for the same user doesn't ask again, or fetch preferences for it.
      final again = _api(isSet: false);
      await _pump(tester, home: _home, prefs: prefs, api: again);
      expect(find.text(_sheetTitle), findsNothing);
      expect(_count(again, _preferencesPath), 0);

      // Another user on the same device is asked.
      await _pump(tester, home: _home, prefs: prefs, api: _api(isSet: false), uid: 'bob');
      expect(find.text(_sheetTitle), findsOneWidget);
    });

    testWidgets('counts as shown when dismissed without choosing', (tester) async {
      await _pump(tester, home: _home, prefs: prefs, api: _api(isSet: false));
      expect(find.text(_sheetTitle), findsOneWidget);

      await tester.tapAt(const Offset(10, 10)); // the barrier
      await tester.pumpAndSettle();
      expect(find.text(_sheetTitle), findsNothing);

      await _pump(tester, home: _home, prefs: prefs, api: _api(isSet: false));
      expect(find.text(_sheetTitle), findsNothing);
    });

    testWidgets('doesn\'t ask when preferences are already set', (tester) async {
      await _pump(tester, home: _home, prefs: prefs, api: _api(isSet: true));

      expect(find.text(_sheetTitle), findsNothing);
      expect(DatePreferencesPromptStore(prefs).hasShownSheet('alice'), isTrue);
    });

    testWidgets('"Set them now" opens the hub', (tester) async {
      await _pump(tester, home: _home, prefs: prefs, api: _api(isSet: false));

      await tester.tap(find.text('Set them now'));
      await tester.pumpAndSettle();

      expect(find.text(_sheetTitle), findsNothing);
      expect(find.byType(DatePreferencesScreen), findsOneWidget);
    });

    testWidgets('asks next time when the preferences fail to load', (tester) async {
      final api = _api(isSet: false)..error = const NetworkException('offline');
      await _pump(tester, home: _home, prefs: prefs, api: api);

      expect(find.text(_sheetTitle), findsNothing);
      expect(DatePreferencesPromptStore(prefs).hasShownSheet('alice'), isFalse);

      await _pump(tester, home: _home, prefs: prefs, api: _api(isSet: false));
      expect(find.text(_sheetTitle), findsOneWidget);
    });

    testWidgets('does nothing when nobody is signed in', (tester) async {
      final api = _api(isSet: false);
      await _pump(tester, home: _home, prefs: prefs, api: api, uid: null);

      expect(find.text(_sheetTitle), findsNothing);
      expect(api.requests, isEmpty);
    });
  });

  group('DatePreferencesPromptCard', () {
    testWidgets('shows while preferences aren\'t set and opens the hub', (tester) async {
      await _pump(tester, home: _datesTab, prefs: prefs, api: _api(isSet: false));

      expect(find.text(_cardTitle), findsOneWidget);
      await tester.tap(find.text(_cardTitle));
      await tester.pumpAndSettle();
      expect(find.byType(DatePreferencesScreen), findsOneWidget);
    });

    testWidgets('isn\'t shown when preferences are set', (tester) async {
      await _pump(tester, home: _datesTab, prefs: prefs, api: _api(isSet: true));

      expect(find.text(_cardTitle), findsNothing);
    });

    testWidgets('hides after the user saves from the hub', (tester) async {
      await _pump(tester, home: _datesTab, prefs: prefs, api: _api(isSet: false));
      await tester.tap(find.text(_cardTitle));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(DatePreferencesScreen)));
      await container.read(datePreferencesProvider.notifier).saveSection(const ActivitiesPatch([]));
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Dates'), findsOneWidget);
      expect(find.text(_cardTitle), findsNothing);
    });

    testWidgets('hides when dismissed, for that user only', (tester) async {
      await _pump(tester, home: _datesTab, prefs: prefs, api: _api(isSet: false));

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.text(_cardTitle), findsNothing);
      expect(find.byType(DatePreferencesScreen), findsNothing);

      await _pump(tester, home: _datesTab, prefs: prefs, api: _api(isSet: false));
      expect(find.text(_cardTitle), findsNothing);

      await _pump(tester, home: _datesTab, prefs: prefs, api: _api(isSet: false), uid: 'bob');
      expect(find.text(_cardTitle), findsOneWidget);
    });
  });

  group('venue ranking screen', () {
    testWidgets('links to the hub under the options', (tester) async {
      await _pump(
        tester,
        home: const VenueRankingScreen(dateId: '7'),
        prefs: prefs,
        api: _api(isSet: true),
        overrides: [
          venueOptionsProvider('7').overrideWith((ref) async => const VenueOptions(
                dateId: 7,
                options: [
                  VenueOption(
                    venueId: 1,
                    name: 'The Ivy',
                    address: '1 West St',
                    optionOrder: 1,
                    priceRange: PriceRange(value: 'PREMIUM', symbol: '£££'),
                  ),
                  VenueOption(
                    venueId: 2,
                    name: 'Bao',
                    address: '2 Lexington St',
                    optionOrder: 2,
                    priceRange: PriceRange(value: 'MID_RANGE', symbol: '££'),
                  ),
                ],
                myRankings: [],
              )),
        ],
      );

      const link = 'Not your kind of place? Update your preferences for next time';
      expect(find.text(link), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(link)).dy,
        greaterThan(tester.getBottomLeft(find.text('Bao')).dy),
      );

      await tester.tap(find.text(link));
      await tester.pumpAndSettle();
      expect(find.byType(DatePreferencesScreen), findsOneWidget);
    });
  });

  test('sign-out clears what the prompts remember', () async {
    final store = DatePreferencesPromptStore(prefs);
    await store.markSheetShown('alice');
    await store.dismissCard('alice');

    await SignOutService(
      firebaseAuth: _FakeFirebaseAuth(),
      sharedPrefs: prefs,
      logger: Logger(level: Level.off),
    ).signOut();

    expect(store.hasShownSheet('alice'), isFalse);
    expect(store.isCardDismissed('alice'), isFalse);
  });
}
