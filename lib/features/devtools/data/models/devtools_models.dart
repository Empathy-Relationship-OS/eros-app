/// Models for the backend `/dev` endpoints (RFC-003 §5).
///
/// Wire conventions match the rest of the API:
/// - Instants are ISO-8601 UTC strings ("2026-10-17T13:00:00Z")
/// - Enum values (gender, role, date state) are UPPER_SNAKE strings. They
///   are kept as strings here: the dev menu only displays them, and keeping
///   them loose means a new backend enum value never breaks the dev menu.
/// - Nullable fields may be present as null
library;

DateTime _instant(dynamic v) => DateTime.parse(v as String);

String _wireInstant(DateTime d) => d.toUtc().toIso8601String();

// ====================
// RESPONSE MODELS
// ====================

/// `GET /dev/health`
class DevtoolsHealth {
  final bool enabled;
  final DateTime serverTime;
  final int offsetSeconds;

  const DevtoolsHealth({
    required this.enabled,
    required this.serverTime,
    required this.offsetSeconds,
  });

  Duration get offset => Duration(seconds: offsetSeconds);

  factory DevtoolsHealth.fromJson(Map<String, dynamic> json) => DevtoolsHealth(
        enabled: json['enabled'] as bool,
        serverTime: _instant(json['serverTime']),
        offsetSeconds: (json['offsetSeconds'] as num).toInt(),
      );
}

/// `ClockDTO`: returned by every `/dev/clock` endpoint and inside reset.
class ClockInfo {
  final DateTime realTime;
  final DateTime serverTime;
  final int offsetSeconds;

  const ClockInfo({
    required this.realTime,
    required this.serverTime,
    required this.offsetSeconds,
  });

  Duration get offset => Duration(seconds: offsetSeconds);

  bool get isShifted => offsetSeconds != 0;

  factory ClockInfo.fromJson(Map<String, dynamic> json) => ClockInfo(
        realTime: _instant(json['realTime']),
        serverTime: _instant(json['serverTime']),
        offsetSeconds: (json['offsetSeconds'] as num).toInt(),
      );
}

/// `PersonaDTO`: a test user whose uid starts with `dev_`.
class Persona {
  final String uid;
  final String firstName;

  /// Backend `Gender` enum name, e.g. `WOMAN`.
  final String gender;
  final String city;

  /// Backend role enum name, e.g. `USER` or `ADMIN`.
  final String role;
  final int tokenBalance;

  const Persona({
    required this.uid,
    required this.firstName,
    required this.gender,
    required this.city,
    required this.role,
    required this.tokenBalance,
  });

  bool get isAdmin => role == 'ADMIN';

  factory Persona.fromJson(Map<String, dynamic> json) => Persona(
        uid: json['uid'] as String,
        firstName: json['firstName'] as String,
        gender: json['gender'] as String,
        city: json['city'] as String,
        role: json['role'] as String,
        tokenBalance: (json['tokenBalance'] as num).toInt(),
      );
}

/// `POST /dev/personas/{uid}/token`: a Firebase custom token to pass to
/// `FirebaseAuth.signInWithCustomToken`.
class CustomToken {
  final String uid;
  final String role;
  final String customToken;

  const CustomToken({
    required this.uid,
    required this.role,
    required this.customToken,
  });

  factory CustomToken.fromJson(Map<String, dynamic> json) => CustomToken(
        uid: json['uid'] as String,
        role: json['role'] as String,
        customToken: json['customToken'] as String,
      );
}

/// `GET /dev/scenarios` entry.
class ScenarioInfo {
  final String name;
  final String description;

  /// Date state the scenario ends in (e.g. `BOOKED`), or null for scenarios
  /// that end before a date exists.
  final String? endState;

  const ScenarioInfo({
    required this.name,
    required this.description,
    this.endState,
  });

  factory ScenarioInfo.fromJson(Map<String, dynamic> json) => ScenarioInfo(
        name: json['name'] as String,
        description: json['description'] as String,
        endState: json['endState'] as String?,
      );
}

/// `ScenarioResultDTO`: returned by `POST /dev/scenarios/{name}`.
class ScenarioResult {
  final String scenario;
  final List<Persona> personas;

  /// Null for scenarios with no ops step.
  final Persona? opsPersona;

  /// Null for scenarios that end before the match exists.
  final int? matchId;

  /// Null for scenarios that end before the date exists.
  final int? dateId;

  /// Backend `DateState` name, null when there is no date.
  final String? dateState;

  /// uid to sign in as to continue testing.
  final String loginAs;
  final List<String> notes;

  const ScenarioResult({
    required this.scenario,
    required this.personas,
    this.opsPersona,
    this.matchId,
    this.dateId,
    this.dateState,
    required this.loginAs,
    required this.notes,
  });

  factory ScenarioResult.fromJson(Map<String, dynamic> json) => ScenarioResult(
        scenario: json['scenario'] as String,
        personas: (json['personas'] as List<dynamic>)
            .map((p) => Persona.fromJson(p as Map<String, dynamic>))
            .toList(),
        opsPersona: json['opsPersona'] == null
            ? null
            : Persona.fromJson(json['opsPersona'] as Map<String, dynamic>),
        matchId: (json['matchId'] as num?)?.toInt(),
        dateId: (json['dateId'] as num?)?.toInt(),
        dateState: json['dateState'] as String?,
        loginAs: json['loginAs'] as String,
        notes: (json['notes'] as List<dynamic>? ?? const [])
            .map((n) => n as String)
            .toList(),
      );
}

/// `POST /dev/reset`
class ResetResult {
  final int deletedPersonas;
  final int deletedMatches;
  final int deletedDates;

  /// Dates pairing a `dev_` user with a real user. Never deleted.
  final List<int> skippedDates;
  final ClockInfo clock;

  const ResetResult({
    required this.deletedPersonas,
    required this.deletedMatches,
    required this.deletedDates,
    required this.skippedDates,
    required this.clock,
  });

  factory ResetResult.fromJson(Map<String, dynamic> json) => ResetResult(
        deletedPersonas: (json['deletedPersonas'] as num).toInt(),
        deletedMatches: (json['deletedMatches'] as num).toInt(),
        deletedDates: (json['deletedDates'] as num).toInt(),
        skippedDates: (json['skippedDates'] as List<dynamic>? ?? const [])
            .map((d) => (d as num).toInt())
            .toList(),
        clock: ClockInfo.fromJson(json['clock'] as Map<String, dynamic>),
      );
}

/// `POST /dev/fixtures/venues`
class VenueFixturesResult {
  final int cityId;
  final List<int> activityIds;
  final int venuesCreated;
  final int venuesExisting;

  const VenueFixturesResult({
    required this.cityId,
    required this.activityIds,
    required this.venuesCreated,
    required this.venuesExisting,
  });

  factory VenueFixturesResult.fromJson(Map<String, dynamic> json) =>
      VenueFixturesResult(
        cityId: (json['cityId'] as num).toInt(),
        activityIds: (json['activityIds'] as List<dynamic>)
            .map((a) => (a as num).toInt())
            .toList(),
        venuesCreated: (json['venuesCreated'] as num).toInt(),
        venuesExisting: (json['venuesExisting'] as num).toInt(),
      );
}

// ====================
// REQUEST MODELS
// ====================

/// Body of `POST /dev/personas`. Only [handle] is required; the backend
/// fills everything else from a fixed preset.
class CreatePersonaRequest {
  /// Must match `[a-z0-9_]{2,32}`. The persona's uid becomes `dev_<handle>`.
  final String handle;
  final String? firstName;

  /// Backend `Gender` enum name, e.g. `WOMAN`.
  final String? gender;

  /// Backend role enum name, e.g. `USER` or `ADMIN`.
  final String? role;
  final int? tokens;

  const CreatePersonaRequest({
    required this.handle,
    this.firstName,
    this.gender,
    this.role,
    this.tokens,
  });

  Map<String, dynamic> toJson() => {
        'handle': handle,
        if (firstName != null) 'firstName': firstName,
        if (gender != null) 'gender': gender,
        if (role != null) 'role': role,
        if (tokens != null) 'tokens': tokens,
      };
}

/// Body of `POST /dev/clock/advance`. All parts default to 0; the total must
/// be positive.
class AdvanceClockRequest {
  final int days;
  final int hours;
  final int minutes;

  const AdvanceClockRequest({this.days = 0, this.hours = 0, this.minutes = 0});

  Map<String, dynamic> toJson() =>
      {'days': days, 'hours': hours, 'minutes': minutes};
}

/// Body of `POST /dev/clock/advance-to`. [instant] must be after the current
/// server time.
class AdvanceClockToRequest {
  final DateTime instant;

  const AdvanceClockToRequest(this.instant);

  Map<String, dynamic> toJson() => {'instant': _wireInstant(instant)};
}

/// Optional body of `POST /dev/scenarios/{name}`.
class RunScenarioRequest {
  /// Reuse these persona handles instead of creating fresh ones.
  final List<String>? handles;

  const RunScenarioRequest({this.handles});

  Map<String, dynamic> toJson() => {
        if (handles != null) 'handles': handles,
      };
}
