import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/devtools/data/devtools_api.dart';
import 'package:eros_app/features/devtools/data/devtools_exceptions.dart';
import 'package:eros_app/features/devtools/data/models/devtools_models.dart';

// JSON examples from RFC-003 §5.

const _clockJson = {
  'realTime': '2026-10-16T12:00:00Z',
  'serverTime': '2026-10-17T13:00:00Z',
  'offsetSeconds': 90000,
};

const _aliceJson = {
  'uid': 'dev_alice',
  'firstName': 'Alice',
  'gender': 'WOMAN',
  'city': 'London',
  'role': 'USER',
  'tokenBalance': 100,
};

const _opsJson = {
  'uid': 'dev_ops',
  'firstName': 'Ops',
  'gender': 'MAN',
  'city': 'London',
  'role': 'ADMIN',
  'tokenBalance': 0,
};

final Map<String, _Stub> _rfcStubs = {
  'GET /dev/health': const _Stub(200, {
    'enabled': true,
    'serverTime': '2026-10-17T13:00:00Z',
    'offsetSeconds': 90000,
  }),
  'GET /dev/clock': const _Stub(200, _clockJson),
  'POST /dev/clock/advance': const _Stub(200, _clockJson),
  'POST /dev/clock/advance-to': const _Stub(200, _clockJson),
  'POST /dev/clock/reset': const _Stub(200, {
    'realTime': '2026-10-16T12:00:00Z',
    'serverTime': '2026-10-16T12:00:00Z',
    'offsetSeconds': 0,
  }),
  'GET /dev/personas': const _Stub(200, [_aliceJson]),
  'POST /dev/personas': const _Stub(201, _aliceJson),
  'POST /dev/personas/standard': const _Stub(200, [_aliceJson, _opsJson]),
  'POST /dev/personas/dev_alice/token': const _Stub(200, {
    'uid': 'dev_alice',
    'role': 'USER',
    'customToken': 'eyJ.custom.token',
  }),
  'DELETE /dev/personas/dev_alice': const _Stub(204, null),
  'POST /dev/fixtures/venues': const _Stub(200, {
    'cityId': 1,
    'activityIds': [1],
    'venuesCreated': 3,
    'venuesExisting': 0,
  }),
  'POST /dev/reset': const _Stub(200, {
    'deletedPersonas': 6,
    'deletedMatches': 4,
    'deletedDates': 2,
    'skippedDates': [],
    'clock': {
      'realTime': '2026-10-16T12:00:00Z',
      'serverTime': '2026-10-16T12:00:00Z',
      'offsetSeconds': 0,
    },
  }),
  'GET /dev/scenarios': const _Stub(200, [
    {'name': 'date-booked', 'description': '...', 'endState': 'BOOKED'},
    {'name': 'match-served', 'description': '...', 'endState': null},
  ]),
  'POST /dev/scenarios/date-booked': const _Stub(200, {
    'scenario': 'date-booked',
    'personas': [_aliceJson, _aliceJson],
    'opsPersona': _opsJson,
    'matchId': 42,
    'dateId': 17,
    'dateState': 'BOOKED',
    'loginAs': 'dev_s1a2b3_a',
    'notes': [
      'Date starts 2026-10-18T19:00:00Z. Advance the clock 25h to open the presence window.',
    ],
  }),
  'POST /dev/scenarios/match-served': const _Stub(200, {
    'scenario': 'match-served',
    'personas': [_aliceJson, _aliceJson],
    'opsPersona': null,
    'matchId': null,
    'dateId': null,
    'dateState': null,
    'loginAs': 'dev_s1a2b3_a',
    'notes': [],
  }),
};

void main() {
  late _FakeAdapter adapter;
  late DevtoolsApi api;

  setUp(() {
    adapter = _FakeAdapter(_rfcStubs);
    api = DevtoolsApi(
      devKey: 'test-dev-key-123456',
      baseUrl: 'http://devtools.test',
      httpClientAdapter: adapter,
    );
  });

  group('headers', () {
    test('sends X-Dev-Key and no Authorization header on every call', () async {
      await api.health();
      await api.listPersonas();
      await api.runScenario('date-booked');

      expect(adapter.requests, hasLength(3));
      for (final request in adapter.requests) {
        expect(request.headers[DevtoolsApi.devKeyHeader], 'test-dev-key-123456');
        final headerNames = request.headers.keys.map((k) => k.toLowerCase());
        expect(headerNames, isNot(contains('authorization')));
      }
    });

    test('targets the configured base URL', () async {
      await api.getClock();
      expect(adapter.requests.single.uri.toString(), 'http://devtools.test/dev/clock');
    });
  });

  group('health', () {
    test('parses the RFC example', () async {
      final health = await api.health();
      expect(health.enabled, isTrue);
      expect(health.serverTime, DateTime.utc(2026, 10, 17, 13));
      expect(health.offsetSeconds, 90000);
      expect(health.offset, const Duration(hours: 25));
    });

    test('a 404 raises DevtoolsDisabledException', () async {
      adapter.stubs['GET /dev/health'] = const _Stub(404, null);
      await expectLater(api.health(), throwsA(isA<DevtoolsDisabledException>()));
    });

    test('DevtoolsDisabledException is still a NotFoundException', () async {
      adapter.stubs['GET /dev/health'] = const _Stub(404, null);
      await expectLater(api.health(), throwsA(isA<NotFoundException>()));
    });
  });

  group('clock', () {
    void expectRfcClock(ClockInfo clock) {
      expect(clock.realTime, DateTime.utc(2026, 10, 16, 12));
      expect(clock.serverTime, DateTime.utc(2026, 10, 17, 13));
      expect(clock.offsetSeconds, 90000);
      expect(clock.isShifted, isTrue);
    }

    test('getClock parses ClockDTO', () async {
      expectRfcClock(await api.getClock());
    });

    test('advanceClock posts days, hours and minutes', () async {
      expectRfcClock(await api.advanceClock(hours: 25));
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.data, {'days': 0, 'hours': 25, 'minutes': 0});
    });

    test('advanceClockTo posts an ISO-8601 UTC instant', () async {
      expectRfcClock(await api.advanceClockTo(DateTime.utc(2026, 10, 20, 18)));
      expect(adapter.requests.single.data, {'instant': '2026-10-20T18:00:00.000Z'});
    });

    test('resetClock returns a zero offset', () async {
      final clock = await api.resetClock();
      expect(clock.offsetSeconds, 0);
      expect(clock.isShifted, isFalse);
    });

    test('a 400 maps to ValidationException with the server message', () async {
      adapter.stubs['POST /dev/clock/advance'] = const _Stub(
        400,
        {'error': 'bad_request', 'message': 'total must be positive'},
      );
      await expectLater(
        api.advanceClock(),
        throwsA(isA<ValidationException>()
            .having((e) => e.message, 'message', 'total must be positive')),
      );
    });
  });

  group('personas', () {
    void expectAlice(Persona p) {
      expect(p.uid, 'dev_alice');
      expect(p.firstName, 'Alice');
      expect(p.gender, 'WOMAN');
      expect(p.city, 'London');
      expect(p.role, 'USER');
      expect(p.tokenBalance, 100);
      expect(p.isAdmin, isFalse);
    }

    test('listPersonas parses PersonaDTO[]', () async {
      final personas = await api.listPersonas();
      expectAlice(personas.single);
    });

    test('createPersona sends only the fields that are set', () async {
      expectAlice(await api.createPersona(
        const CreatePersonaRequest(handle: 'alice', gender: 'WOMAN', tokens: 100),
      ));
      expect(
        adapter.requests.single.data,
        {'handle': 'alice', 'gender': 'WOMAN', 'tokens': 100},
      );
    });

    test('createStandardPersonas parses the list including the ADMIN', () async {
      final personas = await api.createStandardPersonas();
      expect(personas.map((p) => p.uid), ['dev_alice', 'dev_ops']);
      expect(personas.last.isAdmin, isTrue);
    });

    test('getPersonaToken parses the custom token', () async {
      final token = await api.getPersonaToken('dev_alice');
      expect(token.uid, 'dev_alice');
      expect(token.role, 'USER');
      expect(token.customToken, 'eyJ.custom.token');
    });

    test('getPersonaToken 404 is a plain NotFoundException', () async {
      adapter.stubs['POST /dev/personas/dev_alice/token'] =
          const _Stub(404, {'error': 'not_found', 'message': 'no such user'});
      await expectLater(
        api.getPersonaToken('dev_alice'),
        throwsA(allOf(
          isA<NotFoundException>(),
          isNot(isA<DevtoolsDisabledException>()),
        )),
      );
    });

    test('deletePersona accepts 204', () async {
      await api.deletePersona('dev_alice');
      expect(adapter.requests.single.method, 'DELETE');
    });
  });

  group('fixtures and reset', () {
    test('createVenueFixtures parses the result', () async {
      final result = await api.createVenueFixtures();
      expect(result.cityId, 1);
      expect(result.activityIds, [1]);
      expect(result.venuesCreated, 3);
      expect(result.venuesExisting, 0);
    });

    test('reset parses ResetResult with its ClockDTO', () async {
      final result = await api.reset();
      expect(result.deletedPersonas, 6);
      expect(result.deletedMatches, 4);
      expect(result.deletedDates, 2);
      expect(result.skippedDates, isEmpty);
      expect(result.clock.offsetSeconds, 0);
    });
  });

  group('scenarios', () {
    test('listScenarios parses ScenarioInfo', () async {
      final scenarios = await api.listScenarios();
      expect(scenarios.first.name, 'date-booked');
      expect(scenarios.first.description, '...');
      expect(scenarios.first.endState, 'BOOKED');
      expect(scenarios.last.endState, isNull);
    });

    test('runScenario parses ScenarioResultDTO', () async {
      final result = await api.runScenario('date-booked', handles: ['alice', 'bob']);
      expect(result.scenario, 'date-booked');
      expect(result.personas, hasLength(2));
      expect(result.opsPersona?.uid, 'dev_ops');
      expect(result.matchId, 42);
      expect(result.dateId, 17);
      expect(result.dateState, 'BOOKED');
      expect(result.loginAs, 'dev_s1a2b3_a');
      expect(result.notes.single, startsWith('Date starts'));
      expect(adapter.requests.single.data, {
        'handles': ['alice', 'bob'],
      });
    });

    test('runScenario handles the nullable fields', () async {
      final result = await api.runScenario('match-served');
      expect(result.opsPersona, isNull);
      expect(result.matchId, isNull);
      expect(result.dateId, isNull);
      expect(result.dateState, isNull);
      expect(result.notes, isEmpty);
    });

    test('a 500 maps to ServerException naming the failed step', () async {
      adapter.stubs['POST /dev/scenarios/date-booked'] = const _Stub(
        500,
        {'error': 'internal', 'message': 'step pay-deposit failed'},
      );
      await expectLater(
        api.runScenario('date-booked'),
        throwsA(isA<ServerException>()
            .having((e) => e.message, 'message', 'step pay-deposit failed')),
      );
    });
  });

  group('errors', () {
    test('a 401 maps to UnauthorizedException', () async {
      adapter.stubs['GET /dev/clock'] =
          const _Stub(401, {'error': 'unauthorized', 'message': 'bad key'});
      await expectLater(api.getClock(), throwsA(isA<UnauthorizedException>()));
    });

    test('a connection error maps to NetworkException', () async {
      adapter.throwConnectionError = true;
      await expectLater(api.getClock(), throwsA(isA<NetworkException>()));
    });

    test('without a dev key, nothing is sent and the error says so', () async {
      final noKeyApi = DevtoolsApi(
        devKey: '',
        baseUrl: 'http://devtools.test',
        httpClientAdapter: adapter,
      );
      await expectLater(
        noKeyApi.health(),
        throwsA(isA<DevtoolsKeyMissingException>()
            .having((e) => e.message, 'message', contains('DEVTOOLS_KEY not set'))),
      );
      expect(adapter.requests, isEmpty);
    });
  });
}

class _Stub {
  final int status;
  final Object? body;

  const _Stub(this.status, this.body);
}

/// Serves canned responses keyed by `METHOD /path` and records requests.
class _FakeAdapter implements HttpClientAdapter {
  final Map<String, _Stub> stubs;
  final List<RequestOptions> requests = [];
  bool throwConnectionError = false;

  _FakeAdapter(Map<String, _Stub> stubs) : stubs = Map.of(stubs);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (throwConnectionError) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'refused',
      );
    }
    final stub = stubs['${options.method} ${options.uri.path}'];
    if (stub == null) {
      return ResponseBody.fromString('', 599);
    }
    if (stub.body == null) {
      return ResponseBody.fromString('', stub.status);
    }
    return ResponseBody.fromString(
      jsonEncode(stub.body),
      stub.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
