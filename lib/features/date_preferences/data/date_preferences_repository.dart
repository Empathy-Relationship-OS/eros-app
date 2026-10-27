import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/date_preferences/domain/models/city_district.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/domain/models/section_patch.dart';

/// Repository for date preference API calls (RFC-005 §5).
///
/// Preferences are private: this class logs section names, ids and counts, never a pin, a
/// cuisine, a dietary need or step-free access.
class DatePreferencesRepository {
  final ApiClient _apiClient;
  final Logger _logger;

  DatePreferencesRepository({
    required ApiClient apiClient,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ??
            Logger(
              printer: PrettyPrinter(
                methodCount: 0,
                errorMethodCount: 5,
                lineLength: 80,
                colors: true,
                printEmojis: true,
                dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
              ),
            );

  /// Get the user's date preferences, or the defaults with `isSet: false`
  /// GET /users/me/date-preferences
  Future<DatePreferences> get() async {
    try {
      _logger.i('💘 Getting date preferences');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.datePreferences.getCurrentUser(),
      );

      final preferences = _parse(
        () => DatePreferences.fromJson(response),
        'date preferences',
        'We couldn\'t load your date preferences. Please try again.',
      );
      _logger.i('✅ Date preferences retrieved (isSet: ${preferences.isSet})');
      return preferences;
    } on ApiException catch (e) {
      throw _mapError(e, 'We couldn\'t load your date preferences. Please try again.');
    }
  }

  /// Replace one section of the user's date preferences
  /// PATCH /users/me/date-preferences
  /// Returns the full preferences as the server stored them.
  Future<DatePreferences> patch(SectionPatch patch) async {
    try {
      _logger.i('✏️  Saving date preferences section: ${patch.section}');

      final response = await _apiClient.patch<Map<String, dynamic>>(
        ApiEndpoints.datePreferences.updateCurrentUser(),
        data: patch.toJson(),
      );

      _logger.i('✅ Date preferences section saved: ${patch.section}');
      // The PATCH has already been saved here, so a parse failure must not read as a failed save.
      return _parse(
        () => DatePreferences.fromJson(response),
        'date preferences',
        'Your changes were saved, but we couldn\'t show them. Please reload your date preferences.',
      );
    } on ApiException catch (e) {
      throw _mapError(e, 'We couldn\'t save your date preferences. Please try again.');
    }
  }

  /// Get every option list the date preference screens render
  /// GET /date-preferences/options?cityId={cityId}
  /// Without [cityId], the server uses the user's first dating city.
  Future<DatePreferenceOptions> options({int? cityId}) async {
    try {
      _logger.i('📋 Getting date preference options (cityId: $cityId)');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.datePreferences.options(cityId: cityId),
      );

      final options = _parse(
        () => DatePreferenceOptions.fromJson(response),
        'date preference options',
        'We couldn\'t load your date preference options. Please try again.',
      );
      _logger.i('✅ Date preference options retrieved (${options.activities.length} activities)');
      return options;
    } on ApiException catch (e) {
      throw _mapError(e, 'We couldn\'t load your date preference options. Please try again.');
    }
  }

  /// Get a city's districts, sorted by name
  /// GET /city/{cityId}/districts
  Future<List<CityDistrict>> districts(int cityId) async {
    try {
      _logger.i('🗺️  Getting districts for city: $cityId');

      final response = await _apiClient.get<List<dynamic>>(
        ApiEndpoints.datePreferences.districts(cityId),
      );

      final districts = _parse(
        () => List<CityDistrict>.unmodifiable(
            response.map((d) => CityDistrict.fromJson(d as Map<String, dynamic>))),
        'districts',
        'We couldn\'t load the areas for this city. Please try again.',
      );
      _logger.i('✅ ${districts.length} districts retrieved for city: $cityId');
      return districts;
    } on ApiException catch (e) {
      throw _mapError(e, 'We couldn\'t load the areas for this city. Please try again.');
    }
  }

  /// Turns an [ApiException] into this repository's exceptions. A 400 keeps the server's message,
  /// which says what was wrong (RFC-005 §5, "Validation").
  Exception _mapError(ApiException e, String fallbackMessage) {
    switch (e) {
      case ValidationException():
        // The server's message can name a value the user chose, so it isn't logged.
        _logger.w('⚠️  Validation error (400)');
        return DatePreferencesValidationException(e.message, errors: e.fieldErrors);
      case UnauthorizedException():
        _logger.e('🔒 Authentication failed (401)');
        return DatePreferencesRepositoryException(
          'There was a problem verifying your identity. Please try signing in again.',
        );
      case ForbiddenException():
        _logger.e('🚫 Forbidden (403) - Server rejected the request');
        return DatePreferencesRepositoryException(
          'We couldn\'t process your request at this time. Please try again later.',
        );
      case NetworkException():
        _logger.e('💥 Network error', error: e);
        return DatePreferencesRepositoryException(
          'Unable to connect to the server. Please check your internet connection and try again.',
        );
      default:
        _logger.e('❌ Unexpected error', error: e);
        return DatePreferencesRepositoryException(fallbackMessage);
    }
  }

  /// Runs [parse]. A body the app can't read (a missing field, a level it doesn't know) throws a
  /// TypeError, ArgumentError or FormatException, which becomes a
  /// [DatePreferencesRepositoryException] with [message]. The body itself is never logged.
  T _parse<T>(T Function() parse, String what, String message) {
    try {
      return parse();
    } catch (e, st) {
      _logger.e('🧩 Could not parse the $what response (${e.runtimeType})', stackTrace: st);
      throw DatePreferencesRepositoryException(message);
    }
  }
}

/// Riverpod provider for DatePreferencesRepository
final datePreferencesRepositoryProvider = Provider<DatePreferencesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DatePreferencesRepository(apiClient: apiClient);
});

/// Base exception for date preferences repository errors
class DatePreferencesRepositoryException implements Exception {
  final String message;

  DatePreferencesRepositoryException(this.message);

  @override
  String toString() => 'DatePreferencesRepositoryException: $message';
}

/// The server rejected a save (400). [message] is the server's, and says what was wrong.
class DatePreferencesValidationException implements Exception {
  final String message;
  final Map<String, List<String>>? errors;

  DatePreferencesValidationException(this.message, {this.errors});

  @override
  String toString() {
    if (errors != null) {
      return 'DatePreferencesValidationException: $message\nErrors: $errors';
    }
    return 'DatePreferencesValidationException: $message';
  }
}
