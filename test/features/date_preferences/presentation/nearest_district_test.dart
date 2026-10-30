import 'package:eros_app/features/date_preferences/domain/models/city_district.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/presentation/widgets/nearest_district.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_date_preferences_api.dart';

/// The cases the backend's `DistrictLocator` (DP-B4) also passes. The fixture is a copy of
/// eros-backend `docs/tasks/date-preferences/nearest-district-cases.json`; copy it again when
/// that file changes.
final _shared = dpFixture('nearest_district_cases') as Map<String, dynamic>;

GeoPoint _point(Map<String, dynamic> json) => GeoPoint.fromJson(json);

GeoPoint _centre(Map<String, dynamic> city) {
  final centre = city['centre'] as List<dynamic>;
  return GeoPoint(latitude: (centre[0] as num).toDouble(), longitude: (centre[1] as num).toDouble());
}

List<CityDistrict> _districts(Map<String, dynamic> city) => (city['districts'] as List<dynamic>)
    .map((d) => CityDistrict.fromJson(d as Map<String, dynamic>))
    .toList();

void main() {
  test('uses the shared Earth radius', () {
    expect(earthRadiusMeters, _shared['earthRadiusMeters']);
  });

  group('every shared case', () {
    final cities = _shared['cities'] as Map<String, dynamic>;
    final cases = _shared['cases'] as List<dynamic>;

    test('there are cases to run', () => expect(cases, hasLength(18)));

    for (final c in cases.cast<Map<String, dynamic>>()) {
      final city = cities[c['city']] as Map<String, dynamic>;
      final expected = c['expected'] as Map<String, dynamic>;

      test('${c['city']}: ${c['description']}', () {
        final pin = _point(c['pin'] as Map<String, dynamic>);

        expect(roundPoint(pin), _point(c['rounded'] as Map<String, dynamic>));

        final lookup = nearestDistrict(
          pin: pin,
          cityCentre: _centre(city),
          reachMeters: city['reachMeters'] as int,
          districts: _districts(city),
        );

        if (expected['error'] == 'OUTSIDE_CITY') {
          expect(lookup, isA<OutsideCity>());
        } else {
          final near = lookup as NearDistrict;
          expect(near.district.districtId, expected['districtId']);
          expect(near.district.name, expected['name']);
          expect(near.distanceMeters, closeTo((expected['distanceMeters'] as num).toDouble(), 1));
        }
      });
    }
  });

  group('roundCoordinate', () {
    test('rounds negative halves towards positive infinity, unlike Dart\'s round()', () {
      expect(roundCoordinate(-95.3655), -95.365);
      expect((-95.3655 * 1000).round() / 1000, -95.366);
    });

    test('is stable on an already rounded value', () {
      for (final v in [51.461, -0.116, 29.747, -95.365, 40.0]) {
        expect(roundCoordinate(v), v);
      }
    });
  });

  group('nearestDistrict', () {
    const london = GeoPoint(latitude: 51.5074, longitude: -0.1278);
    const woodlands = GeoPoint(latitude: 30.166, longitude: -95.461);
    const houston = GeoPoint(latitude: 29.7604, longitude: -95.3698);

    test('takes the reach as a parameter, never a fixed 40 km', () {
      // The Woodlands is about 46 km from downtown Houston.
      expect(
        nearestDistrict(pin: woodlands, cityCentre: houston, reachMeters: 40000, districts: []),
        isA<OutsideCity>(),
      );
      expect(
        nearestDistrict(pin: woodlands, cityCentre: houston, reachMeters: 70000, districts: []),
        isA<NoDistricts>(),
      );
    });

    test('a city with no districts gives NoDistricts inside its reach', () {
      expect(
        nearestDistrict(pin: london, cityCentre: london, reachMeters: 40000, districts: []),
        isA<NoDistricts>(),
      );
    });

    test('a tie goes to the lowest id whatever order the districts come in', () {
      const pin = GeoPoint(latitude: 40.0, longitude: -75.0);
      final districts = [
        const CityDistrict(districtId: 11, name: 'West', latitude: 40.0, longitude: -75.01),
        const CityDistrict(districtId: 10, name: 'East', latitude: 40.0, longitude: -74.99),
      ];
      for (final order in [districts, districts.reversed.toList()]) {
        final near = nearestDistrict(
          pin: pin,
          cityCentre: pin,
          reachMeters: 40000,
          districts: order,
        ) as NearDistrict;
        expect(near.district.districtId, 10);
      }
    });
  });
}
