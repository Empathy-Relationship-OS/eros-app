import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_patch.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preferences.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../fake_match_preferences_api.dart';

const _preferencesPath = '/users/me/match-preferences';
const _optionsPath = '/match-preferences/options';

/// Keeps every log line, so tests can check that no value is logged.
class _RecordingOutput extends LogOutput {
  final lines = <String>[];

  @override
  void output(OutputEvent event) => lines.addAll(event.lines);
}

MatchPreferencesRepository _repository(FakeMatchPreferencesApi api, [_RecordingOutput? output]) =>
    MatchPreferencesRepository(
      apiClient: api,
      logger: Logger(
        level: output == null ? Level.off : Level.all,
        printer: SimplePrinter(colors: false),
        output: output,
        filter: ProductionFilter(),
      ),
    );

void main() {
  group('get', () {
    test('returns the parsed preferences for a 200', () async {
      final api = FakeMatchPreferencesApi(responses: {
        'GET $_preferencesPath': mpFixture('get_users_me_match_preferences'),
      });

      final preferences = await _repository(api).get();

      expect(preferences.gender.values, [Gender.female]);
      expect(api.requests.single.path, _preferencesPath);
    });

    test('drops an unknown value and logs only the filter\'s name', () async {
      final body = mpFixture('get_users_me_match_preferences') as Map<String, dynamic>;
      body['religion'] = {
        'values': ['JUDAISM', 'NEW_FAITH'],
        'dealbreaker': false,
      };
      final api = FakeMatchPreferencesApi(responses: {'GET $_preferencesPath': body});
      final output = _RecordingOutput();

      final preferences = await _repository(api, output).get();

      expect(preferences.religion.values, [Religion.judaism]);
      expect(output.lines, contains(contains('Dropped 1 unknown value(s) from religion')));
      expect(output.lines.join('\n'), isNot(contains('NEW_FAITH')));
      expect(output.lines.join('\n'), isNot(contains('JUDAISM')));
    });

    test('turns an unreadable response into a MatchPreferencesRepositoryException', () async {
      final body = mpFixture('get_users_me_match_preferences') as Map<String, dynamic>
        ..remove('age');
      final api = FakeMatchPreferencesApi(responses: {'GET $_preferencesPath': body});

      await expectLater(
        _repository(api).get(),
        throwsA(isA<MatchPreferencesRepositoryException>()
            .having((e) => e.message, 'message', contains('couldn\'t load'))),
      );
    });

    test('turns a network failure into a MatchPreferencesRepositoryException', () async {
      final api = FakeMatchPreferencesApi(error: const NetworkException('offline'));

      await expectLater(
        _repository(api).get(),
        throwsA(isA<MatchPreferencesRepositoryException>()
            .having((e) => e.message, 'message', contains('Unable to connect'))),
      );
    });
  });

  group('patch', () {
    test('sends only the filter and returns the server\'s preferences', () async {
      final api = FakeMatchPreferencesApi(responses: {
        'PATCH $_preferencesPath': mpFixture('get_users_me_match_preferences'),
      });
      final output = _RecordingOutput();

      final saved = await _repository(api, output).patch(
        SmokingStatusPatch(ValueFilter(values: [SmokingStatus.never], dealbreaker: true)),
      );

      expect(api.requests.single.method, 'PATCH');
      expect(api.requests.single.data, {
        'smokingStatus': {
          'values': ['NEVER'],
          'dealbreaker': true,
        },
      });
      expect(saved.smokingStatus.values, [SmokingStatus.never, SmokingStatus.quitting]);
      expect(output.lines, contains(contains('Saving match preference: smokingStatus')));
      expect(output.lines.join('\n'), isNot(contains('NEVER')));
    });

    test('maps a 400 to MatchPreferencesValidationException with the server\'s message',
        () async {
      final api = FakeMatchPreferencesApi(
        error: const ValidationException('Choose who you\'re interested in first'),
      );

      await expectLater(
        _repository(api).patch(const AgePatch(RangeFilter(min: 24, max: 32, dealbreaker: true))),
        throwsA(isA<MatchPreferencesValidationException>().having(
            (e) => e.message, 'message', 'Choose who you\'re interested in first')),
      );
    });

    test('turns other failures into a MatchPreferencesRepositoryException', () async {
      for (final error in <ApiException>[
        const ServerException('boom'),
        const UnauthorizedException('expired'),
        const ForbiddenException('no'),
        const ConflictException('conflict'),
      ]) {
        final api = FakeMatchPreferencesApi(error: error);

        await expectLater(
          _repository(api).patch(GenderPatch([Gender.male])),
          throwsA(isA<MatchPreferencesRepositoryException>()
              .having((e) => e, 'exception', isNot(isA<MatchPreferencesSavedException>()))),
          reason: error.runtimeType.toString(),
        );
      }
    });

    test('says the change was saved when only the response is unreadable', () async {
      final api = FakeMatchPreferencesApi(responses: {
        'PATCH $_preferencesPath': <String, dynamic>{'isSet': true},
      });

      await expectLater(
        _repository(api).patch(GenderPatch([Gender.male])),
        throwsA(isA<MatchPreferencesSavedException>()
            .having((e) => e.message, 'message', contains('Your change was saved'))),
      );
    });
  });

  group('options', () {
    test('returns the parsed options for a 200', () async {
      final api = FakeMatchPreferencesApi(responses: {
        'GET $_optionsPath': mpFixture('get_match_preferences_options'),
      });

      final options = await _repository(api).options();

      expect(options.distance.stopsMeters.first, 1609);
      expect(api.requests.single.path, _optionsPath);
    });

    test('turns a server error into a MatchPreferencesRepositoryException', () async {
      final api = FakeMatchPreferencesApi(error: const ServerException('boom', statusCode: 503));

      await expectLater(
        _repository(api).options(),
        throwsA(isA<MatchPreferencesRepositoryException>()
            .having((e) => e.message, 'message', contains('options'))),
      );
    });
  });
}
