import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/date_preferences_screen.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/edit_date_types_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../fake_date_preferences_api.dart';

const _preferencesPath = 'GET /users/me/date-preferences';
const _optionsPath = 'GET /date-preferences/options';

Map<String, dynamic> _preferences() =>
    dpFixture('get_users_me_date_preferences') as Map<String, dynamic>;

Map<String, dynamic> _defaults() =>
    dpFixture('get_users_me_date_preferences_defaults') as Map<String, dynamic>;

Map<String, dynamic> _londonOptions() =>
    dpFixture('get_date_preferences_options_london') as Map<String, dynamic>;

/// The London options as a city that uses km and euros.
Map<String, dynamic> _kmOptions() {
  final options = _londonOptions();
  (options['city'] as Map<String, dynamic>)
    ..['distanceUnit'] = 'KM'
    ..['currency'] = 'EUR';
  options['travelStops'] = [
    {'label': '2 km', 'meters': 2000},
    {'label': '5 km', 'meters': 5000},
    {'label': '10 km', 'meters': 10000},
  ];
  for (final band in options['priceRanges'] as List<dynamic>) {
    final b = band as Map<String, dynamic>;
    b['symbol'] = (b['symbol'] as String).replaceAll('£', '€');
  }
  return options;
}

FakeDatePreferencesApi _api({Map<String, dynamic>? preferences, Map<String, dynamic>? options}) {
  return FakeDatePreferencesApi(responses: {
    _preferencesPath: preferences ?? _preferences(),
    _optionsPath: options ?? _londonOptions(),
  });
}

Future<void> _pump(WidgetTester tester, FakeDatePreferencesApi api) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      datePreferencesRepositoryProvider.overrideWithValue(
        DatePreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
      ),
    ],
    child: const MaterialApp(home: DatePreferencesScreen()),
  ));
  await tester.pumpAndSettle();
}

int _count(FakeDatePreferencesApi api, String request) =>
    api.requests.where((r) => '${r.method} ${r.path}' == request).length;

void main() {
  group('DatePreferencesScreen', () {
    testWidgets('shows every section\'s summary from the fixture', (tester) async {
      await _pump(tester, _api());

      expect(
        find.text('These shape the places we suggest. You and your date still rank them. Only '
            'you can see this page.'),
        findsOneWidget,
      );
      expect(find.text('Tell us what you like and we\'ll pick better places'), findsNothing);

      // Where
      expect(find.text('London · near Clapham · up to 5 miles'), findsOneWidget);

      // Date types: Dinner is LOVE, Coffee (id 1) is NO, Drinks has no row so it's OK.
      expect(find.text('Date types'), findsOneWidget);
      expect(find.text('Love it'), findsOneWidget);
      expect(find.text('Happy to'), findsOneWidget);
      expect(find.text('Not for me'), findsOneWidget);

      // Dinner
      expect(find.text('Loves Thai, Italian · won\'t eat British'), findsOneWidget);
      expect(find.text('Vegetarian'), findsOneWidget);

      // Drinks
      expect(find.text('Wine bar'), findsOneWidget);
      expect(find.text('Good alcohol-free options'), findsNothing);

      // The venue
      await tester.scrollUntilVisible(find.text('Step-free access: not needed'), 100);
      expect(
        find.text('££–£££ · Atmosphere: Quiet and relaxed · Setting: Either'),
        findsOneWidget,
      );
      expect(find.text('Step-free access: not needed'), findsOneWidget);
    });

    testWidgets('pairs each activity with its level', (tester) async {
      await _pump(tester, _api());

      Finder levelOf(String activity) => find.descendant(
            of: find.ancestor(of: find.text(activity), matching: find.byType(Row)).first,
            matching: find.byType(Text),
          );

      List<String?> texts(String activity) =>
          tester.widgetList<Text>(levelOf(activity)).map((t) => t.data).toList();

      expect(texts('Coffee'), ['Coffee', 'Not for me']);
      expect(texts('Drinks'), ['Drinks', 'Happy to']);
    });

    testWidgets('shows the defaults and the banner when nothing is set yet', (tester) async {
      await _pump(tester, _api(preferences: _defaults()));

      expect(find.text('Tell us what you like and we\'ll pick better places'), findsOneWidget);
      expect(find.text('London · City centre · Anywhere'), findsOneWidget);
      expect(find.text('Happy to'), findsNWidgets(3));
      expect(find.text('Any cuisine'), findsOneWidget);
      expect(find.text('Any kind of bar'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Step-free access: not needed'), 100);
      expect(
        find.text('£–££££ · Atmosphere: No preference · Setting: Either'),
        findsOneWidget,
      );
    });

    testWidgets('hides Dinner when Dinner is "Not for me"', (tester) async {
      final preferences = _preferences();
      preferences['activities'] = [
        {'activityId': 3, 'level': 'NO'},
      ];
      await _pump(tester, _api(preferences: preferences));

      expect(find.text('Dinner'), findsOneWidget); // Its "Date types" line only.
      expect(find.text('Loves Thai, Italian · won\'t eat British'), findsNothing);
      expect(find.text('Drinks'), findsNWidgets(2)); // Its line and its section.
    });

    testWidgets('finds Dinner and Drinks by category, not name', (tester) async {
      final options = _londonOptions();
      for (final activity in options['activities'] as List<dynamic>) {
        final a = activity as Map<String, dynamic>;
        a['name'] = 'Activity ${a['activityId']}';
      }
      final preferences = _preferences();
      preferences['activities'] = [
        {'activityId': 2, 'level': 'NO'},
      ];
      await _pump(tester, _api(preferences: preferences, options: options));

      expect(find.text('Loves Thai, Italian · won\'t eat British'), findsOneWidget);
      expect(find.text('Wine bar'), findsNothing);
    });

    testWidgets('shows distance in miles in a MI city', (tester) async {
      final preferences = _preferences();
      (preferences['where'] as Map<String, dynamic>)['maxTravelMeters'] = 4000; // Not a stop.
      await _pump(tester, _api(preferences: preferences));

      expect(find.text('London · near Clapham · up to 2.5 miles'), findsOneWidget);
    });

    testWidgets('shows distance in km and prices in the city\'s currency in a KM city',
        (tester) async {
      final preferences = _preferences();
      (preferences['where'] as Map<String, dynamic>)['maxTravelMeters'] = 5000;
      await _pump(tester, _api(preferences: preferences, options: _kmOptions()));

      expect(find.text('London · near Clapham · up to 5 km'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Step-free access: not needed'), 100);
      expect(
        find.text('€€–€€€ · Atmosphere: Quiet and relaxed · Setting: Either'),
        findsOneWidget,
      );
    });

    testWidgets('converts a distance that isn\'t one of the city\'s stops into km', (tester) async {
      await _pump(tester, _api(options: _kmOptions())); // 8047 m is a London stop.

      expect(find.text('London · near Clapham · up to 8 km'), findsOneWidget);
    });

    testWidgets('lists each city on its own line when there are several', (tester) async {
      final preferences = _preferences();
      ((preferences['where'] as Map<String, dynamic>)['cities'] as List<dynamic>)
          .add({'cityId': 2, 'cityName': 'Manchester', 'start': null});
      await _pump(tester, _api(preferences: preferences));

      expect(find.text('London · near Clapham'), findsOneWidget);
      expect(find.text('Manchester · City centre'), findsOneWidget);
      expect(find.text('Up to 5 miles'), findsOneWidget);
    });

    testWidgets('calls a pin with no district "Your starting point"', (tester) async {
      final preferences = _preferences();
      final city = ((preferences['where'] as Map<String, dynamic>)['cities'] as List<dynamic>)
          .single as Map<String, dynamic>;
      (city['start'] as Map<String, dynamic>)['district'] = null;
      await _pump(tester, _api(preferences: preferences));

      expect(find.text('London · Your starting point · up to 5 miles'), findsOneWidget);
    });

    testWidgets('shows price bands with a gap separately', (tester) async {
      final preferences = _preferences();
      (preferences['venue'] as Map<String, dynamic>)
        ..['priceRanges'] = ['BUDGET', 'PREMIUM']
        ..['needsStepFree'] = true;
      await _pump(tester, _api(preferences: preferences));

      await tester.scrollUntilVisible(find.text('Step-free access: needed'), 100);
      expect(
        find.text('£, £££ · Atmosphere: Quiet and relaxed · Setting: Either'),
        findsOneWidget,
      );
    });

    testWidgets('shows an error and loads again on retry', (tester) async {
      final api = _api()..error = const NetworkException('offline');
      await _pump(tester, api);

      expect(
        find.text('Unable to connect to the server. Please check your internet connection and try '
            'again.'),
        findsOneWidget,
      );
      expect(find.text('London · near Clapham · up to 5 miles'), findsNothing);

      api.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('London · near Clapham · up to 5 miles'), findsOneWidget);
    });

    testWidgets('shows an error when only the options fail, and retries them', (tester) async {
      final api = FakeDatePreferencesApi(responses: {_preferencesPath: _preferences()});
      await _pump(tester, api);

      expect(find.text('Try again'), findsOneWidget);

      api.responses[_optionsPath] = _londonOptions();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('London · near Clapham · up to 5 miles'), findsOneWidget);
    });

    testWidgets('pull-to-refresh fetches the preferences and the options again', (tester) async {
      final api = _api();
      await _pump(tester, api);
      expect(_count(api, _preferencesPath), 1);
      expect(_count(api, _optionsPath), 1);

      api.responses[_preferencesPath] = _defaults();
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(_count(api, _preferencesPath), 2);
      expect(_count(api, _optionsPath), 2);
      expect(find.text('London · City centre · Anywhere'), findsOneWidget);
    });

    testWidgets('shows the error, not the old summaries, when a refresh fails', (tester) async {
      final api = _api();
      await _pump(tester, api);

      api.responses.remove(_optionsPath);
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('London · near Clapham · up to 5 miles'), findsNothing);
    });

    testWidgets('shows the error when refreshing the preferences fails', (tester) async {
      final api = _api();
      await _pump(tester, api);

      api.responses.remove(_preferencesPath);
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('London · near Clapham · up to 5 miles'), findsNothing);
    });

    testWidgets('each section opens its placeholder', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _api());

      // The card reads as one button: its title and summary, then what tapping it does.
      expect(
        tester.getSemantics(find.text('London · near Clapham · up to 5 miles')),
        matchesSemantics(
          label: 'Where\nLondon · near Clapham · up to 5 miles',
          hint: 'Edit Where',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();

      await tester.tap(find.text('London · near Clapham · up to 5 miles'));
      await tester.pumpAndSettle();

      expect(find.text('You\'ll be able to change this soon.'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Where'), findsOneWidget);
    });

    testWidgets('Date types opens its editor', (tester) async {
      await _pump(tester, _api());

      await tester.tap(find.text('Love it')); // the Dinner line, in the Date types card
      await tester.pumpAndSettle();

      expect(find.byType(EditDateTypesScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Date types'), findsOneWidget);
      expect(find.text('You\'ll be able to change this soon.'), findsNothing);
    });
  });
}
