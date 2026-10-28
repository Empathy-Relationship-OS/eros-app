import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preferences_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/edit_where_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../fake_date_preferences_api.dart';

const _patchPath = 'PATCH /users/me/date-preferences';

Map<String, dynamic> _preferences() =>
    dpFixture('get_users_me_date_preferences') as Map<String, dynamic>;

Map<String, dynamic> _london() =>
    dpFixture('get_date_preferences_options_london') as Map<String, dynamic>;

Map<String, dynamic> _texas() =>
    dpFixture('get_date_preferences_options_texas') as Map<String, dynamic>;

const _clapham = StartPoint(
  latitude: 51.462,
  longitude: -0.138,
  district: DistrictRef(districtId: 14, name: 'Clapham'),
);

const _london1 = DatingCityPreference(cityId: 1, cityName: 'London', start: _clapham);
const _houston = DatingCityPreference(cityId: 2, cityName: 'Houston');

/// "My first city" answers with [firstCityOptions]; each city id answers with its own options.
FakeDatePreferencesApi _api({Map<String, dynamic>? firstCityOptions}) {
  return FakeDatePreferencesApi(responses: {
    'GET /city/all': dpFixture('get_city_all') as Object,
    'GET /users/me/date-preferences': _preferences(),
    'GET /date-preferences/options': firstCityOptions ?? _london(),
    'GET /date-preferences/options?cityId=1': _london(),
    'GET /date-preferences/options?cityId=2': _texas(),
    'GET /date-preferences/options?cityId=3': _texas(),
    _patchPath: _preferences(),
  });
}

/// Opens [EditWhereScreen] from a launcher, so its pop on save has somewhere to go.
Future<void> _pump(
  WidgetTester tester,
  FakeDatePreferencesApi api,
  WherePreferences initial,
) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    datePreferencesRepositoryProvider.overrideWithValue(
      DatePreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
    ),
  ]);
  addTearDown(container.dispose);
  await container.read(datePreferencesProvider.future);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EditWhereScreen(initial: initial),
            )),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Finder _chip(String city) => find.widgetWithText(FilterChip, city);

bool _chipSelected(WidgetTester tester, String city) =>
    tester.widget<FilterChip>(_chip(city)).selected;

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save')).onPressed != null;

String _distance(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('travel-distance-value'))).data!;

Future<void> _dragSlider(WidgetTester tester, double dx) async {
  await tester.drag(find.byType(Slider), Offset(dx, 0));
  await tester.pumpAndSettle();
}

Future<Map<String, dynamic>> _save(WidgetTester tester, FakeDatePreferencesApi api) async {
  await tester.tap(find.widgetWithText(TextButton, 'Save'));
  await tester.pumpAndSettle();
  final patch = api.requests.singleWhere((r) => '${r.method} ${r.path}' == _patchPath);
  return (patch.data as Map<String, dynamic>)['where'] as Map<String, dynamic>;
}

void main() {
  group('EditWhereScreen', () {
    testWidgets('shows the cities from GET /city/all and each chosen city\'s starting point',
        (tester) async {
      await _pump(tester, _api(), WherePreferences(cities: [_london1], maxTravelMeters: 8047));

      expect(_chipSelected(tester, 'London'), isTrue);
      expect(_chipSelected(tester, 'Houston'), isFalse);
      expect(_chipSelected(tester, 'Dallas'), isFalse);

      final londonRow = find.byKey(const Key('starting-from-1'));
      expect(find.descendant(of: londonRow, matching: find.text('Starting from')), findsOneWidget);
      expect(find.descendant(of: londonRow, matching: find.text('Clapham')), findsOneWidget);

      expect(_distance(tester), '5 miles');
      expect(
        find.text('We\'ll aim to keep dates within this. If the best place for you both is a '
            'little further, we may suggest it.'),
        findsOneWidget,
      );
      // Nothing has changed yet.
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('with no city selected, Save is disabled', (tester) async {
      await _pump(tester, _api(), WherePreferences(cities: [_london1], maxTravelMeters: 8047));

      await tester.tap(_chip('London'));
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, 'London'), isFalse);
      expect(_saveEnabled(tester), isFalse);
      // The slider keeps London's stops rather than disappearing.
      expect(_distance(tester), '5 miles');
    });

    testWidgets('removing a city removes its starting row; Save keeps the kept city\'s start',
        (tester) async {
      final api = _api();
      await _pump(tester, api, WherePreferences(cities: [_london1, _houston], maxTravelMeters: 8047));
      expect(find.byKey(const Key('starting-from-2')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('starting-from-2')), matching: find.text('City centre')),
        findsOneWidget,
      );

      await tester.tap(_chip('Houston'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('starting-from-2')), findsNothing);

      await tester.tap(_chip('Dallas'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byKey(const Key('starting-from-3')), matching: find.text('City centre')),
        findsOneWidget,
      );

      final where = await _save(tester, api);
      expect(where, {
        'cities': [
          {'cityId': 1, 'start': {'latitude': 51.462, 'longitude': -0.138}},
          {'cityId': 3, 'start': null},
        ],
        'maxTravelMeters': 8047,
      });
      expect(find.byType(EditWhereScreen), findsNothing);
    });

    testWidgets('a city removed and chosen again keeps its saved starting point', (tester) async {
      final api = _api();
      await _pump(tester, api, WherePreferences(cities: [_houston, _london1], maxTravelMeters: 8047));

      await tester.tap(_chip('London'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('London'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byKey(const Key('starting-from-1')), matching: find.text('Clapham')),
        findsOneWidget,
      );
      // Same cities, same order: nothing to save.
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('a pin with no district reads "Your starting point", not "City centre"',
        (tester) async {
      const pinNoDistrict = StartPoint(latitude: 29.76, longitude: -95.37);
      await _pump(
        tester,
        _api(),
        WherePreferences(
          cities: [
            _london1.copyWith(start: pinNoDistrict),
            _houston,
          ],
          maxTravelMeters: 8047,
        ),
      );

      final pinnedRow = find.byKey(const Key('starting-from-1'));
      expect(find.descendant(of: pinnedRow, matching: find.text('Your starting point')),
          findsOneWidget);
      expect(find.descendant(of: pinnedRow, matching: find.text('City centre')), findsNothing);
      // No pin at all is still the city centre.
      expect(
        find.descendant(of: find.byKey(const Key('starting-from-2')), matching: find.text('City centre')),
        findsOneWidget,
      );
    });

    testWidgets('the slider\'s stops and labels come from the London options', (tester) async {
      await _pump(tester, _api(), WherePreferences(cities: [_london1], maxTravelMeters: 8047));

      expect(tester.widget<Slider>(find.byType(Slider)).divisions, 6);
      expect(find.text('1 mile'), findsOneWidget);

      await _dragSlider(tester, -1000);
      expect(_distance(tester), '1 mile');
    });

    testWidgets('the slider\'s stops and labels come from the Texas options', (tester) async {
      await _pump(
        tester,
        _api(firstCityOptions: _texas()),
        WherePreferences(cities: [_houston], maxTravelMeters: 8047),
      );

      expect(tester.widget<Slider>(find.byType(Slider)).divisions, 6);
      expect(find.text('2 miles'), findsOneWidget);
      expect(find.text('1 mile'), findsNothing);

      await _dragSlider(tester, -1000);
      expect(_distance(tester), '2 miles');
    });

    testWidgets('a saved distance that isn\'t a stop shows the nearest one, and Save sends it',
        (tester) async {
      final api = _api(firstCityOptions: _texas());
      // 3 miles, a London stop: the nearest Texas stop is 2 miles.
      await _pump(tester, api, WherePreferences(cities: [_houston], maxTravelMeters: 4828));

      expect(_distance(tester), '2 miles');
      // Not saved until the user taps Save.
      expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);
      expect(_saveEnabled(tester), isTrue);

      final where = await _save(tester, api);
      expect(where['maxTravelMeters'], 3219);
    });

    testWidgets('Anywhere sends null', (tester) async {
      final api = _api();
      await _pump(tester, api, WherePreferences(cities: [_london1], maxTravelMeters: 8047));

      await _dragSlider(tester, 1000);
      expect(_distance(tester), 'Anywhere');

      final where = await _save(tester, api);
      expect(where.containsKey('maxTravelMeters'), isTrue);
      expect(where['maxTravelMeters'], isNull);
    });

    testWidgets('the stops follow the first chosen city', (tester) async {
      final api = _api();
      await _pump(tester, api, WherePreferences(cities: [_london1], maxTravelMeters: 4828));
      expect(_distance(tester), '3 miles');

      await tester.tap(_chip('Houston'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('London'));
      await tester.pumpAndSettle();

      // Houston is now first, so its stops are shown and 3 miles becomes 2.
      expect(api.requests.map((r) => r.path), contains('/date-preferences/options?cityId=2'));
      expect(find.text('1 mile'), findsNothing);
      expect(_distance(tester), '2 miles');

      final where = await _save(tester, api);
      expect(where, {
        'cities': [
          {'cityId': 2, 'start': null},
        ],
        'maxTravelMeters': 3219,
      });
    });

    testWidgets('a rejected save shows the server\'s message and stays open', (tester) async {
      final api = _api();
      await _pump(tester, api, WherePreferences(cities: [_london1], maxTravelMeters: 8047));
      await _dragSlider(tester, 1000);

      api.error = const ValidationException('That city isn\'t available.');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit-error-banner')), findsOneWidget);
      expect(find.text('That city isn\'t available.'), findsOneWidget);
      expect(find.byType(EditWhereScreen), findsOneWidget);
    });

    testWidgets('a failed city load can be retried', (tester) async {
      final api = _api();
      final cities = api.responses.remove('GET /city/all')!;
      await _pump(tester, api, WherePreferences(cities: [_london1], maxTravelMeters: 8047));

      expect(find.text('We couldn\'t load the cities. Please try again.'), findsOneWidget);

      api.responses['GET /city/all'] = cities;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, 'London'), isTrue);
    });
  });
}
