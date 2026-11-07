import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_patch.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_values.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preferences.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preference_options_provider.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_provider.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../fake_match_preferences_api.dart';

const _preferencesPath = '/users/me/match-preferences';

ProviderContainer _container(FakeMatchPreferencesApi api) {
  final container = ProviderContainer(overrides: [
    matchPreferencesRepositoryProvider.overrideWithValue(
      MatchPreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
    ),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// Holds each GET, and each PATCH when [holdPatches], until the test answers it, so responses can
/// land out of order.
class _HeldApi extends FakeMatchPreferencesApi {
  _HeldApi({this.holdPatches = false})
      : super(responses: {'GET $_preferencesPath': mpFixture('get_users_me_match_preferences')});

  final bool holdPatches;
  final held = <Completer<void>>[];
  final heldPatches = <Completer<void>>[];

  @override
  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (holdPatches) {
      final answer = Completer<void>();
      heldPatches.add(answer);
      await answer.future;
    }
    return super.patch<T>(path, data: data, queryParameters: queryParameters, options: options);
  }

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    final answer = Completer<void>();
    held.add(answer);
    await answer.future;
    return super.get<T>(path, queryParameters: queryParameters, options: options);
  }
}

void main() {
  group('matchPreferencesProvider', () {
    test('loads the user\'s preferences', () async {
      final api = FakeMatchPreferencesApi(responses: {
        'GET $_preferencesPath': mpFixture('get_users_me_match_preferences_defaults'),
      });

      final preferences = await _container(api).read(matchPreferencesProvider.future);

      expect(preferences.isSet, isFalse);
    });

    test('save replaces state with the server\'s response, without a refetch', () async {
      final saved = mpFixture('get_users_me_match_preferences') as Map<String, dynamic>;
      // The server's answer differs from what was sent, so a local merge would show.
      saved['religion'] = {
        'values': null,
        'dealbreaker': true,
      };
      final api = FakeMatchPreferencesApi(responses: {
        'GET $_preferencesPath': mpFixture('get_users_me_match_preferences_defaults'),
        'PATCH $_preferencesPath': saved,
      });
      final container = _container(api);
      await container.read(matchPreferencesProvider.future);

      final returned = await container.read(matchPreferencesProvider.notifier).save(
            ReligionPatch(ValueFilter(values: FilterValues.religion.choices, dealbreaker: true)),
          );

      final after = container.read(matchPreferencesProvider).requireValue;
      expect(after, MatchPreferences.fromJson(saved));
      expect(returned, after);
      expect(after.religion.values, isNull);
      expect(after.isSet, isTrue);
      expect(api.requests.map((r) => r.method), ['GET', 'PATCH']);
    });

    test('save keeps the previous state and rethrows the server\'s message on a 400', () async {
      final api = FakeMatchPreferencesApi(responses: {
        'GET $_preferencesPath': mpFixture('get_users_me_match_preferences_defaults'),
      });
      final container = _container(api);
      final before = await container.read(matchPreferencesProvider.future);
      api.error = const ValidationException('Choose who you\'re interested in first');

      await expectLater(
        container
            .read(matchPreferencesProvider.notifier)
            .save(const AgePatch(RangeFilter(min: 20, max: 30, dealbreaker: true))),
        throwsA(isA<MatchPreferencesValidationException>()
            .having((e) => e.message, 'message', 'Choose who you\'re interested in first')),
      );
      expect(container.read(matchPreferencesProvider).requireValue, before);
    });

    test('a load that lands after a save doesn\'t replace it', () async {
      final api = _HeldApi()
        ..responses['PATCH $_preferencesPath'] =
            mpFixture('get_users_me_match_preferences_defaults');
      final container = _container(api);
      final first = container.read(matchPreferencesProvider.future);
      api.held.single.complete();
      await first;

      final reload = container.read(matchPreferencesProvider.notifier).load();
      await container.read(matchPreferencesProvider.notifier).save(GenderPatch([Gender.male]));
      api.held.last.complete();
      await reload;

      expect(container.read(matchPreferencesProvider).requireValue.isSet, isFalse);
    });

    test('the first load doesn\'t replace a save that lands before it', () async {
      final api = _HeldApi()
        ..responses['PATCH $_preferencesPath'] =
            mpFixture('get_users_me_match_preferences_defaults');
      final container = _container(api);
      final subscription = container.listen(matchPreferencesProvider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(matchPreferencesProvider.notifier).save(GenderPatch([Gender.male]));
      final firstGet = api.held.single;
      firstGet.complete();
      // The GET's answer is in only once the held request has returned to the notifier.
      await firstGet.future;
      await pumpEventQueue();

      expect(container.read(matchPreferencesProvider).requireValue.isSet, isFalse);
    });
    test('saves run one at a time, in order', () async {
      final api = _HeldApi(holdPatches: true)
        ..responses['PATCH $_preferencesPath'] =
            mpFixture('get_users_me_match_preferences_defaults');
      final container = _container(api);
      final first = container.read(matchPreferencesProvider.future);
      api.held.single.complete();
      await first;
      final notifier = container.read(matchPreferencesProvider.notifier);

      final male = notifier.save(GenderPatch([Gender.male]));
      final female = notifier.save(GenderPatch([Gender.female]));
      await pumpEventQueue();
      expect(api.heldPatches, hasLength(1));

      api.heldPatches.single.complete();
      await male;
      await pumpEventQueue();
      expect(api.heldPatches, hasLength(2));
      api.heldPatches.last.complete();
      await female;

      expect(api.requests.where((r) => r.method == 'PATCH').map((r) => r.data), [
        GenderPatch([Gender.male]).toJson(),
        GenderPatch([Gender.female]).toJson(),
      ]);
    });

    test('a failed save doesn\'t stop the next one', () async {
      final api = _HeldApi(holdPatches: true)
        ..responses['PATCH $_preferencesPath'] =
            mpFixture('get_users_me_match_preferences_defaults');
      final container = _container(api);
      final first = container.read(matchPreferencesProvider.future);
      api.held.single.complete();
      await first;
      final notifier = container.read(matchPreferencesProvider.notifier);

      final failed = notifier.save(GenderPatch([Gender.male]));
      final next = notifier.save(GenderPatch([Gender.female]));
      api.error = const ValidationException('Choose who you\'re interested in first');
      await pumpEventQueue();
      api.heldPatches.single.complete();
      await expectLater(failed, throwsA(isA<MatchPreferencesValidationException>()));

      api.error = null;
      await pumpEventQueue();
      api.heldPatches.last.complete();
      await next;

      expect(container.read(matchPreferencesProvider).requireValue.isSet, isFalse);
    });
  });

  group('matchPreferenceOptionsProvider', () {
    test('loads the options', () async {
      final api = FakeMatchPreferencesApi(responses: {
        'GET /match-preferences/options': mpFixture('get_match_preferences_options'),
      });
      final container = _container(api);
      final subscription = container.listen(matchPreferenceOptionsProvider, (_, _) {});
      addTearDown(subscription.close);

      final options = await container.read(matchPreferenceOptionsProvider.future);

      expect(options.suggestedGenders, [Gender.female]);
    });
  });
}
