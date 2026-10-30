import 'dart:async';

import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preferences_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/date_preferences_screen.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/edit_drinks_screen.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/edit_food_screen.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/edit_venue_screen.dart';
import 'package:eros_app/features/profile/domain/models/my_profile.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../fake_date_preferences_api.dart';
import '../profile_fixture.dart';

const _getPreferences = 'GET /users/me/date-preferences';
const _patchPreferences = 'PATCH /users/me/date-preferences';
const _getOptions = 'GET /date-preferences/options';

/// Saved preferences: loves Thai and Italian, won't eat British, vegetarian; wine bars;
/// ££–£££, quiet, either, no step-free.
Map<String, dynamic> _saved() => dpFixture('get_users_me_date_preferences') as Map<String, dynamic>;

/// Never saved (`isSet` false): the defaults.
Map<String, dynamic> _defaults() =>
    dpFixture('get_users_me_date_preferences_defaults') as Map<String, dynamic>;

/// The London options with ten cuisines, so the 5-item limits can be reached, and kosher.
Map<String, dynamic> _options() {
  final options = dpFixture('get_date_preferences_options_london') as Map<String, dynamic>;
  (options['cuisines'] as List<dynamic>).addAll([
    for (final (value, name) in [
      ('CHINESE', 'Chinese'),
      ('FRENCH', 'French'),
      ('GREEK', 'Greek'),
      ('INDIAN', 'Indian'),
      ('MEXICAN', 'Mexican'),
      ('SPANISH', 'Spanish'),
    ])
      {'value': value, 'displayName': name},
  ]);
  (options['dietaryOptions'] as List<dynamic>).add({'value': 'KOSHER', 'displayName': 'Kosher'});
  return options;
}

/// Serves the profile from `GET /users/me` without a network call.
class _FakeMyProfile extends MyProfileNotifier {
  final Future<MyProfile> profile;

  _FakeMyProfile(this.profile);

  @override
  Future<MyProfile> build() => profile;
}

typedef _ScreenBuilder = Widget Function(
    DatePreferences preferences, DatePreferenceOptions options);

/// Opens [screen] from a launcher page, so Save and Back can pop it. Returns the fake API, which
/// records every request.
Future<FakeDatePreferencesApi> _open(
  WidgetTester tester,
  _ScreenBuilder screen, {
  Map<String, dynamic>? preferences,
  MyProfile? profile,
  Future<MyProfile>? profileLater,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final prefsJson = preferences ?? _saved();
  final api = FakeDatePreferencesApi(responses: {
    _getPreferences: prefsJson,
    _patchPreferences: _saved(),
    _getOptions: _options(),
  });
  final prefs = DatePreferences.fromJson(prefsJson);
  final options = DatePreferenceOptions.fromJson(_options());

  await tester.pumpWidget(ProviderScope(
    overrides: [
      datePreferencesRepositoryProvider.overrideWithValue(
        DatePreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
      ),
      myProfileProvider.overrideWith(
        () => _FakeMyProfile(profileLater ?? Future.value(profile ?? profileWith())),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => screen(prefs, options)),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  ));
  // Load the profile first, as the hub's app would have, so suggestions can apply at once.
  if (profileLater == null) {
    ProviderScope.containerOf(tester.element(find.text('Open'))).read(myProfileProvider);
    await tester.pump();
  }
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return api;
}

Widget _food(DatePreferences p, DatePreferenceOptions o) =>
    EditFoodScreen(preferences: p, options: o);
Widget _drinks(DatePreferences p, DatePreferenceOptions o) =>
    EditDrinksScreen(preferences: p, options: o);
Widget _venue(DatePreferences p, DatePreferenceOptions o) =>
    EditVenueScreen(preferences: p, options: o);

Finder _save() => find.widgetWithText(TextButton, 'Save');

bool _canSave(WidgetTester tester) => tester.widget<TextButton>(_save()).onPressed != null;

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(_save());
  await tester.pumpAndSettle();
}

CheckboxListTile _tile(WidgetTester tester, String label) =>
    tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, label));

List<dynamic> _patches(FakeDatePreferencesApi api) => [
      for (final r in api.requests)
        if ('${r.method} ${r.path}' == _patchPreferences) r.data,
    ];

void main() {
  group('EditFoodScreen', () {
    testWidgets('caps "Cuisines I love" at the limit and saves only the food section',
        (tester) async {
      final api = await _open(tester, _food, preferences: _defaults());

      for (final cuisine in ['British', 'Italian', 'Japanese', 'Thai', 'Chinese']) {
        await tester.tap(find.text(cuisine));
        await tester.pump();
      }
      expect(find.text('5/5 selected'), findsOneWidget);
      expect(_tile(tester, 'French').onChanged, isNull);

      await tester.tap(find.text('French'));
      await tester.pump();
      expect(_tile(tester, 'French').value, isFalse);

      await _tapSave(tester);
      expect(_patches(api), [
        {
          'food': {
            'cuisinesLoved': ['BRITISH', 'ITALIAN', 'JAPANESE', 'THAI', 'CHINESE'],
            'cuisinesExcluded': <String>[],
            'dietaryNeeds': <String>[],
          },
        },
      ]);
      expect(find.byType(EditFoodScreen), findsNothing);
    });

    testWidgets('caps "Cuisines I won\'t eat" at the limit and says they\'re never suggested',
        (tester) async {
      await _open(tester, _food, preferences: _defaults());

      await tester.tap(find.text('Cuisines I won\'t eat'));
      await tester.pumpAndSettle();
      expect(find.text('We\'ll never suggest a restaurant that serves these.'), findsOneWidget);

      for (final cuisine in ['Chinese', 'French', 'Greek', 'Indian', 'Mexican']) {
        await tester.tap(find.text(cuisine));
        await tester.pump();
      }
      expect(find.text('5/5 selected'), findsOneWidget);
      expect(_tile(tester, 'Spanish').onChanged, isNull);
    });

    testWidgets('a cuisine picked in one list is disabled in the other', (tester) async {
      await _open(tester, _food);

      // Loved: Thai, Italian. British is excluded, so it can't be loved too.
      expect(_tile(tester, 'Thai').value, isTrue);
      expect(_tile(tester, 'British').onChanged, isNull);
      expect(find.text('Already in Cuisines I won\'t eat'), findsOneWidget);
      await tester.tap(find.text('British'));
      await tester.pump();
      expect(_tile(tester, 'British').value, isFalse);

      await tester.tap(find.text('Cuisines I won\'t eat'));
      await tester.pumpAndSettle();
      expect(_tile(tester, 'British').value, isTrue);
      expect(_tile(tester, 'Thai').onChanged, isNull);
      expect(_tile(tester, 'Italian').onChanged, isNull);
      expect(find.text('Already in Cuisines I love'), findsNWidgets(2));

      // Freeing a cuisine from one list makes it available in the other.
      await tester.tap(find.text('British'));
      await tester.pump();
      await tester.tap(find.text('Cuisines I love'));
      await tester.pumpAndSettle();
      expect(_tile(tester, 'British').onChanged, isNotNull);
    });

    testWidgets('suggests dietary needs from the profile when nothing is set, unsaved until Save',
        (tester) async {
      final api = await _open(
        tester,
        _food,
        preferences: _defaults(),
        profile: profileWith(diet: 'Vegan'),
      );

      // Opens on the dietary tab so the suggestion is seen.
      expect(_tile(tester, 'Vegan').value, isTrue);
      expect(find.text('Suggested from your profile'), findsOneWidget);
      expect(_tile(tester, 'Vegetarian').value, isFalse);
      expect(_canSave(tester), isTrue);

      // Leaving doesn't save, and doesn't ask: the user changed nothing themselves.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(EditFoodScreen), findsNothing);
      expect(_patches(api), isEmpty);

      // Saving keeps it.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await _tapSave(tester);
      expect(_patches(api), [
        {
          'food': {
            'cuisinesLoved': <String>[],
            'cuisinesExcluded': <String>[],
            'dietaryNeeds': ['VEGAN'],
          },
        },
      ]);
    });

    testWidgets('suggests nothing once preferences are set', (tester) async {
      await _open(tester, _food, profile: profileWith(diet: 'Vegan'));

      expect(find.text('Cuisines I love'), findsOneWidget);
      await tester.tap(find.text('Dietary needs'));
      await tester.pumpAndSettle();
      expect(_tile(tester, 'Vegetarian').value, isTrue);
      expect(_tile(tester, 'Vegan').value, isFalse);
      expect(find.text('Suggested from your profile'), findsNothing);
      expect(_canSave(tester), isFalse);
    });

    testWidgets('suggests nothing for a diet without a dietary need', (tester) async {
      await _open(
        tester,
        _food,
        preferences: _defaults(),
        profile: profileWith(diet: 'Pescatarian'),
      );

      await tester.tap(find.text('Dietary needs'));
      await tester.pumpAndSettle();
      expect(find.text('Suggested from your profile'), findsNothing);
      expect(_canSave(tester), isFalse);
    });

    testWidgets('suggests once the profile loads, if it loads after the screen opens',
        (tester) async {
      final profile = Completer<MyProfile>();
      await _open(tester, _food, preferences: _defaults(), profileLater: profile.future);
      expect(find.text('Suggested from your profile'), findsNothing);

      profile.complete(profileWith(diet: 'Halal'));
      await tester.pumpAndSettle();
      expect(_tile(tester, 'Halal').value, isTrue);
      expect(find.text('Suggested from your profile'), findsOneWidget);
    });

    testWidgets('shows the server\'s validation message in the banner', (tester) async {
      final api = await _open(tester, _food);
      await tester.tap(find.text('Japanese'));
      await tester.pump();

      api.error = const ValidationException('At most 5 cuisines you love');
      await _tapSave(tester);

      expect(find.text('At most 5 cuisines you love'), findsOneWidget);
      expect(find.byType(EditFoodScreen), findsOneWidget);
    });
  });

  group('EditDrinksScreen', () {
    testWidgets('picks kinds of bar and saves only the drinks section', (tester) async {
      final api = await _open(tester, _drinks);

      expect(find.text('Leave them all unticked for any kind of bar.'), findsOneWidget);
      expect(_tile(tester, 'Wine bar').value, isTrue);
      expect(_canSave(tester), isFalse);

      await tester.tap(find.text('Wine bar'));
      await tester.pump();
      await tester.tap(find.text('Good alcohol-free options matter to me'));
      await tester.pump();

      await _tapSave(tester);
      expect(_patches(api), [
        {
          'drinks': {'drinkStyles': <String>[], 'wantsAlcoholFree': true},
        },
      ]);
    });

    testWidgets('suggests alcohol-free when the profile says "Never", unsaved until Save',
        (tester) async {
      final api = await _open(
        tester,
        _drinks,
        preferences: _defaults(),
        profile: profileWith(alcohol: 'Never'),
      );

      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
      expect(find.text('Suggested from your profile'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(_patches(api), isEmpty);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await _tapSave(tester);
      expect(_patches(api), [
        {
          'drinks': {'drinkStyles': <String>[], 'wantsAlcoholFree': true},
        },
      ]);
    });

    testWidgets('suggests nothing once preferences are set', (tester) async {
      await _open(tester, _drinks, profile: profileWith(alcohol: 'Never'));
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
      expect(find.text('Suggested from your profile'), findsNothing);
    });

    testWidgets('suggests nothing when the alcohol answer isn\'t "Never"', (tester) async {
      await _open(
        tester,
        _drinks,
        preferences: _defaults(),
        profile: profileWith(alcohol: 'Sometimes'),
      );
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
      expect(find.text('Suggested from your profile'), findsNothing);
    });
  });

  group('EditVenueScreen', () {
    bool selected(WidgetTester tester, String label) => tester
        .widget<FilterChip>(find.ancestor(of: find.text(label), matching: find.byType(FilterChip)))
        .selected;

    testWidgets('shows the server\'s price symbols and keeps at least one band', (tester) async {
      final api = await _open(tester, _venue);

      for (final symbol in ['£', '££', '£££', '££££']) {
        expect(find.text(symbol), findsOneWidget);
      }
      expect(find.text('Pick at least one.'), findsOneWidget);
      expect(selected(tester, '££'), isTrue);
      expect(selected(tester, '£££'), isTrue);

      await tester.tap(find.text('££'));
      await tester.pump();
      expect(selected(tester, '££'), isFalse);

      // The last band can't be deselected.
      await tester.tap(find.text('£££'));
      await tester.pump();
      expect(selected(tester, '£££'), isTrue);

      await _tapSave(tester);
      expect(_patches(api), [
        {
          'venue': {
            'priceRanges': ['PREMIUM'],
            'atmosphere': 'QUIET',
            'setting': 'EITHER',
            'needsStepFree': false,
          },
        },
      ]);
    });

    testWidgets('saves bands cheapest first, single choices and step-free, only the venue',
        (tester) async {
      final api = await _open(tester, _venue);

      await tester.tap(find.text('£'));
      await tester.tap(find.text('Lively'));
      await tester.tap(find.text('Outdoors'));
      await tester.tap(find.text('I need step-free access'));
      await tester.pump();

      await _tapSave(tester);
      expect(_patches(api), [
        {
          'venue': {
            'priceRanges': ['BUDGET', 'MID_RANGE', 'PREMIUM'],
            'atmosphere': 'LIVELY',
            'setting': 'OUTDOORS',
            'needsStepFree': true,
          },
        },
      ]);
    });

    testWidgets('asks before discarding changes', (tester) async {
      await _open(tester, _venue);
      await tester.tap(find.text('Lively'));
      await tester.pump();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });

  group('DatePreferencesScreen', () {
    Future<void> pumpHub(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          datePreferencesRepositoryProvider.overrideWithValue(DatePreferencesRepository(
            apiClient: FakeDatePreferencesApi(responses: {
              _getPreferences: _saved(),
              _patchPreferences: _saved(),
              _getOptions: _options(),
            }),
            logger: Logger(level: Level.off),
          )),
          myProfileProvider.overrideWith(() => _FakeMyProfile(Future.value(profileWith()))),
        ],
        child: const MaterialApp(home: DatePreferencesScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('Dinner, Drinks and The venue open their editors', (tester) async {
      await pumpHub(tester);
      expect(foodEditorEnabled && drinksEditorEnabled && venueEditorEnabled, isTrue);

      for (final (summary, screen) in [
        ('Loves Thai, Italian · won\'t eat British', EditFoodScreen),
        ('Wine bar', EditDrinksScreen),
        ('Step-free access: not needed', EditVenueScreen),
      ]) {
        await tester.tap(find.text(summary));
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('shows the saved section from the server\'s response', (tester) async {
      await pumpHub(tester);
      final container =
          ProviderScope.containerOf(tester.element(find.byType(DatePreferencesScreen)));

      await tester.tap(find.text('Step-free access: not needed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lively'));
      await tester.pump();
      await _tapSave(tester);

      // The PATCH stub answers with the saved fixture, so the hub shows that, not the draft.
      expect(find.byType(EditVenueScreen), findsNothing);
      expect(container.read(datePreferencesProvider).value?.venue.atmosphere, 'QUIET');
    });
  });
}
