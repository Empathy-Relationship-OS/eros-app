import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/domain/models/section_patch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../fake_date_preferences_api.dart';

const _preferencesPath = '/users/me/date-preferences';

DatePreferencesRepository _repository(FakeDatePreferencesApi api) =>
    DatePreferencesRepository(apiClient: api, logger: Logger(level: Level.off));

void main() {
  group('get', () {
    test('returns the parsed preferences', () async {
      final api = FakeDatePreferencesApi(responses: {
        'GET $_preferencesPath': dpFixture('get_users_me_date_preferences'),
      });

      final preferences = await _repository(api).get();

      expect(preferences.levelFor(3), PreferenceLevel.love);
      expect(api.requests.single.path, _preferencesPath);
    });

    test('turns an unreadable response into a DatePreferencesRepositoryException', () async {
      final body = dpFixture('get_users_me_date_preferences') as Map<String, dynamic>
        ..remove('venue');
      final api = FakeDatePreferencesApi(responses: {'GET $_preferencesPath': body});

      await expectLater(
        _repository(api).get(),
        throwsA(isA<DatePreferencesRepositoryException>()
            .having((e) => e.message, 'message', contains('couldn\'t load'))),
      );
    });
  });

  group('patch', () {
    test('sends exactly the section and returns the server\'s preferences', () async {
      final api = FakeDatePreferencesApi(responses: {
        'PATCH $_preferencesPath': dpFixture('get_users_me_date_preferences'),
      });
      final patch = DrinksPatch(DrinksPreferences(drinkStyles: ['PUB'], wantsAlcoholFree: true));

      final saved = await _repository(api).patch(patch);

      expect(api.requests.single.data, {
        'drinks': {
          'drinkStyles': ['PUB'],
          'wantsAlcoholFree': true,
        },
      });
      expect(saved.drinks.drinkStyles, ['WINE_BAR']);
    });

    test('surfaces the server\'s message for a 400', () async {
      final api = FakeDatePreferencesApi(
        error: const ValidationException('At least one active date type must not be "Not for me"'),
      );

      await expectLater(
        _repository(api).patch(const ActivitiesPatch([])),
        throwsA(isA<DatePreferencesValidationException>().having((e) => e.message, 'message',
            'At least one active date type must not be "Not for me"')),
      );
    });

    test('turns other failures into a DatePreferencesRepositoryException', () async {
      final api = FakeDatePreferencesApi(error: const ServerException('boom'));

      await expectLater(
        _repository(api).patch(const ActivitiesPatch([])),
        throwsA(isA<DatePreferencesRepositoryException>()
            .having((e) => e.message, 'message', contains('couldn\'t save'))),
      );
    });

    test('says the change was saved when only the response is unreadable', () async {
      final api = FakeDatePreferencesApi(responses: {
        'PATCH $_preferencesPath': <String, dynamic>{'isSet': true},
      });

      await expectLater(
        _repository(api).patch(const ActivitiesPatch([])),
        throwsA(isA<DatePreferencesSavedException>()
            .having((e) => e.message, 'message', contains('Your changes were saved'))),
      );
    });
  });

  group('options', () {
    test('asks for the given city', () async {
      final api = FakeDatePreferencesApi(responses: {
        'GET /date-preferences/options?cityId=1': dpFixture('get_date_preferences_options'),
      });

      final options = await _repository(api).options(cityId: 1);

      expect(options.city!.cityId, 1);
    });

    test('asks for the user\'s first dating city without a cityId', () async {
      final api = FakeDatePreferencesApi(responses: {
        'GET /date-preferences/options': dpFixture('get_date_preferences_options'),
      });

      await _repository(api).options();

      expect(api.requests.single.path, '/date-preferences/options');
    });
  });

  group('districts', () {
    test('returns the city\'s districts', () async {
      final api = FakeDatePreferencesApi(responses: {
        'GET /city/1/districts': dpFixture('get_city_districts'),
      });

      final districts = await _repository(api).districts(1);

      expect(districts.map((d) => d.name), ['Brixton', 'Clapham']);
    });

    test('turns a network failure into a DatePreferencesRepositoryException', () async {
      final api = FakeDatePreferencesApi(error: const NetworkException('offline'));

      await expectLater(
        _repository(api).districts(1),
        throwsA(isA<DatePreferencesRepositoryException>()
            .having((e) => e.message, 'message', contains('Unable to connect'))),
      );
    });
  });
}
