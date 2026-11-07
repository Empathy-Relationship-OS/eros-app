import 'package:eros_app/features/match_preferences/domain/models/filter_patch.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_values.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preference_options.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preferences.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_match_preferences_api.dart';

void main() {
  group('MatchPreferences', () {
    test('round-trips the RFC-007 §5 example', () {
      final json = mpFixture('get_users_me_match_preferences') as Map<String, dynamic>;

      expect(MatchPreferences.fromJson(json).toJson(), json);
    });

    test('round-trips the defaults for a user with no row', () {
      final json = mpFixture('get_users_me_match_preferences_defaults') as Map<String, dynamic>;

      final preferences = MatchPreferences.fromJson(json);

      expect(preferences.toJson(), json);
      expect(preferences.isSet, isFalse);
      expect(preferences.gender.values, isEmpty);
      expect(preferences.distance.isAnywhere, isTrue);
    });

    test('parses values into the profile enums', () {
      final preferences = MatchPreferences.fromJson(
          mpFixture('get_users_me_match_preferences') as Map<String, dynamic>);

      expect(preferences.gender.values, [Gender.female]);
      expect(preferences.relationshipType.values, [RelationshipType.monogamous]);
      expect(preferences.dateIntentions.values,
          [DateIntentions.seriousDating, DateIntentions.notSure]);
      expect(preferences.smokingStatus.values, [SmokingStatus.never, SmokingStatus.quitting]);
      expect(preferences.smokingStatus.dealbreaker, isTrue);
      expect(preferences.age, const RangeFilter(min: 24, max: 32, dealbreaker: true));
      expect(preferences.distance.maxMeters, 8047);
    });

    test('keeps values: null as open to all, not an empty list', () {
      final preferences = MatchPreferences.fromJson(
          mpFixture('get_users_me_match_preferences') as Map<String, dynamic>);

      expect(preferences.ethnicity.values, isNull);
      expect(preferences.ethnicity.isOpenToAll, isTrue);
      expect(preferences.ethnicity.toJson(), {'values': null, 'dealbreaker': false});
      expect(preferences.height.isOpenToAll, isTrue);
    });

    test('drops an unknown value and reports the filter, not the value', () {
      final json = mpFixture('get_users_me_match_preferences') as Map<String, dynamic>;
      json['religion'] = {
        'values': ['BUDDHISM', 'PASTAFARIAN'],
        'dealbreaker': false,
      };
      json['smokingStatus'] = {
        'values': ['NEVER', 'VAPING', 'PREFER_NOT_TO_SAY'],
        'dealbreaker': true,
      };
      final dropped = <(String, int)>[];

      final preferences =
          MatchPreferences.fromJson(json, onDropped: (filter, count) => dropped.add((filter, count)));

      expect(preferences.religion.values, [Religion.buddhism]);
      expect(preferences.smokingStatus.values, [SmokingStatus.never]);
      expect(dropped, [('religion', 1), ('smokingStatus', 2)]);
    });

    test('copyWith replaces one filter and can clear values to open to all', () {
      final preferences = MatchPreferences.fromJson(
          mpFixture('get_users_me_match_preferences') as Map<String, dynamic>);

      final changed = preferences.copyWith(
        smokingStatus: preferences.smokingStatus.copyWith(clearValues: true),
      );

      expect(changed.smokingStatus, ValueFilter<SmokingStatus>(values: null, dealbreaker: true));
      expect(changed.copyWith(smokingStatus: preferences.smokingStatus), preferences);
      expect(changed.toString(), isNot(contains('NEVER')));
    });
  });

  group('MatchPreferenceOptions', () {
    test('round-trips the RFC-007 §5 example', () {
      final json = mpFixture('get_match_preferences_options') as Map<String, dynamic>;

      final options = MatchPreferenceOptions.fromJson(json);

      expect(options.toJson(), json);
      expect(options.age.defaultRange, const AgeRange(min: 24, max: 34));
      expect(options.distance.from, 'Clapham');
      expect(options.suggestedGenders, [Gender.female]);
    });

    test('keeps a null from and drops an unknown suggested gender', () {
      final json = mpFixture('get_match_preferences_options') as Map<String, dynamic>;
      (json['distance'] as Map<String, dynamic>)['from'] = null;
      json['suggestedGenders'] = ['MALE', 'AGENDER'];
      final dropped = <(String, int)>[];

      final options = MatchPreferenceOptions.fromJson(json,
          onDropped: (filter, count) => dropped.add((filter, count)));

      expect(options.distance.from, isNull);
      expect(options.suggestedGenders, [Gender.male]);
      expect(dropped, [('suggestedGenders', 1)]);
    });
  });

  group('FilterValues', () {
    test('uses the backend enum names', () {
      String names(FilterChoices<Enum> c) => c.choices.map(filterValueName).join(' ');

      expect(names(FilterValues.gender), 'MALE FEMALE NON_BINARY OTHER');
      expect(names(FilterValues.ethnicity),
          'BLACK_AFRICAN_DESCENT EAST_ASIAN HISPANIC_LATINO MIDDLE_EASTERN NATIVE_AMERICAN '
          'PACIFIC_ISLANDER SOUTH_ASIAN SOUTHEAST_ASIAN WHITE_CAUCASIAN OTHER');
      expect(names(FilterValues.religion),
          'CHRISTIANITY ISLAM HINDUISM BUDDHISM JUDAISM SIKHISM ATHEIST AGNOSTIC SPIRITUAL OTHER');
      expect(names(FilterValues.relationshipType), 'MONOGAMOUS NON_MONOGAMOUS OPEN');
      expect(names(FilterValues.dateIntentions),
          'CASUAL_DATING SERIOUS_DATING FRIENDSHIP NETWORKING NOT_SURE');
      expect(names(FilterValues.kidsPreference), 'WANT_KIDS DONT_WANT_KIDS HAVE_KIDS OPEN_TO_KIDS');
      expect(names(FilterValues.smokingStatus), 'NEVER SOMETIMES REGULARLY QUITTING');
      expect(names(FilterValues.alcoholConsumption), 'NEVER SOMETIMES REGULARLY');
    });

    test('never offers Prefer not to say', () {
      expect(FilterValues.kidsPreference.choices, isNot(contains(KidsPreference.preferNotToSay)));
      expect(FilterValues.religion.parse('PREFER_NOT_TO_SAY'), isNull);
    });

    test('a value filter never sends Prefer not to say', () {
      final filter = ValueFilter(
        values: [Religion.preferNotToSay, Religion.atheist],
        dealbreaker: true,
      );

      expect(filter.values, [Religion.atheist]);
      expect(ReligionPatch(filter).toJson(), {
        'religion': {'values': ['ATHEIST'], 'dealbreaker': true},
      });
    });
  });

  group('FilterPatch', () {
    final valueFilter = ValueFilter<Ethnicity>(values: null, dealbreaker: false);

    test('each case produces a body with only its key', () {
      final patches = <FilterPatch, Map<String, dynamic>>{
        GenderPatch([Gender.female, Gender.nonBinary]): {
          'gender': {
            'values': ['FEMALE', 'NON_BINARY'],
            'dealbreaker': true,
          },
        },
        const AgePatch(RangeFilter(min: 24, max: 32, dealbreaker: false)): {
          'age': {'min': 24, 'max': 32, 'dealbreaker': false},
        },
        const HeightPatch(HeightFilter(minCm: 160, maxCm: 190, dealbreaker: true)): {
          'height': {'minCm': 160, 'maxCm': 190, 'dealbreaker': true},
        },
        const DistancePatch(DistanceFilter.anywhere()): {
          'distance': {'maxMeters': null, 'dealbreaker': false},
        },
        EthnicityPatch(valueFilter): {
          'ethnicity': {'values': null, 'dealbreaker': false},
        },
        ReligionPatch(ValueFilter(values: [Religion.atheist, Religion.agnostic], dealbreaker: true)):
            {
          'religion': {
            'values': ['ATHEIST', 'AGNOSTIC'],
            'dealbreaker': true,
          },
        },
        RelationshipTypePatch(
            ValueFilter(values: [RelationshipType.nonMonogamous], dealbreaker: false)): {
          'relationshipType': {
            'values': ['NON_MONOGAMOUS'],
            'dealbreaker': false,
          },
        },
        DateIntentionsPatch(ValueFilter(values: [DateIntentions.notSure], dealbreaker: false)): {
          'dateIntentions': {
            'values': ['NOT_SURE'],
            'dealbreaker': false,
          },
        },
        KidsPreferencePatch(ValueFilter(values: [KidsPreference.dontWantKids], dealbreaker: true)):
            {
          'kidsPreference': {
            'values': ['DONT_WANT_KIDS'],
            'dealbreaker': true,
          },
        },
        SmokingStatusPatch(ValueFilter(values: [SmokingStatus.never], dealbreaker: true)): {
          'smokingStatus': {
            'values': ['NEVER'],
            'dealbreaker': true,
          },
        },
        const AlcoholConsumptionPatch(ValueFilter.openToAll()): {
          'alcoholConsumption': {'values': null, 'dealbreaker': false},
        },
      };

      for (final MapEntry(key: patch, value: body) in patches.entries) {
        expect(patch.toJson(), body, reason: patch.filter);
        expect(patch.toJson().keys, [patch.filter]);
      }
      // One case per filter in the GET body.
      final filters = (mpFixture('get_users_me_match_preferences') as Map<String, dynamic>).keys
          .where((k) => k != 'isSet');
      expect(patches.keys.map((p) => p.filter).toSet(), filters.toSet());
    });

    test('toString names the filter, not the values', () {
      final patch = ReligionPatch(ValueFilter(values: [Religion.islam], dealbreaker: true));

      expect(patch.toString(), 'ReligionPatch(religion)');
    });
  });
}
