import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/domain/models/section_patch.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preference_options_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../fake_date_preferences_api.dart';

const _preferencesPath = '/users/me/date-preferences';

ProviderContainer _container(FakeDatePreferencesApi api) {
  final container = ProviderContainer(overrides: [
    datePreferencesRepositoryProvider.overrideWithValue(
      DatePreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
    ),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('datePreferencesProvider', () {
    test('loads the user\'s preferences', () async {
      final api = FakeDatePreferencesApi(responses: {
        'GET $_preferencesPath': dpFixture('get_users_me_date_preferences'),
      });

      final preferences = await _container(api).read(datePreferencesProvider.future);

      expect(preferences.isSet, isTrue);
    });

    test('saveSection replaces state with the server\'s response, without a refetch', () async {
      final saved = dpFixture('get_users_me_date_preferences') as Map<String, dynamic>;
      // The server's answer differs from what was sent, so a local merge would show.
      (saved['venue'] as Map<String, dynamic>)['atmosphere'] = 'LIVELY';
      final api = FakeDatePreferencesApi(responses: {
        'GET $_preferencesPath': dpFixture('get_users_me_date_preferences'),
        'PATCH $_preferencesPath': saved,
      });
      final container = _container(api);
      final before = await container.read(datePreferencesProvider.future);

      await container.read(datePreferencesProvider.notifier).saveSection(
            VenuePatch(before.venue.copyWith(needsStepFree: true)),
          );

      final after = container.read(datePreferencesProvider).requireValue;
      expect(after, DatePreferences.fromJson(saved));
      expect(after.venue.atmosphere, 'LIVELY');
      expect(after.venue.needsStepFree, isFalse);
      expect(api.requests.map((r) => r.method), ['GET', 'PATCH']);
    });

    test('saveSection keeps the previous state and rethrows the server\'s message on a 400',
        () async {
      final api = FakeDatePreferencesApi(responses: {
        'GET $_preferencesPath': dpFixture('get_users_me_date_preferences'),
      });
      final container = _container(api);
      final before = await container.read(datePreferencesProvider.future);
      api.error = const ValidationException('Pick at least one price range');

      await expectLater(
        container
            .read(datePreferencesProvider.notifier)
            .saveSection(VenuePatch(before.venue.copyWith(priceRanges: []))),
        throwsA(isA<DatePreferencesValidationException>()
            .having((e) => e.message, 'message', 'Pick at least one price range')),
      );
      expect(container.read(datePreferencesProvider).requireValue, before);
    });

    test('load fetches again', () async {
      final api = FakeDatePreferencesApi(responses: {
        'GET $_preferencesPath': dpFixture('get_users_me_date_preferences'),
      });
      final container = _container(api);
      await container.read(datePreferencesProvider.future);

      await container.read(datePreferencesProvider.notifier).load();

      expect(api.requests.length, 2);
      expect(container.read(datePreferencesProvider).hasValue, isTrue);
    });
  });

  group('datePreferenceOptionsProvider', () {
    test('fetches each city once', () async {
      final api = FakeDatePreferencesApi(responses: {
        'GET /date-preferences/options?cityId=1': dpFixture('get_date_preferences_options'),
      });
      final container = _container(api);

      await container.read(datePreferenceOptionsProvider(1).future);
      final options = await container.read(datePreferenceOptionsProvider(1).future);

      expect(options.cuisines.single.value, 'THAI');
      expect(api.requests.length, 1);
    });
  });

  group('cityDistrictsProvider', () {
    test('loads the city\'s districts', () async {
      final api = FakeDatePreferencesApi(responses: {
        'GET /city/1/districts': dpFixture('get_city_districts'),
      });

      final districts = await _container(api).read(cityDistrictsProvider(1).future);

      expect(districts.length, 2);
    });
  });
}
