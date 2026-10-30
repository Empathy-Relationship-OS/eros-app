import 'package:eros_app/core/config/map_config.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/data/device_location_service.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/start_point_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../fake_date_preferences_api.dart';

const _districtsPath = 'GET /city/1/districts';

const _london = OptionsCity(
  cityId: 1,
  distanceUnit: 'MI',
  currency: 'GBP',
  centre: GeoPoint(latitude: 51.5074, longitude: -0.1278),
  reachMeters: 40000,
);

// Near the Clapham and Brixton centres in get_city_districts.json.
const _clapham = GeoPoint(latitude: 51.4620, longitude: -0.1380);
const _brixton = GeoPoint(latitude: 51.46149, longitude: -0.11551);
const _brighton = GeoPoint(latitude: 50.8225, longitude: -0.1372);

/// Answers "Use my location" with [result] and counts the calls.
class _FakeLocationService implements DeviceLocationService {
  _FakeLocationService(this.result);

  final DeviceLocation result;
  int calls = 0;

  @override
  Future<DeviceLocation> currentLocation() async {
    calls++;
    return result;
  }
}

class _Harness {
  final FakeDatePreferencesApi api;
  StartPointChoice? choice;
  bool popped = false;

  _Harness(this.api);
}

/// Opens the map from a host page, as the Where screen will, and records what it returns.
Future<_Harness> _open(
  WidgetTester tester, {
  GeoPoint? start,
  DeviceLocationService? location,
  MapTiles? tiles,
}) async {
  final harness = _Harness(FakeDatePreferencesApi(responses: {
    _districtsPath: dpFixture('get_city_districts') as Object,
  }));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      datePreferencesRepositoryProvider.overrideWithValue(
        DatePreferencesRepository(apiClient: harness.api, logger: Logger(level: Level.off)),
      ),
      deviceLocationServiceProvider
          .overrideWithValue(location ?? _FakeLocationService(const LocationRefused())),
      mapTilesProvider.overrideWithValue(tiles),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            harness.choice = await StartPointMapScreen.open(
              context,
              city: _london,
              cityName: 'London',
              start: start,
            );
            harness.popped = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

ElevatedButton _saveButton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Set starting point'));

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Set starting point'));
  await tester.tap(find.text('Set starting point'));
  await tester.pumpAndSettle();
}

void main() {
  group('StartPointMapScreen', () {
    testWidgets('opens on the saved pin and labels its district', (tester) async {
      await _open(tester, start: _clapham);

      expect(find.text('Near Clapham'), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('opens on the city centre without a saved pin', (tester) async {
      await _open(tester);

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.initialCenter.latitude, 51.5074);
      expect(map.options.initialCenter.longitude, -0.1278);
    });

    testWidgets('the label follows the map while panning', (tester) async {
      await _open(tester, start: _clapham);
      expect(find.text('Near Clapham'), findsOneWidget);

      // Dragging the map left moves its centre east, towards Brixton.
      await tester.drag(find.byType(FlutterMap), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(find.text('Near Brixton'), findsOneWidget);
    });

    testWidgets('"Jump to" moves the map to a district', (tester) async {
      await _open(tester, start: _clapham);

      expect(find.text('Jump to'), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, 'Brixton'));
      await tester.pumpAndSettle();

      expect(find.text('Near Brixton'), findsOneWidget);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.mapController!.camera.center.latitude, 51.4613);
      expect(map.mapController!.camera.center.longitude, -0.1156);
    });

    testWidgets('"Set starting point" returns the centre, rounded as the server stores it',
        (tester) async {
      final harness = await _open(tester, start: _brixton);

      await _tapSave(tester);

      expect(harness.popped, isTrue);
      final pinned = harness.choice as StartPointPinned;
      expect(pinned.point, const GeoPoint(latitude: 51.461, longitude: -0.116));
      expect(pinned.toString(), isNot(contains('51.')));
    });

    testWidgets('"Use city centre" returns the city centre choice', (tester) async {
      final harness = await _open(tester, start: _clapham);

      await tester.ensureVisible(find.text('Use city centre'));
      await tester.tap(find.text('Use city centre'));
      await tester.pumpAndSettle();

      expect(harness.choice, isA<StartPointCityCentre>());
    });

    testWidgets('going back returns nothing', (tester) async {
      final harness = await _open(tester, start: _clapham);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(harness.popped, isTrue);
      expect(harness.choice, isNull);
    });

    testWidgets('outside the city disables Save until the pin is back inside', (tester) async {
      await _open(tester, start: _brighton);

      expect(find.text('Outside London'), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNull);

      await tester.tap(find.widgetWithText(ActionChip, 'Clapham'));
      await tester.pumpAndSettle();

      expect(find.text('Near Clapham'), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('"Use my location" moves the map and sends nothing', (tester) async {
      final location = _FakeLocationService(const LocationFix(_brixton));
      final harness = await _open(tester, start: _clapham, location: location);

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(location.calls, 1);
      expect(find.text('Near Brixton'), findsOneWidget);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.mapController!.camera.center.latitude, _brixton.latitude);
      expect(map.mapController!.camera.center.longitude, _brixton.longitude);
      // The only request is the districts list; the position went nowhere.
      expect(harness.api.requests.map((r) => '${r.method} ${r.path}'), [_districtsPath]);
      expect(harness.api.requests.single.data, isNull);
      expect(harness.popped, isFalse);
    });

    testWidgets('refusing permission leaves the map, chips and Save working', (tester) async {
      final location = _FakeLocationService(const LocationRefused());
      final harness = await _open(tester, start: _clapham, location: location);

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(
        find.text('Location access is off. You can still move the map to your starting point.'),
        findsOneWidget,
      );
      expect(find.text('Near Clapham'), findsOneWidget);
      expect(find.text('Use my location'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Brixton'));
      await tester.pumpAndSettle();
      expect(find.text('Near Brixton'), findsOneWidget);

      await _tapSave(tester);
      expect(harness.choice, isA<StartPointPinned>());
    });

    testWidgets('no position fix says so and keeps the map where it was', (tester) async {
      await _open(tester,
          start: _clapham, location: _FakeLocationService(const LocationUnavailable()));

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(
        find.text('We couldn\'t find your location. You can still move the map to your '
            'starting point.'),
        findsOneWidget,
      );
      expect(find.text('Near Clapham'), findsOneWidget);
    });

    testWidgets('without districts the pin can still be set', (tester) async {
      final harness = _Harness(FakeDatePreferencesApi(responses: {_districtsPath: <Object>[]}));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          datePreferencesRepositoryProvider.overrideWithValue(
            DatePreferencesRepository(apiClient: harness.api, logger: Logger(level: Level.off)),
          ),
          mapTilesProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: StartPointMapScreen(city: _london, cityName: 'London')),
      ));
      await tester.pumpAndSettle();

      expect(find.text('In London'), findsOneWidget);
      expect(find.text('Jump to'), findsNothing);
      expect(_saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('a local build without tiles shows the grey placeholder', (tester) async {
      await _open(tester, start: _clapham);

      expect(find.byType(TileLayer), findsNothing);
      expect(find.textContaining('No map tiles in this build'), findsOneWidget);
    });

    testWidgets('configured tiles always show their attribution', (tester) async {
      await _open(
        tester,
        start: _clapham,
        tiles: const MapTiles(
          urlTemplate: 'https://tiles.example.test/{z}/{x}/{y}.png?key={key}',
          key: 'test-key',
          attribution: '© Example © OpenStreetMap contributors',
        ),
      );

      final layer = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(layer.urlTemplate, 'https://tiles.example.test/{z}/{x}/{y}.png?key={key}');
      expect(layer.additionalOptions, {'key': 'test-key'});
      expect(find.text('© Example © OpenStreetMap contributors'), findsOneWidget);

      await tester.drag(find.byType(FlutterMap), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('© Example © OpenStreetMap contributors'), findsOneWidget);
    });
  });
}
