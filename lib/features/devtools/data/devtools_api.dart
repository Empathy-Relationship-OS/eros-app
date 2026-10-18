import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_config.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import '../devtools_config.dart';
import 'devtools_exceptions.dart';
import 'models/devtools_models.dart';

/// Endpoint paths for the backend `/dev` routes (RFC-003 §5).
///
/// Kept inside the devtools feature (not `core/network/api_endpoints.dart`)
/// so every reference to `/dev` is stripped with the rest of devtools.
class DevEndpoints {
  const DevEndpoints._();

  /// GET /dev/health
  static String health() => '/dev/health';

  /// GET /dev/clock
  static String clock() => '/dev/clock';

  /// POST /dev/clock/advance
  static String clockAdvance() => '/dev/clock/advance';

  /// POST /dev/clock/advance-to
  static String clockAdvanceTo() => '/dev/clock/advance-to';

  /// POST /dev/clock/reset
  static String clockReset() => '/dev/clock/reset';

  /// GET /dev/personas, POST /dev/personas
  static String personas() => '/dev/personas';

  /// POST /dev/personas/standard
  static String standardPersonas() => '/dev/personas/standard';

  /// POST /dev/personas/{uid}/token
  static String personaToken(String uid) =>
      '/dev/personas/${Uri.encodeComponent(uid)}/token';

  /// DELETE /dev/personas/{uid}
  static String persona(String uid) =>
      '/dev/personas/${Uri.encodeComponent(uid)}';

  /// POST /dev/fixtures/venues
  static String venueFixtures() => '/dev/fixtures/venues';

  /// POST /dev/reset
  static String reset() => '/dev/reset';

  /// GET /dev/scenarios
  static String scenarios() => '/dev/scenarios';

  /// POST /dev/scenarios/{name}
  static String scenario(String name) =>
      '/dev/scenarios/${Uri.encodeComponent(name)}';
}

/// HTTP client for every backend `/dev` endpoint (RFC-003 §5).
///
/// Uses its **own** [Dio] instance (agent primer rule 9):
/// - sends `X-Dev-Key` on every request
/// - has **no** `AuthInterceptor`: `/dev` routes do not use Firebase auth,
///   and the persona switcher must work while signed out
///
/// Errors are thrown as the app's [ApiException] types. A 404 on
/// [health] becomes [DevtoolsDisabledException]. If the app was built
/// without `DEVTOOLS_KEY`, every call throws [DevtoolsKeyMissingException]
/// without sending a request.
class DevtoolsApi {
  static const String devKeyHeader = 'X-Dev-Key';

  final Dio _dio;
  final String _devKey;
  final Logger _logger = Logger();

  DevtoolsApi({
    required String devKey,
    String? baseUrl,
    @visibleForTesting HttpClientAdapter? httpClientAdapter,
  })  : _devKey = devKey,
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? ApiConfig.baseUrl,
            connectTimeout: ApiConfig.connectTimeout,
            // Scenarios drive many real service calls; give them room.
            receiveTimeout: const Duration(seconds: 60),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              devKeyHeader: devKey,
            },
            // Never throw on status; responses are mapped to ApiException
            // types in _send.
            validateStatus: (status) => status != null,
          ),
        ) {
    if (httpClientAdapter != null) {
      _dio.httpClientAdapter = httpClientAdapter;
    }
    // DT-F1: add ServerTimeInterceptor here once it has merged, so dev
    // responses also feed ServerClock.
  }

  bool get hasKey => _devKey.isNotEmpty;

  // ====================
  // HEALTH
  // ====================

  /// `GET /dev/health`. Throws [DevtoolsDisabledException] if the backend
  /// has devtools turned off.
  Future<DevtoolsHealth> health() async {
    try {
      final json = await _send<Map<String, dynamic>>('GET', DevEndpoints.health());
      return DevtoolsHealth.fromJson(json);
    } on DevtoolsDisabledException {
      rethrow;
    } on NotFoundException catch (e) {
      throw DevtoolsDisabledException(
        originalError: e.originalError,
        stackTrace: e.stackTrace,
      );
    }
  }

  // ====================
  // CLOCK
  // ====================

  /// `GET /dev/clock`
  Future<ClockInfo> getClock() async => ClockInfo.fromJson(
        await _send<Map<String, dynamic>>('GET', DevEndpoints.clock()),
      );

  /// `POST /dev/clock/advance`. 400 ([ValidationException]) if the total is
  /// not positive.
  Future<ClockInfo> advanceClock({
    int days = 0,
    int hours = 0,
    int minutes = 0,
  }) async =>
      ClockInfo.fromJson(
        await _send<Map<String, dynamic>>(
          'POST',
          DevEndpoints.clockAdvance(),
          data: AdvanceClockRequest(days: days, hours: hours, minutes: minutes)
              .toJson(),
        ),
      );

  /// `POST /dev/clock/advance-to`. 400 ([ValidationException]) if [instant]
  /// is not after the current server time.
  Future<ClockInfo> advanceClockTo(DateTime instant) async =>
      ClockInfo.fromJson(
        await _send<Map<String, dynamic>>(
          'POST',
          DevEndpoints.clockAdvanceTo(),
          data: AdvanceClockToRequest(instant).toJson(),
        ),
      );

  /// `POST /dev/clock/reset`
  Future<ClockInfo> resetClock() async => ClockInfo.fromJson(
        await _send<Map<String, dynamic>>('POST', DevEndpoints.clockReset()),
      );

  // ====================
  // PERSONAS
  // ====================

  /// `GET /dev/personas`
  Future<List<Persona>> listPersonas() async =>
      _personaList(await _send<List<dynamic>>('GET', DevEndpoints.personas()));

  /// `POST /dev/personas`. Returns the existing persona if `dev_<handle>`
  /// already exists. 400 ([ValidationException]) for an invalid handle.
  Future<Persona> createPersona(CreatePersonaRequest request) async =>
      Persona.fromJson(
        await _send<Map<String, dynamic>>(
          'POST',
          DevEndpoints.personas(),
          data: request.toJson(),
        ),
      );

  /// `POST /dev/personas/standard`: `dev_alice`, `dev_bob`, `dev_cara`,
  /// `dev_dan` and `dev_ops` (ADMIN). Idempotent.
  Future<List<Persona>> createStandardPersonas() async => _personaList(
        await _send<List<dynamic>>('POST', DevEndpoints.standardPersonas()),
      );

  /// `POST /dev/personas/{uid}/token`: a Firebase custom token for
  /// `signInWithCustomToken`. 400 if [uid] lacks `dev_`, 404 if unknown.
  Future<CustomToken> getPersonaToken(String uid) async => CustomToken.fromJson(
        await _send<Map<String, dynamic>>(
          'POST',
          DevEndpoints.personaToken(uid),
        ),
      );

  /// `DELETE /dev/personas/{uid}`. 400 if [uid] lacks `dev_`.
  Future<void> deletePersona(String uid) async {
    await _send<dynamic>('DELETE', DevEndpoints.persona(uid));
  }

  // ====================
  // FIXTURES AND RESET
  // ====================

  /// `POST /dev/fixtures/venues`. Idempotent.
  Future<VenueFixturesResult> createVenueFixtures() async =>
      VenueFixturesResult.fromJson(
        await _send<Map<String, dynamic>>('POST', DevEndpoints.venueFixtures()),
      );

  /// `POST /dev/reset`: deletes every `dev_` user and their data, then
  /// resets the clock. Venue fixtures are kept.
  Future<ResetResult> reset() async => ResetResult.fromJson(
        await _send<Map<String, dynamic>>('POST', DevEndpoints.reset()),
      );

  // ====================
  // SCENARIOS
  // ====================

  /// `GET /dev/scenarios`
  Future<List<ScenarioInfo>> listScenarios() async =>
      (await _send<List<dynamic>>('GET', DevEndpoints.scenarios()))
          .map((s) => ScenarioInfo.fromJson(s as Map<String, dynamic>))
          .toList();

  /// `POST /dev/scenarios/{name}`. Without [handles], fresh personas are
  /// created. 404 ([NotFoundException]) for an unknown name; 500
  /// ([ServerException]) naming the failed step if it fails partway.
  Future<ScenarioResult> runScenario(
    String name, {
    List<String>? handles,
  }) async =>
      ScenarioResult.fromJson(
        await _send<Map<String, dynamic>>(
          'POST',
          DevEndpoints.scenario(name),
          data: RunScenarioRequest(handles: handles).toJson(),
        ),
      );

  // ====================
  // CORE
  // ====================

  List<Persona> _personaList(List<dynamic> json) =>
      json.map((p) => Persona.fromJson(p as Map<String, dynamic>)).toList();

  Future<T> _send<T>(String method, String path, {Object? data}) async {
    if (!hasKey) throw const DevtoolsKeyMissingException();

    final Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        data: data,
        options: Options(method: method),
      );
    } on DioException catch (e, stackTrace) {
      _logger.e('🛠️ Dev request failed: $method $path', error: e);
      throw _mapDioException(e, stackTrace);
    }

    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      if (status == 204) return null as T;
      final body = response.data;
      if (body is! T) {
        throw UnknownApiException(
          'Unexpected response from $method $path',
          statusCode: status,
          originalError: body,
        );
      }
      return body;
    }

    _logger.w('🛠️ Dev request returned $status: $method $path');
    throw _mapStatus(status, response);
  }

  /// Maps an error response to the app's [ApiException] types, mirroring
  /// `ApiClient` (whose mapper is private).
  ApiException _mapStatus(int status, Response<dynamic> response) {
    final data = response.data;
    String? message;
    if (data is Map<String, dynamic>) {
      message = data['message'] as String? ?? data['error'] as String?;
    }

    switch (status) {
      case 400:
        return ValidationException(
          message ?? 'Validation failed',
          statusCode: status,
          originalError: data,
        );
      case 401:
        return UnauthorizedException(
          message ?? 'Wrong or missing X-Dev-Key',
          statusCode: status,
          originalError: data,
        );
      case 403:
        return ForbiddenException(
          message ?? 'Access denied',
          statusCode: status,
          originalError: data,
        );
      case 404:
        return NotFoundException(
          message ?? 'Resource not found',
          statusCode: status,
          originalError: data,
        );
      case 409:
        return ConflictException(
          message ?? 'Resource conflict',
          statusCode: status,
          originalError: data,
        );
      case 429:
        final retryAfter =
            int.tryParse(response.headers.value('retry-after') ?? '');
        return RateLimitException(
          message ?? 'Too many requests',
          retryAfter: retryAfter == null ? null : Duration(seconds: retryAfter),
          statusCode: status,
          originalError: data,
        );
      default:
        if (status >= 500) {
          return ServerException(
            message ?? 'Server error',
            statusCode: status,
            originalError: data,
          );
        }
        return UnknownApiException(
          message ?? 'Unexpected status $status',
          statusCode: status,
          originalError: data,
        );
    }
  }

  ApiException _mapDioException(DioException e, StackTrace stackTrace) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          'Dev request timed out. Is the backend running?',
          originalError: e,
          stackTrace: stackTrace,
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          'Cannot reach the backend at ${_dio.options.baseUrl}',
          originalError: e,
          stackTrace: stackTrace,
        );
      case DioExceptionType.cancel:
        return NetworkException(
          'Request cancelled',
          originalError: e,
          stackTrace: stackTrace,
        );
      default:
        return UnknownApiException(
          'Dev request failed: ${e.message}',
          originalError: e,
          stackTrace: stackTrace,
        );
    }
  }
}

/// The `X-Dev-Key` the app was built with. Overridable in tests.
final devtoolsKeyProvider = Provider<String>((ref) => DevtoolsConfig.key);

/// The single [DevtoolsApi] used by the dev menu and every devtools panel.
///
/// Deliberately does not watch any auth provider: `/dev` calls are
/// independent of who is signed in.
final devtoolsApiProvider = Provider<DevtoolsApi>((ref) {
  return DevtoolsApi(devKey: ref.watch(devtoolsKeyProvider));
});
