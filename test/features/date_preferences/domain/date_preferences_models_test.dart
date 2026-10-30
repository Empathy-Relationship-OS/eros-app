import 'dart:convert';
import 'dart:io';

import 'package:eros_app/features/date_preferences/domain/models/city_district.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/domain/models/section_patch.dart';
import 'package:flutter_test/flutter_test.dart';

dynamic _fixture(String name) =>
    jsonDecode(File('test/fixtures/date_preferences/$name.json').readAsStringSync());

void main() {
  group('DatePreferences', () {
    test('round-trips the RFC-005 §5 example', () {
      final json = _fixture('get_users_me_date_preferences') as Map<String, dynamic>;

      expect(DatePreferences.fromJson(json).toJson(), json);
    });

    test('reads every section', () {
      final preferences = DatePreferences.fromJson(
          _fixture('get_users_me_date_preferences') as Map<String, dynamic>);

      expect(preferences.isSet, isTrue);
      expect(preferences.updatedAt, DateTime.utc(2026, 10, 27, 18, 4, 11));
      expect(preferences.where.cities.single.start!.district!.name, 'Clapham');
      expect(preferences.where.maxTravelMeters, 8047);
      expect(preferences.food.cuisinesExcluded, ['BRITISH']);
      expect(preferences.drinks.drinkStyles, ['WINE_BAR']);
      expect(preferences.venue.atmosphere, 'QUIET');
    });

    test('reads the defaults: no pin, anywhere, never saved', () {
      final json = _fixture('get_users_me_date_preferences') as Map<String, dynamic>;
      json['isSet'] = false;
      json['updatedAt'] = null;
      (json['where'] as Map<String, dynamic>)['maxTravelMeters'] = null;
      ((json['where'] as Map<String, dynamic>)['cities'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .single['start'] = null;
      json['activities'] = <dynamic>[];

      final preferences = DatePreferences.fromJson(json);

      expect(preferences.isSet, isFalse);
      expect(preferences.updatedAt, isNull);
      expect(preferences.where.maxTravelMeters, isNull);
      expect(preferences.where.cities.single.start, isNull);
      expect(preferences.toJson(), json);
    });

    group('levelFor', () {
      final preferences = DatePreferences.fromJson(
          _fixture('get_users_me_date_preferences') as Map<String, dynamic>);

      test('returns the level the user set', () {
        expect(preferences.levelFor(3), PreferenceLevel.love);
        expect(preferences.levelFor(1), PreferenceLevel.no);
      });

      test('defaults to OK for an activity without a row', () {
        expect(preferences.levelFor(2), PreferenceLevel.ok);
      });
    });

    test('rejects a level the app does not know', () {
      final json = _fixture('get_users_me_date_preferences') as Map<String, dynamic>;
      json['activities'] = [
        {'activityId': 3, 'level': 'MAYBE'},
      ];

      expect(() => DatePreferences.fromJson(json), throwsArgumentError);
    });

    test('copyWith can clear the travel distance and a pin', () {
      final preferences = DatePreferences.fromJson(
          _fixture('get_users_me_date_preferences') as Map<String, dynamic>);

      final where = preferences.where.copyWith(
        clearMaxTravelMeters: true,
        cities: [preferences.where.cities.single.copyWith(clearStart: true)],
      );

      expect(where.maxTravelMeters, isNull);
      expect(where.cities.single.start, isNull);
      expect(where.cities.single.cityName, 'London');
    });

    test('copies lists, so changing the caller\'s list later changes nothing', () {
      final preferences = DatePreferences.fromJson(
          _fixture('get_users_me_date_preferences') as Map<String, dynamic>);
      final styles = ['PUB'];
      final activities = [const ActivityPreference(activityId: 2, level: PreferenceLevel.love)];

      final drinks = DrinksPreferences(drinkStyles: styles);
      final food = preferences.food.copyWith(cuisinesExcluded: styles);
      final updated = preferences.copyWith(activities: activities);
      styles.add('WINE_BAR');
      activities.clear();

      expect(drinks.drinkStyles, ['PUB']);
      expect(food.cuisinesExcluded, ['PUB']);
      expect(updated.levelFor(2), PreferenceLevel.love);
      expect(() => drinks.drinkStyles.add('X'), throwsUnsupportedError);
    });

    test('keeps coordinates and sensitive values out of toString', () {
      final preferences = DatePreferences.fromJson(
          _fixture('get_users_me_date_preferences') as Map<String, dynamic>);
      final strings = [
        preferences.toString(),
        preferences.where.cities.single.start.toString(),
        preferences.food.toString(),
        preferences.venue.toString(),
      ].join(' ');

      expect(strings, isNot(contains('51.462')));
      expect(strings, isNot(contains('VEGETARIAN')));
      expect(strings, isNot(contains('needsStepFree')));
    });
  });

  group('DatePreferenceOptions', () {
    test('round-trips the RFC-005 §5 example', () {
      final json = _fixture('get_date_preferences_options') as Map<String, dynamic>;

      expect(DatePreferenceOptions.fromJson(json).toJson(), json);
    });

    test('keeps option values as strings with display names', () {
      final options = DatePreferenceOptions.fromJson(
          _fixture('get_date_preferences_options') as Map<String, dynamic>);

      expect(options.cuisines.single, const OptionValue(value: 'THAI', displayName: 'Thai'));
      expect(options.priceRanges.single.symbol, '££');
      expect(options.activities.single.tokenCost, 1.0);
      expect(options.city!.distanceUnit, 'MI');
      expect(options.city!.centre, const GeoPoint(latitude: 51.5074, longitude: -0.1278));
      expect(options.city!.reachMeters, 40000);
      expect(options.travelStops.map((s) => s.meters), [1609, 8047]);
      expect(options.limits.maxCuisinesExcluded, 5);
    });
  });

  group('CityDistrict', () {
    test('round-trips the districts list', () {
      final json = _fixture('get_city_districts') as List<dynamic>;

      final districts =
          json.map((d) => CityDistrict.fromJson(d as Map<String, dynamic>)).toList();

      expect(districts.map((d) => d.toJson()).toList(), json);
      expect(districts.last.name, 'Clapham');
    });
  });

  group('SectionPatch', () {
    final preferences = DatePreferences.fromJson(
        _fixture('get_users_me_date_preferences') as Map<String, dynamic>);

    test('WherePatch sends only where, each start as latitude and longitude or null', () {
      const patch = WherePatch(
        cities: [
          WhereCityPatch(cityId: 1, start: GeoPoint(latitude: 51.4621, longitude: -0.1384)),
          WhereCityPatch(cityId: 2),
        ],
        maxTravelMeters: null,
      );

      expect(patch.toJson(), {
        'where': {
          'cities': [
            {
              'cityId': 1,
              'start': {'latitude': 51.4621, 'longitude': -0.1384},
            },
            {'cityId': 2, 'start': null},
          ],
          'maxTravelMeters': null,
        },
      });
    });

    test('ActivitiesPatch sends only activities', () {
      final patch = ActivitiesPatch(preferences.activities);

      expect(patch.toJson(), {
        'activities': [
          {'activityId': 3, 'level': 'LOVE'},
          {'activityId': 1, 'level': 'NO'},
        ],
      });
    });

    test('FoodPatch sends only food', () {
      expect(FoodPatch(preferences.food).toJson(), {
        'food': {
          'cuisinesLoved': ['THAI', 'ITALIAN'],
          'cuisinesExcluded': ['BRITISH'],
          'dietaryNeeds': ['VEGETARIAN'],
        },
      });
    });

    test('DrinksPatch sends only drinks', () {
      expect(DrinksPatch(preferences.drinks).toJson(), {
        'drinks': {
          'drinkStyles': ['WINE_BAR'],
          'wantsAlcoholFree': false,
        },
      });
    });

    test('VenuePatch sends only venue', () {
      expect(VenuePatch(preferences.venue).toJson(), {
        'venue': {
          'priceRanges': ['MID_RANGE', 'PREMIUM'],
          'atmosphere': 'QUIET',
          'setting': 'EITHER',
          'needsStepFree': false,
        },
      });
    });
  });
}
