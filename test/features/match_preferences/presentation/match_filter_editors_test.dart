import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_filter.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preference_options.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_banner_providers.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/edit_age_screen.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/edit_distance_screen.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/edit_height_screen.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/match_filter_editors.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/match_preferences_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../fake_match_preferences_api.dart';

const _preferencesPath = 'GET /users/me/match-preferences';
const _optionsPath = 'GET /match-preferences/options';
const _patchPath = 'PATCH /users/me/match-preferences';

const _preferenceSubtitle = 'We\'ll show you people who fit first';
const _dealbreakerSubtitle = 'We\'ll only show you people who fit';
const _switchHelp = 'Only show me people who fit. Fewer people will see you too.';

Map<String, dynamic> _preferences() =>
    mpFixture('get_users_me_match_preferences') as Map<String, dynamic>;

Map<String, dynamic> _options() => mpFixture('get_match_preferences_options') as Map<String, dynamic>;

/// The fixture with [filter]'s JSON replaced by [json].
Map<String, dynamic> _with(String filter, Map<String, dynamic> json) =>
    _preferences()..[filter] = json;

/// The server: answers GET with [preferences] and [options], and PATCH with [saved] (the fixture
/// by default), whatever was sent.
FakeMatchPreferencesApi _api({
  Map<String, dynamic>? preferences,
  Map<String, dynamic>? options,
  Map<String, dynamic>? saved,
}) {
  return FakeMatchPreferencesApi(responses: {
    _preferencesPath: preferences ?? _preferences(),
    _optionsPath: options ?? _options(),
    _patchPath: saved ?? _preferences(),
  });
}

/// The body of the only PATCH sent.
Map<String, dynamic> _patched(FakeMatchPreferencesApi api) {
  final patches = api.requests.where((r) => r.method == 'PATCH').toList();
  expect(patches, hasLength(1));
  return patches.single.data as Map<String, dynamic>;
}

/// Pumps the hub, then opens [filter]'s editor from its row.
Future<void> _open(WidgetTester tester, FakeMatchPreferencesApi api, MatchFilter filter) async {
  // Tall enough for every row and every value, so none needs scrolling to.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    // A new key each time, so nothing is carried over from the previous pump.
    key: UniqueKey(),
    overrides: [
      // The banner never shows, so it can't push rows around.
      matchPreferencesBannerUidProvider.overrideWithValue(null),
      matchPreferencesRepositoryProvider.overrideWithValue(
        MatchPreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
      ),
    ],
    child: const MaterialApp(home: MatchPreferencesScreen()),
  ));
  await tester.pumpAndSettle();

  await tester.tap(_row(filter.label));
  await tester.pumpAndSettle();
}

/// The hub row titled [title]: the button that opens its editor.
Finder _row(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(InkWell)).first;

String? _summaryOf(WidgetTester tester, String title) => tester
    .widgetList<Text>(find.descendant(of: _row(title), matching: find.byType(Text)))
    .map((t) => t.data)
    .elementAt(1);

/// Whether the option labelled [label] is ticked.
bool _isTicked(WidgetTester tester, String label) => tester
    .widget<CheckboxListTile>(find.ancestor(
      of: find.text(label),
      matching: find.byType(CheckboxListTile),
    ))
    .value!;

bool _switchValue(WidgetTester tester) =>
    tester.widget<SwitchListTile>(find.byKey(const Key('dealbreaker-switch'))).value;

String? _textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data;

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

/// The JSON key each filter is sent under.
String _keyOf(MatchFilter filter) => switch (filter) {
      MatchFilter.gender => 'gender',
      MatchFilter.age => 'age',
      MatchFilter.distance => 'distance',
      MatchFilter.height => 'height',
      MatchFilter.ethnicity => 'ethnicity',
      MatchFilter.religion => 'religion',
      MatchFilter.relationshipType => 'relationshipType',
      MatchFilter.dateIntentions => 'dateIntentions',
      MatchFilter.kidsPreference => 'kidsPreference',
      MatchFilter.smokingStatus => 'smokingStatus',
      MatchFilter.alcoholConsumption => 'alcoholConsumption',
    };

void main() {
  group('matchFilterEditor', () {
    testWidgets('opens each filter\'s editor', (tester) async {
      final api = _api();
      for (final filter in MatchFilter.values) {
        await _open(tester, api, filter);
        final expected = switch (filter) {
          MatchFilter.gender => '$InterestedInEditor',
          MatchFilter.age => '$EditAgeScreen',
          MatchFilter.distance => '$EditDistanceScreen',
          MatchFilter.height => '$EditHeightScreen',
          // Generic over the filter's enum, such as EditValueFilterScreen<Religion>.
          _ => 'EditValueFilterScreen<',
        };
        expect(
          find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith(expected)),
          findsOneWidget,
          reason: filter.label,
        );
        if (filter != MatchFilter.gender) expect(find.text(filter.label), findsOneWidget);
      }
    });

    group('each editor sends only its own key', () {
      for (final filter in MatchFilter.values) {
        testWidgets(filter.label, (tester) async {
          final api = _api();
          await _open(tester, api, filter);

          if (filter == MatchFilter.gender) {
            await tester.tap(find.text('Male'));
            await tester.pump();
            await tester.tap(find.text('Continue'));
          } else {
            await tester.tap(find.byKey(const Key('dealbreaker-switch')));
            await tester.pump();
            await tester.tap(find.text('Save'));
          }
          await tester.pumpAndSettle();

          expect(_patched(api).keys, [_keyOf(filter)]);
          // Saved and closed: back on the hub.
          expect(find.byType(MatchPreferencesScreen), findsOneWidget);
          expect(find.text('Save'), findsNothing);
        });
      }
    });
  });

  group('value list editors', () {
    testWidgets('show the profile labels without Prefer not to say, and Open to all', (tester) async {
      await _open(tester, _api(), MatchFilter.smokingStatus);

      for (final label in ['Open to all', 'Never', 'Sometimes', 'Regularly', 'Quitting']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Prefer not to say'), findsNothing);
      expect(_isTicked(tester, 'Never'), isTrue);
      expect(_isTicked(tester, 'Quitting'), isTrue);
      expect(_isTicked(tester, 'Open to all'), isFalse);
    });

    testWidgets('Open to all is ticked when nothing else is', (tester) async {
      await _open(tester, _api(), MatchFilter.religion);
      expect(_isTicked(tester, 'Open to all'), isTrue);

      await tester.tap(find.text('Islam'));
      await tester.pump();
      expect(_isTicked(tester, 'Open to all'), isFalse);

      await tester.tap(find.text('Islam'));
      await tester.pump();
      expect(_isTicked(tester, 'Open to all'), isTrue);
    });

    testWidgets('Open to all clears the list and saves as null', (tester) async {
      final api = _api();
      await _open(tester, api, MatchFilter.smokingStatus);

      await tester.tap(find.text('Open to all'));
      await tester.pump();
      expect(_isTicked(tester, 'Open to all'), isTrue);
      expect(_isTicked(tester, 'Never'), isFalse);
      expect(_isTicked(tester, 'Quitting'), isFalse);

      await _save(tester);
      expect(_patched(api), {
        'smokingStatus': {'values': null, 'dealbreaker': true},
      });
    });

    testWidgets('ticking every value saves as open to all', (tester) async {
      final api = _api();
      await _open(tester, api, MatchFilter.smokingStatus);

      await tester.tap(find.text('Sometimes'));
      await tester.pump();
      await tester.tap(find.text('Regularly'));
      await tester.pump();

      await _save(tester);
      expect(_patched(api), {
        'smokingStatus': {'values': null, 'dealbreaker': true},
      });
    });

    testWidgets('sends the ticked values as enum names, in the enum\'s order', (tester) async {
      final api = _api();
      await _open(tester, api, MatchFilter.dateIntentions);

      await tester.tap(find.text('Casual Dating'));
      await tester.pump();

      await _save(tester);
      expect(_patched(api), {
        'dateIntentions': {
          'values': ['CASUAL_DATING', 'SERIOUS_DATING', 'NOT_SURE'],
          'dealbreaker': false,
        },
      });
    });

    testWidgets('the hub then shows the server\'s response, not what was sent', (tester) async {
      final api = _api(
        saved: _with('smokingStatus', {
          'values': ['REGULARLY'],
          'dealbreaker': false,
        }),
      );
      await _open(tester, api, MatchFilter.smokingStatus);

      await tester.tap(find.text('Open to all'));
      await tester.pump();
      await _save(tester);

      expect(_summaryOf(tester, 'Smoking'), 'Regularly');
      // Nothing was fetched again.
      expect(api.requests.where((r) => r.path.contains('match-preferences') && r.method == 'GET'),
          hasLength(2));
    });

    testWidgets('Save is off until something changes', (tester) async {
      final api = _api();
      await _open(tester, api, MatchFilter.smokingStatus);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows the server\'s message when saving fails', (tester) async {
      final api = _api();
      await _open(tester, api, MatchFilter.smokingStatus);
      api.error = const ValidationException('Choose who you\'re interested in first');

      await tester.tap(find.text('Sometimes'));
      await tester.pump();
      await _save(tester);

      expect(find.byKey(const Key('edit-error-banner')), findsOneWidget);
      expect(find.text('Choose who you\'re interested in first'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });

  group('the dealbreaker switch', () {
    testWidgets('shows its help, and the subtitle follows it', (tester) async {
      final api = _api();
      await _open(tester, api, MatchFilter.ethnicity);

      expect(find.text('Dealbreaker'), findsOneWidget);
      expect(find.text(_switchHelp), findsOneWidget);
      expect(_switchValue(tester), isFalse);
      expect(find.text(_preferenceSubtitle), findsOneWidget);

      await tester.tap(find.byKey(const Key('dealbreaker-switch')));
      await tester.pump();
      expect(_switchValue(tester), isTrue);
      expect(find.text(_dealbreakerSubtitle), findsOneWidget);
      expect(find.text(_preferenceSubtitle), findsNothing);

      await _save(tester);
      expect(_patched(api), {
        'ethnicity': {'values': null, 'dealbreaker': true},
      });
    });

    testWidgets('starts from the saved value', (tester) async {
      await _open(tester, _api(), MatchFilter.relationshipType);

      expect(_switchValue(tester), isTrue);
      expect(find.text(_dealbreakerSubtitle), findsOneWidget);
    });

    testWidgets('isn\'t on Interested in', (tester) async {
      await _open(tester, _api(), MatchFilter.gender);

      expect(find.byKey(const Key('dealbreaker-switch')), findsNothing);
      expect(find.text('Who are you interested in?'), findsOneWidget);
    });
  });

  group('Interested in', () {
    testWidgets('ticks the saved genders and saves the new choice', (tester) async {
      final api = _api();
      await _open(tester, api, MatchFilter.gender);

      await tester.tap(find.text('Male'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(_patched(api), {
        'gender': {
          'values': ['MALE', 'FEMALE'],
          'dealbreaker': true,
        },
      });
    });
  });

  group('Age range', () {
    testWidgets('shows the top of the slider as 99+', (tester) async {
      final api = _api(preferences: _with('age', {'min': 24, 'max': 99, 'dealbreaker': true}));
      await _open(tester, api, MatchFilter.age);

      expect(_textOf(tester, 'age-range-value'), '24–99+');
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
    });

    testWidgets('its switch starts on for a new user', (tester) async {
      final defaults = mpFixture('get_users_me_match_preferences_defaults') as Map<String, dynamic>;
      await _open(tester, _api(preferences: defaults), MatchFilter.age);

      expect(_textOf(tester, 'age-range-value'), '25–35');
      expect(_switchValue(tester), isTrue);
      expect(find.text(_dealbreakerSubtitle), findsOneWidget);
    });

    testWidgets('sends the range with the switch', (tester) async {
      final api = _api();
      await _open(tester, api, MatchFilter.age);

      await tester.tap(find.byKey(const Key('dealbreaker-switch')));
      await tester.pump();
      await _save(tester);

      expect(_patched(api), {
        'age': {'min': 24, 'max': 32, 'dealbreaker': false},
      });
    });
  });

  group('Height', () {
    testWidgets('shows the ends in cm, and in feet and inches', (tester) async {
      await _open(tester, _api(), MatchFilter.height);

      expect(_isTicked(tester, 'Open to all'), isTrue);
      expect(_textOf(tester, 'height-min-value'), '120 cm or less');
      expect(_textOf(tester, 'height-max-value'), '220 cm or more');

      await tester.tap(find.text('Feet'));
      await tester.pump();
      expect(_textOf(tester, 'height-min-value'), '4\'0" or less');
      expect(_textOf(tester, 'height-max-value'), '7\'3" or more');
    });

    testWidgets('shows a saved range in either unit', (tester) async {
      final api = _api(
        preferences: _with('height', {'minCm': 160, 'maxCm': 185, 'dealbreaker': false}),
      );
      await _open(tester, api, MatchFilter.height);

      expect(_isTicked(tester, 'Open to all'), isFalse);
      expect(_textOf(tester, 'height-min-value'), '160 cm');
      expect(_textOf(tester, 'height-max-value'), '185 cm');

      await tester.tap(find.text('Feet'));
      await tester.pump();
      expect(_textOf(tester, 'height-min-value'), '5\'3"');
      expect(_textOf(tester, 'height-max-value'), '6\'1"');
    });

    testWidgets('changing the unit alone changes nothing to save', (tester) async {
      final api = _api(
        preferences: _with('height', {'minCm': 161, 'maxCm': 185, 'dealbreaker': false}),
      );
      await _open(tester, api, MatchFilter.height);

      await tester.tap(find.text('Feet'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('dealbreaker-switch')));
      await tester.pump();
      await _save(tester);

      // 161 cm shows as the nearest inch but is sent as saved.
      expect(_patched(api), {
        'height': {'minCm': 161, 'maxCm': 185, 'dealbreaker': true},
      });
    });

    testWidgets('Open to all clears it', (tester) async {
      final api = _api(
        preferences: _with('height', {'minCm': 160, 'maxCm': 185, 'dealbreaker': true}),
      );
      await _open(tester, api, MatchFilter.height);

      await tester.tap(find.text('Open to all'));
      await tester.pump();
      expect(_isTicked(tester, 'Open to all'), isTrue);
      expect(_textOf(tester, 'height-min-value'), '120 cm or less');
      expect(_textOf(tester, 'height-max-value'), '220 cm or more');

      await _save(tester);
      expect(_patched(api), {
        'height': {'minCm': null, 'maxCm': null, 'dealbreaker': true},
      });
    });
  });

  group('Distance', () {
    testWidgets('shows the stops in the city\'s unit and where it measures from', (tester) async {
      await _open(tester, _api(), MatchFilter.distance);

      expect(_textOf(tester, 'travel-distance-value'), '5 miles');
      expect(find.text('1 mile'), findsOneWidget);
      expect(find.text('Anywhere'), findsOneWidget);
      expect(find.text('From near Clapham'), findsOneWidget);
      // The Where editor's note about dates isn't shown here.
      expect(find.textContaining('keep dates within'), findsNothing);
    });

    testWidgets('without a starting point, measures from the city centre', (tester) async {
      final options = _options();
      (options['distance'] as Map<String, dynamic>)['from'] = null;
      await _open(tester, _api(options: options), MatchFilter.distance);

      expect(find.text('From the city centre. Set your starting point'), findsOneWidget);
      expect(find.textContaining('From near'), findsNothing);
    });

    testWidgets('labels km stops in km', (tester) async {
      final options = _options();
      options['distance'] = {
        'unit': 'KM',
        'stopsMeters': [2000, 5000, 10000],
        'from': 'Mitte',
      };
      final api = _api(
        options: options,
        preferences: _with('distance', {'maxMeters': 5000, 'dealbreaker': false}),
      );
      await _open(tester, api, MatchFilter.distance);

      expect(_textOf(tester, 'travel-distance-value'), '5 km');
      expect(find.text('2 km'), findsOneWidget);
      expect(find.text('From near Mitte'), findsOneWidget);
    });

    testWidgets('sends the distance with the switch', (tester) async {
      final api = _api();
      await _open(tester, api, MatchFilter.distance);

      await tester.tap(find.byKey(const Key('dealbreaker-switch')));
      await tester.pump();
      await _save(tester);

      expect(_patched(api), {
        'distance': {'maxMeters': 8047, 'dealbreaker': true},
      });
    });
  });

  test('heightStops ends at the bounds, with whole inches between', () {
    final stops = heightStops(const HeightOptions(minCm: 120, maxCm: 220), HeightUnit.feet);
    expect(stops.first.cm, 120);
    expect(stops.last.cm, 220);
    expect(stops[1].label, '4\'1"');
    expect(stops[stops.length - 2].label, '7\'2"');
    expect(stops.map((s) => s.cm).toList(), [...stops.map((s) => s.cm)]..sort());
  });
}
