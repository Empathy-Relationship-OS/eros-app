import 'dart:async';

import 'package:eros_app/features/devtools/data/devtools_api.dart';
import 'package:eros_app/features/devtools/data/models/devtools_models.dart';

/// PersonaDTOs from RFC-003 §5.3 (`POST /dev/personas/standard`).
const standardCastJson = [
  {
    'uid': 'dev_alice',
    'firstName': 'Alice',
    'gender': 'FEMALE',
    'city': 'London',
    'role': 'USER',
    'tokenBalance': 100,
  },
  {
    'uid': 'dev_bob',
    'firstName': 'Bob',
    'gender': 'MALE',
    'city': 'London',
    'role': 'USER',
    'tokenBalance': 100,
  },
  {
    'uid': 'dev_ops',
    'firstName': 'Ops',
    'gender': 'MALE',
    'city': 'London',
    'role': 'ADMIN',
    'tokenBalance': 0,
  },
];

List<Persona> standardCast() => standardCastJson.map(Persona.fromJson).toList();

/// `GET /dev/scenarios` (RFC-003 §5.5), in pipeline order. The names are
/// deliberately not the backend's, so a test that finds them on screen
/// proves the list comes from the response.
const scenarioListJson = [
  {
    'name': 'zz-match-only',
    'description': 'A and B are in each other\'s current batch.',
    'endState': 'MATCH',
  },
  {
    'name': 'zz-deposit-partner-paid',
    'description': 'B has paid the deposit, A has not.',
    'endState': 'AWAITING_DEPOSIT',
  },
  {
    'name': 'zz-booked',
    'description': 'Booked by ops; start is just over 48h away.',
    'endState': 'BOOKED',
  },
];

List<ScenarioInfo> scenarioList() =>
    scenarioListJson.map(ScenarioInfo.fromJson).toList();

/// `ScenarioResultDTO`, the RFC-003 §5.5 example.
const scenarioResultJson = {
  'scenario': 'zz-booked',
  'personas': [
    {
      'uid': 'dev_s1a2b3_a',
      'firstName': 'Ava',
      'gender': 'FEMALE',
      'city': 'London',
      'role': 'USER',
      'tokenBalance': 95,
    },
    {
      'uid': 'dev_s1a2b3_b',
      'firstName': 'Ben',
      'gender': 'MALE',
      'city': 'London',
      'role': 'USER',
      'tokenBalance': 95,
    },
  ],
  'opsPersona': {
    'uid': 'dev_ops',
    'firstName': 'Ops',
    'gender': 'MALE',
    'city': 'London',
    'role': 'ADMIN',
    'tokenBalance': 0,
  },
  'matchId': 42,
  'dateId': 17,
  'dateState': 'BOOKED',
  'loginAs': 'dev_s1a2b3_a',
  'notes': [
    'Date starts 2026-10-18T19:00:00Z. Advance the clock 25h to open the '
        'presence window.',
  ],
};

/// A scenario that ends at a match: no date yet (RFC-003 §5.5).
const matchScenarioResultJson = {
  'scenario': 'zz-match-only',
  'personas': [
    {
      'uid': 'dev_s9_a',
      'firstName': 'Ava',
      'gender': 'FEMALE',
      'city': 'London',
      'role': 'USER',
      'tokenBalance': 100,
    },
    {
      'uid': 'dev_s9_b',
      'firstName': 'Ben',
      'gender': 'MALE',
      'city': 'London',
      'role': 'USER',
      'tokenBalance': 100,
    },
  ],
  'opsPersona': null,
  'matchId': 42,
  'dateId': null,
  'dateState': null,
  'loginAs': 'dev_s9_a',
  'notes': ['Like Ben to create the date.'],
};

/// `POST /dev/reset` (RFC-003 §5.4).
const resetResultJson = {
  'deletedPersonas': 6,
  'deletedMatches': 4,
  'deletedDates': 2,
  'skippedDates': <int>[],
  'clock': {
    'realTime': '2026-10-16T12:00:00Z',
    'serverTime': '2026-10-16T12:00:00Z',
    'offsetSeconds': 0,
  },
};

/// In-memory [DevtoolsApi] for the persona, scenario and reset endpoints.
/// Never sends a request.
///
/// Set the `*Error` fields to make the matching call throw.
class FakeDevtoolsApi extends DevtoolsApi {
  FakeDevtoolsApi({List<Persona>? personas})
    : personas = personas ?? [],
      super(devKey: 'test-dev-key-123456', baseUrl: 'http://fake.invalid');

  List<Persona> personas;
  final List<String> calls = [];

  Object? listError;
  Object? tokenError;
  Object? deleteError;
  Object? createError;

  List<ScenarioInfo> scenarios = scenarioList();
  ScenarioResult scenarioResult = ScenarioResult.fromJson(scenarioResultJson);
  ResetResult resetResult = ResetResult.fromJson(resetResultJson);
  Object? scenariosError;
  Object? runError;
  Object? resetError;

  /// Handles passed to the last [runScenario].
  List<String>? lastHandles;

  /// When set, [runScenario] waits for it before answering.
  Completer<void>? runGate;

  @override
  Future<List<Persona>> listPersonas() async {
    calls.add('listPersonas');
    if (listError != null) throw listError!;
    return List.of(personas);
  }

  @override
  Future<List<Persona>> createStandardPersonas() async {
    calls.add('createStandardPersonas');
    personas = standardCast();
    return personas;
  }

  @override
  Future<Persona> createPersona(CreatePersonaRequest request) async {
    calls.add('createPersona:${request.handle}');
    if (createError != null) throw createError!;
    final persona = Persona(
      uid: 'dev_${request.handle}',
      firstName: request.firstName ?? 'Test',
      gender: request.gender ?? 'FEMALE',
      city: 'London',
      role: request.role ?? 'USER',
      tokenBalance: request.tokens ?? 100,
    );
    personas = [...personas, persona];
    return persona;
  }

  @override
  Future<CustomToken> getPersonaToken(String uid) async {
    calls.add('getPersonaToken:$uid');
    if (tokenError != null) throw tokenError!;
    return CustomToken.fromJson({
      'uid': uid,
      'role': 'USER',
      'customToken': 'custom-token-for-$uid',
    });
  }

  @override
  Future<void> deletePersona(String uid) async {
    calls.add('deletePersona:$uid');
    if (deleteError != null) throw deleteError!;
    personas = personas.where((p) => p.uid != uid).toList();
  }

  @override
  Future<List<ScenarioInfo>> listScenarios() async {
    calls.add('listScenarios');
    if (scenariosError != null) throw scenariosError!;
    return List.of(scenarios);
  }

  @override
  Future<ScenarioResult> runScenario(
    String name, {
    List<String>? handles,
  }) async {
    calls.add('runScenario:$name');
    lastHandles = handles;
    await runGate?.future;
    if (runError != null) throw runError!;
    return scenarioResult;
  }

  @override
  Future<ResetResult> reset() async {
    calls.add('reset');
    if (resetError != null) throw resetError!;
    personas = [];
    return resetResult;
  }
}
