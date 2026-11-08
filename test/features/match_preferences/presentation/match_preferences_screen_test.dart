import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_banner_store.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_filter.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_banner_providers.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/match_preferences_screen.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_match_preferences_api.dart';

const _preferencesPath = 'GET /users/me/match-preferences';
const _optionsPath = 'GET /match-preferences/options';

const _banner = 'Only people who fit a dealbreaker are shown. Everything else just decides who '
    'you see first.';

Map<String, dynamic> _preferences() =>
    mpFixture('get_users_me_match_preferences') as Map<String, dynamic>;

Map<String, dynamic> _options() => mpFixture('get_match_preferences_options') as Map<String, dynamic>;

FakeMatchPreferencesApi _api({Map<String, dynamic>? preferences, Map<String, dynamic>? options}) {
  return FakeMatchPreferencesApi(responses: {
    _preferencesPath: preferences ?? _preferences(),
    _optionsPath: options ?? _options(),
  });
}

/// The fixture with [filter]'s JSON replaced by [json].
Map<String, dynamic> _with(String filter, Map<String, dynamic> json) =>
    _preferences()..[filter] = json;

/// Pumps the hub in a fresh [ProviderScope], as a new app launch would, signed in as [uid].
Future<void> _pump(
  WidgetTester tester,
  FakeMatchPreferencesApi api, {
  required SharedPreferences prefs,
  String? uid = 'alice',
}) async {
  // Tall enough for every row, so none needs scrolling to.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    // A new key each time, so nothing is carried over from the previous pump.
    key: UniqueKey(),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      matchPreferencesBannerUidProvider.overrideWithValue(uid),
      matchPreferencesRepositoryProvider.overrideWithValue(
        MatchPreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
      ),
    ],
    child: const MaterialApp(home: MatchPreferencesScreen()),
  ));
  await tester.pumpAndSettle();
}

/// The row titled [title]: the button that opens its editor.
Finder _row(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(InkWell)).first;

/// The texts in [title]'s row, in order: its title, its summary and "Dealbreaker" if shown.
List<String?> _rowTexts(WidgetTester tester, String title) => tester
    .widgetList<Text>(find.descendant(of: _row(title), matching: find.byType(Text)))
    .map((t) => t.data)
    .toList();

String? _summaryOf(WidgetTester tester, String title) => _rowTexts(tester, title)[1];

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('MatchPreferencesScreen', () {
    testWidgets('lists every filter in RFC-007 §4.1\'s order', (tester) async {
      await _pump(tester, _api(), prefs: prefs);

      final titles = [
        'Interested in',
        'Age range',
        'Distance',
        'Height',
        'Ethnicity',
        'Religion',
        'Relationship type',
        'Dating intentions',
        'Kids',
        'Smoking',
        'Drinking',
      ];
      expect(MatchFilter.values.map((f) => f.label), titles);
      final tops = [for (final title in titles) tester.getTopLeft(find.text(title)).dy];
      expect(tops, [...tops]..sort());
    });

    testWidgets('shows each filter\'s summary from the fixture', (tester) async {
      await _pump(tester, _api(), prefs: prefs);

      expect(_summaryOf(tester, 'Interested in'), 'Women');
      expect(_summaryOf(tester, 'Age range'), '24–32');
      expect(_summaryOf(tester, 'Distance'), '5 mi from near Clapham');
      expect(_summaryOf(tester, 'Height'), 'Open to all');
      expect(_summaryOf(tester, 'Ethnicity'), 'Open to all');
      expect(_summaryOf(tester, 'Religion'), 'Open to all');
      expect(_summaryOf(tester, 'Relationship type'), 'Monogamous');
      expect(_summaryOf(tester, 'Dating intentions'), 'Serious Dating, Not Sure');
      expect(_summaryOf(tester, 'Kids'), 'Open to all');
      expect(_summaryOf(tester, 'Smoking'), 'Never, Quitting');
      expect(_summaryOf(tester, 'Drinking'), 'Open to all');
    });

    testWidgets('marks the dealbreakers, and only them', (tester) async {
      await _pump(tester, _api(), prefs: prefs);

      const dealbreakers = ['Interested in', 'Age range', 'Relationship type', 'Smoking'];
      for (final filter in MatchFilter.values) {
        final texts = _rowTexts(tester, filter.label);
        expect(
          texts.contains('Dealbreaker'),
          dealbreakers.contains(filter.label),
          reason: filter.label,
        );
      }
      expect(find.text('Dealbreaker'), findsNWidgets(dealbreakers.length));
    });

    testWidgets('reads each row as one button with its summary and marker', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _api(), prefs: prefs);

      expect(
        find.bySemanticsLabel('Smoking, Never, Quitting, Dealbreaker'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Drinking, Open to all'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('lists several values in the profile\'s order, whatever order they come in',
        (tester) async {
      await _pump(
        tester,
        _api(
          preferences: _with('alcoholConsumption', {
            'values': ['REGULARLY', 'NEVER'],
            'dealbreaker': false,
          }),
        ),
        prefs: prefs,
      );

      expect(_summaryOf(tester, 'Drinking'), 'Never, Regularly');
      expect(_rowTexts(tester, 'Drinking'), isNot(contains('Dealbreaker')));
    });

    testWidgets('names several genders, or everyone when all are ticked', (tester) async {
      await _pump(
        tester,
        _api(
          preferences: _with('gender', {
            'values': ['NON_BINARY', 'FEMALE'],
            'dealbreaker': true,
          }),
        ),
        prefs: prefs,
      );
      expect(_summaryOf(tester, 'Interested in'), 'Women, Non-binary people');

      await _pump(
        tester,
        _api(preferences: _with('gender', {'values': null, 'dealbreaker': true})),
        prefs: prefs,
      );
      expect(_summaryOf(tester, 'Interested in'), 'Everyone');
    });

    testWidgets('says Interested in isn\'t set before the user has answered', (tester) async {
      await _pump(
        tester,
        _api(
          preferences:
              mpFixture('get_users_me_match_preferences_defaults') as Map<String, dynamic>,
        ),
        prefs: prefs,
      );

      expect(_summaryOf(tester, 'Interested in'), 'Not set yet');
      expect(_summaryOf(tester, 'Distance'), 'Anywhere');
      expect(_summaryOf(tester, 'Drinking'), 'Open to all');
    });

    testWidgets('shows the top of the age range as 99+', (tester) async {
      await _pump(
        tester,
        _api(preferences: _with('age', {'min': 30, 'max': 99, 'dealbreaker': false})),
        prefs: prefs,
      );

      expect(_summaryOf(tester, 'Age range'), '30–99+');
      expect(_rowTexts(tester, 'Age range'), isNot(contains('Dealbreaker')));
    });

    group('height', () {
      Future<void> pumpHeight(WidgetTester tester, int? minCm, int? maxCm) => _pump(
            tester,
            _api(
              preferences:
                  _with('height', {'minCm': minCm, 'maxCm': maxCm, 'dealbreaker': true}),
            ),
            prefs: prefs,
          );

      testWidgets('shows a range in centimetres', (tester) async {
        await pumpHeight(tester, 160, 185);
        expect(_summaryOf(tester, 'Height'), '160–185 cm');
        expect(_rowTexts(tester, 'Height'), contains('Dealbreaker'));
      });

      testWidgets('reads the bottom of the slider as "or less"', (tester) async {
        await pumpHeight(tester, 120, 185);
        expect(_summaryOf(tester, 'Height'), 'Up to 185 cm');
      });

      testWidgets('reads the top of the slider as "or more"', (tester) async {
        await pumpHeight(tester, 160, 220);
        expect(_summaryOf(tester, 'Height'), '160 cm or more');
      });

      testWidgets('reads both ends of the slider as open to all', (tester) async {
        await pumpHeight(tester, 120, 220);
        expect(_summaryOf(tester, 'Height'), 'Open to all');
      });
    });

    group('distance', () {
      testWidgets('leaves out "from" when the server names no district', (tester) async {
        final options = _options();
        (options['distance'] as Map<String, dynamic>)['from'] = null;
        await _pump(tester, _api(options: options), prefs: prefs);

        expect(_summaryOf(tester, 'Distance'), 'Up to 5 mi');
      });

      testWidgets('uses the city\'s unit', (tester) async {
        final options = _options();
        (options['distance'] as Map<String, dynamic>)
          ..['unit'] = 'KM'
          ..['stopsMeters'] = [2000, 5000, 10000];
        await _pump(
          tester,
          _api(
            preferences: _with('distance', {'maxMeters': 5000, 'dealbreaker': true}),
            options: options,
          ),
          prefs: prefs,
        );

        expect(_summaryOf(tester, 'Distance'), '5 km from near Clapham');
        expect(_rowTexts(tester, 'Distance'), contains('Dealbreaker'));
      });

      testWidgets('reads MI as miles', (tester) async {
        final options = _options();
        (options['distance'] as Map<String, dynamic>)['unit'] = 'MI';
        await _pump(
          tester,
          _api(
            preferences: _with('distance', {'maxMeters': 1609, 'dealbreaker': false}),
            options: options,
          ),
          prefs: prefs,
        );

        expect(_summaryOf(tester, 'Distance'), '1 mi from near Clapham');
      });

      testWidgets('shows Anywhere with no limit', (tester) async {
        await _pump(
          tester,
          _api(preferences: _with('distance', {'maxMeters': null, 'dealbreaker': false})),
          prefs: prefs,
        );

        expect(_summaryOf(tester, 'Distance'), 'Anywhere');
      });
    });

    testWidgets('has no locks and no counts', (tester) async {
      await _pump(tester, _api(), prefs: prefs);

      expect(find.byIcon(Icons.lock), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      // Nothing on the screen is a number of people (D-16): the only digits are the fixture's
      // age range and distance.
      final digits = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((text) => text.contains(RegExp('[0-9]')))
          .toList();
      expect(digits, unorderedEquals(['24–32', '5 mi from near Clapham']));
    });

    group('each row', () {
      for (final filter in MatchFilter.values) {
        testWidgets('opens ${filter.label}\'s editor', (tester) async {
          await _pump(tester, _api(), prefs: prefs);

          await tester.tap(_row(filter.label));
          await tester.pumpAndSettle();

          // Interested in is MP-F2's screen, with Continue; every other editor saves with Save.
          expect(find.byType(MatchPreferencesScreen), findsNothing);
          expect(find.text(filter == MatchFilter.gender ? 'Continue' : 'Save'), findsOneWidget);

          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          expect(find.byType(MatchPreferencesScreen), findsOneWidget);
        });
      }
    });

    group('the dealbreakers banner', () {
      testWidgets('shows until it is dismissed, and then never again', (tester) async {
        await _pump(tester, _api(), prefs: prefs);
        expect(find.text(_banner), findsOneWidget);

        // Opening the screen again doesn't hide it: only dismissing does.
        await _pump(tester, _api(), prefs: prefs);
        expect(find.text(_banner), findsOneWidget);

        await tester.tap(find.byTooltip('Dismiss'));
        await tester.pumpAndSettle();
        expect(find.text(_banner), findsNothing);
        expect(prefs.getBool(MatchPreferencesBannerStore.dismissedKey('alice')), isTrue);

        // A new launch remembers it.
        await _pump(tester, _api(), prefs: prefs);
        expect(find.text(_banner), findsNothing);
        expect(find.text('Interested in'), findsOneWidget);
      });

      testWidgets('is remembered per user', (tester) async {
        await _pump(tester, _api(), prefs: prefs);
        await tester.tap(find.byTooltip('Dismiss'));
        await tester.pumpAndSettle();

        await _pump(tester, _api(), prefs: prefs, uid: 'bob');
        expect(find.text(_banner), findsOneWidget);
      });

      testWidgets('isn\'t shown when nobody is signed in', (tester) async {
        await _pump(tester, _api(), prefs: prefs, uid: null);
        expect(find.text(_banner), findsNothing);
      });
    });

    testWidgets('shows an error with a retry when loading fails', (tester) async {
      final api = _api()..error = const NetworkException('offline');
      await _pump(tester, api, prefs: prefs);

      expect(
        find.text('Unable to connect to the server. Please check your internet connection and try '
            'again.'),
        findsOneWidget,
      );
      expect(find.text('Interested in'), findsNothing);

      api.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Interested in'), findsOneWidget);
      expect(_summaryOf(tester, 'Interested in'), 'Women');
    });
  });
}
