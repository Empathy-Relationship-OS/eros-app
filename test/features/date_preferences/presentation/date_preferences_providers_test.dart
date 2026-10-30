import 'dart:async';

import 'package:dio/dio.dart';
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

/// Holds each GET until the test answers it, so responses can land out of order.
class _HeldApi extends FakeDatePreferencesApi {
  _HeldApi()
      : super(responses: {'GET $_preferencesPath': dpFixture('get_users_me_date_preferences')});

  final held = <Completer<void>>[];

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    final answer = Completer<void>();
    held.add(answer);
    await answer.future;
    return super.get<T>(path, queryParameters: queryParameters, options: options);
  }
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

    test('a load that finishes after a newer one is ignored', () async {
      final api = _HeldApi();
      final container = _container(api);
      final initial = container.read(datePreferencesProvider.future);
      api.held.single.complete();
      await initial;
      final notifier = container.read(datePreferencesProvider.notifier);

      final first = notifier.load();
      final retry = notifier.load();
      api.held[2].complete();
      await retry;
      api.held[1].completeError(const ServerException('Server error'));
      await first;

      final state = container.read(datePreferencesProvider);
      expect(state.hasError, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.hasValue, isTrue);
    });

    test('a load that finishes after a save is ignored', () async {
      final api = _HeldApi()
        ..responses['PATCH $_preferencesPath'] = dpFixture('get_users_me_date_preferences');
      final container = _container(api);
      final initial = container.read(datePreferencesProvider.future);
      api.held.single.complete();
      final before = await initial;
      final notifier = container.read(datePreferencesProvider.notifier);

      final reload = notifier.load();
      final saved = await notifier.saveSection(VenuePatch(before.venue));
      api.held[1].completeError(const ServerException('Server error'));
      await reload;

      expect(container.read(datePreferencesProvider), AsyncData(saved));
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

    test('fetches the first city\'s options again after "Where" is saved, and only then',
        () async {
      final api = FakeDatePreferencesApi(responses: {
        'GET /date-preferences/options': dpFixture('get_date_preferences_options'),
        'GET /date-preferences/options?cityId=1': dpFixture('get_date_preferences_options'),
        'GET $_preferencesPath': dpFixture('get_users_me_date_preferences'),
        'PATCH $_preferencesPath': dpFixture('get_users_me_date_preferences'),
      });
      final container = _container(api);
      final before = await container.read(datePreferencesProvider.future);
      await container.read(datePreferenceOptionsProvider(null).future);
      await container.read(datePreferenceOptionsProvider(1).future);
      final notifier = container.read(datePreferencesProvider.notifier);

      await notifier.saveSection(VenuePatch(before.venue));
      await container.read(datePreferenceOptionsProvider(null).future);
      await notifier.saveSection(
        const WherePatch(cities: [WhereCityPatch(cityId: 1)], maxTravelMeters: null),
      );
      await container.read(datePreferenceOptionsProvider(null).future);
      await container.read(datePreferenceOptionsProvider(1).future);

      final optionReads = api.requests
          .map((r) => r.path)
          .where((p) => p.startsWith('/date-preferences/options'))
          .toList();
      expect(optionReads, [
        '/date-preferences/options',
        '/date-preferences/options?cityId=1',
        '/date-preferences/options',
      ]);
    });
    test('fetches first-city options again when "Where" saved with an unreadable response',
        () async {
      final api = FakeDatePreferencesApi(responses: {
        'GET /date-preferences/options': dpFixture('get_date_preferences_options'),
        'GET $_preferencesPath': dpFixture('get_users_me_date_preferences'),
        'PATCH $_preferencesPath': <String, dynamic>{'isSet': true},
      });
      final container = _container(api);
      await container.read(datePreferencesProvider.future);
      await container.read(datePreferenceOptionsProvider(null).future);

      await expectLater(
        container.read(datePreferencesProvider.notifier).saveSection(
              const WherePatch(cities: [WhereCityPatch(cityId: 1)], maxTravelMeters: null),
            ),
        throwsA(isA<DatePreferencesSavedException>()),
      );
      await container.read(datePreferenceOptionsProvider(null).future);

      final optionReads =
          api.requests.where((r) => r.path.startsWith('/date-preferences/options')).length;
      expect(optionReads, 2);
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
