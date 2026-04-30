import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/auth/domain/models/marketing_preference_models.dart';

/// Provider for MarketingPreferenceRepository
final marketingPreferenceRepositoryProvider =
    Provider<MarketingPreferenceRepository>((ref) {
  return MarketingPreferenceRepository(
    apiClient: ref.read(apiClientProvider),
  );
});

/// Repository for marketing preference API calls
///
/// Handles creating and updating marketing consent preferences for users.
class MarketingPreferenceRepository {
  final ApiClient _apiClient;
  final Logger _logger;

  MarketingPreferenceRepository({
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

  /// Create marketing preference
  /// POST /marketing/preference
  ///
  /// Creates a new marketing consent record for the authenticated user.
  /// Returns the created preference or throws an exception if failed.
  Future<MarketingPreferenceResponse> createMarketingPreference({
    required bool marketingConsent,
  }) async {
    try {
      _logger.d('📧 Creating marketing preference: $marketingConsent');

      final request = CreateMarketingConsentRequest(
        marketingConsent: marketingConsent,
      );

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.marketing.createPreference(),
        data: request.toJson(),
      );

      _logger.i('✅ Marketing preference created successfully');
      return MarketingPreferenceResponse.fromJson(response);
    } on ConflictException {
      _logger.w('⚠️  Marketing preference already exists');
      // If it already exists, that's fine - the user's preference is already set
      rethrow;
    } on ValidationException catch (e) {
      _logger.w('⚠️  Validation error: ${e.message}');
      rethrow;
    } on UnauthorizedException {
      _logger.e('🔒 Authentication failed (401)');
      rethrow;
    } on ForbiddenException {
      _logger.e('🚫 Forbidden (403) - Server rejected the request');
      rethrow;
    } on NetworkException catch (e) {
      _logger.e('💥 Network error', error: e);
      rethrow;
    } on ApiException catch (e) {
      _logger.e('❌ Unexpected error creating marketing preference', error: e);
      rethrow;
    }
  }

  /// Update marketing preference
  /// PUT /marketing/preference
  ///
  /// Updates the marketing consent for the authenticated user.
  /// Returns the updated preference or throws an exception if failed.
  Future<MarketingPreferenceResponse> updateMarketingPreference({
    required bool marketingConsent,
  }) async {
    try {
      _logger.d('🔄 Updating marketing preference: $marketingConsent');

      final request = CreateMarketingConsentRequest(
        marketingConsent: marketingConsent,
      );

      final response = await _apiClient.patch<Map<String, dynamic>>(
        ApiEndpoints.marketing.updatePreference(),
        data: request.toJson(),
      );

      _logger.i('✅ Marketing preference updated successfully');
      return MarketingPreferenceResponse.fromJson(response);
    } on NotFoundException {
      _logger.w('⚠️  Marketing preference not found - creating instead');
      // If not found, create it instead
      return createMarketingPreference(marketingConsent: marketingConsent);
    } on ValidationException catch (e) {
      _logger.w('⚠️  Validation error: ${e.message}');
      rethrow;
    } on UnauthorizedException {
      _logger.e('🔒 Authentication failed (401)');
      rethrow;
    } on ForbiddenException {
      _logger.e('🚫 Forbidden (403) - Server rejected the request');
      rethrow;
    } on NetworkException catch (e) {
      _logger.e('💥 Network error', error: e);
      rethrow;
    } on ApiException catch (e) {
      _logger.e('❌ Unexpected error updating marketing preference', error: e);
      rethrow;
    }
  }

  /// Get marketing preference
  /// GET /marketing/preference
  ///
  /// Retrieves the current marketing consent for the authenticated user.
  /// Returns null if no preference has been set yet.
  Future<MarketingPreferenceResponse?> getMarketingPreference() async {
    try {
      _logger.d('🔍 Getting marketing preference');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.marketing.getPreference(),
      );

      _logger.i('✅ Marketing preference retrieved successfully');
      return MarketingPreferenceResponse.fromJson(response);
    } on NotFoundException {
      _logger.d('ℹ️  Marketing preference not found');
      return null;
    } on UnauthorizedException {
      _logger.e('🔒 Authentication failed (401)');
      rethrow;
    } on ForbiddenException {
      _logger.e('🚫 Forbidden (403) - Server rejected the request');
      rethrow;
    } on NetworkException catch (e) {
      _logger.e('💥 Network error', error: e);
      rethrow;
    } on ApiException catch (e) {
      _logger.e('❌ Unexpected error getting marketing preference', error: e);
      rethrow;
    }
  }
}
