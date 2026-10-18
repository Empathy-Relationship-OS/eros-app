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

/// In-memory [DevtoolsApi] for the persona endpoints. Never sends a request.
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
}
