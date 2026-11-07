import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_patch.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preference_options.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preferences.dart';

/// Repository for match preference API calls (RFC-007 §5).
///
/// Preferences are private (RFC-007 D-9): this class logs filter names, counts and status codes,
/// never a value, a bound or a district.
class MatchPreferencesRepository {
  final ApiClient _apiClient;
  final Logger _logger;

  MatchPreferencesRepository({
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

  /// Get the user's match preferences, or the defaults with `isSet: false`
  /// GET /users/me/match-preferences
  Future<MatchPreferences> get() async {
    try {
      _logger.i('💞 Getting match preferences');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.matchPreferences.getCurrentUser(),
      );

      final preferences = _parse(
        () => MatchPreferences.fromJson(response, onDropped: _logDropped),
        'match preferences',
        'We couldn\'t load your match preferences. Please try again.',
      );
      _logger.i('✅ Match preferences retrieved (isSet: ${preferences.isSet})');
      return preferences;
    } on ApiException catch (e) {
      throw _mapError(e, 'We couldn\'t load your match preferences. Please try again.');
    }
  }

  /// Replace one filter of the user's match preferences
  /// PATCH /users/me/match-preferences
  /// Returns the full preferences as the server stored them.
  Future<MatchPreferences> patch(FilterPatch patch) async {
    try {
      _logger.i('✏️  Saving match preference: ${patch.filter}');

      final response = await _apiClient.patch<Map<String, dynamic>>(
        ApiEndpoints.matchPreferences.updateCurrentUser(),
        data: patch.toJson(),
      );

      _logger.i('✅ Match preference saved: ${patch.filter}');
      // The PATCH has already been saved here, so a parse failure must not read as a failed save.
      return _parse(
        () => MatchPreferences.fromJson(response, onDropped: _logDropped),
        'match preferences',
        'Your change was saved, but we couldn\'t show it. Please reload your match preferences.',
        saved: true,
      );
    } on ApiException catch (e) {
      throw _mapError(e, 'We couldn\'t save your match preferences. Please try again.');
    }
  }

  /// Get the bounds, distance stops, age default and gender suggestion the screens need
  /// GET /match-preferences/options
  Future<MatchPreferenceOptions> options() async {
    try {
      _logger.i('📋 Getting match preference options');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.matchPreferences.options(),
      );

      final options = _parse(
        () => MatchPreferenceOptions.fromJson(response, onDropped: _logDropped),
        'match preference options',
        'We couldn\'t load your match preference options. Please try again.',
      );
      _logger.i('✅ Match preference options retrieved');
      return options;
    } on ApiException catch (e) {
      throw _mapError(e, 'We couldn\'t load your match preference options. Please try again.');
    }
  }

  /// A value the app doesn't know, perhaps one added to the profile since this build. Only the
  /// filter's key and the count are logged: the value could be the user's religion or ethnicity.
  void _logDropped(String filter, int count) {
    _logger.w('🧩 Dropped $count unknown value(s) from $filter');
  }

  /// Turns an [ApiException] into this repository's exceptions. A 400 keeps the server's message,
  /// which says what was wrong (RFC-007 §5).
  Exception _mapError(ApiException e, String fallbackMessage) {
    switch (e) {
      case ValidationException():
        // The server's message can name a value the user chose, so it isn't logged.
        _logger.w('⚠️  Validation error (400)');
        return MatchPreferencesValidationException(e.message, errors: e.fieldErrors);
      case UnauthorizedException():
        _logger.e('🔒 Authentication failed (401)');
        return MatchPreferencesRepositoryException(
          'There was a problem verifying your identity. Please try signing in again.',
        );
      case ForbiddenException():
        _logger.e('🚫 Forbidden (403) - Server rejected the request');
        return MatchPreferencesRepositoryException(
          'We couldn\'t process your request at this time. Please try again later.',
        );
      case NetworkException():
        _logger.e('💥 Network error (${e.runtimeType})');
        return MatchPreferencesRepositoryException(
          'Unable to connect to the server. Please check your internet connection and try again.',
        );
      default:
        _logger.e('❌ Unexpected error (status: ${e.statusCode})');
        return MatchPreferencesRepositoryException(fallbackMessage);
    }
  }

  /// Runs [parse]. A body the app can't read (a missing field, a wrong type) throws a TypeError,
  /// which becomes a [MatchPreferencesRepositoryException] with [message], or a
  /// [MatchPreferencesSavedException] when [saved]. The body itself is never logged.
  T _parse<T>(T Function() parse, String what, String message, {bool saved = false}) {
    try {
      return parse();
    } catch (e, st) {
      _logger.e('🧩 Could not parse the $what response (${e.runtimeType})', stackTrace: st);
      throw saved
          ? MatchPreferencesSavedException(message)
          : MatchPreferencesRepositoryException(message);
    }
  }
}

/// Riverpod provider for MatchPreferencesRepository
final matchPreferencesRepositoryProvider = Provider<MatchPreferencesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MatchPreferencesRepository(apiClient: apiClient);
});

/// Base exception for match preferences repository errors
class MatchPreferencesRepositoryException implements Exception {
  final String message;

  MatchPreferencesRepositoryException(this.message);

  @override
  String toString() => 'MatchPreferencesRepositoryException: $message';
}

/// The server saved the change, but its response couldn't be read.
class MatchPreferencesSavedException extends MatchPreferencesRepositoryException {
  MatchPreferencesSavedException(super.message);

  @override
  String toString() => 'MatchPreferencesSavedException: $message';
}

/// The server rejected a save (400). [message] is the server's, and says what was wrong, such as
/// "Choose who you're interested in first".
class MatchPreferencesValidationException implements Exception {
  final String message;
  final Map<String, List<String>>? errors;

  MatchPreferencesValidationException(this.message, {this.errors});

  @override
  String toString() {
    if (errors != null) {
      return 'MatchPreferencesValidationException: $message\nErrors: $errors';
    }
    return 'MatchPreferencesValidationException: $message';
  }
}
