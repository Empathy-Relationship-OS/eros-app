import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/matching/domain/models/match_models.dart';

/// Repository for match-related API operations
class MatchRepository {
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  MatchRepository(this._apiClient);

  /// Fetch daily batch of matches
  ///
  /// Returns a batch of up to 7 unserved matches for the authenticated user.
  /// Users can fetch maximum 3 batches per day (21 total matches).
  ///
  /// Returns:
  /// - [DailyBatchResponse] on success (200)
  /// - `null` if no matches available (204 No Content)
  ///
  /// Throws:
  /// - [RateLimitException] if daily batch limit exceeded (429) with resetAt time
  /// - [UnauthorizedException] if not authenticated (401)
  /// - Other [ApiException] subclasses for other errors
  Future<DailyBatchResponse?> fetchDailyBatch() async {
    try {
      _logger.d('🎯 Fetching daily match batch');

      final response = await _apiClient.get<Map<String, dynamic>?>(
        ApiEndpoints.match.fetchBatch(),
      );

      // Handle 204 No Content (null response)
      if (response == null) {
        _logger.d('ℹ️  No matches available (204 No Content)');
        return null;
      }

      final batchResponse = DailyBatchResponse.fromJson(response);
      _logger.d(
        '✅ Fetched batch ${batchResponse.batchNumber} with ${batchResponse.profiles.length} profiles. Remaining: ${batchResponse.remainingBatches}',
      );

      return batchResponse;
    } on RateLimitException catch (e) {
      // 429 - daily batch limit exceeded
      _logger.w('⏰ Daily batch limit exceeded. Retry after: ${e.retryAfter}');
      _logger.d('Original error data: ${e.originalError}');
      rethrow;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to fetch daily batch. Type: ${e.runtimeType}, Message: ${e.message}');
      _logger.d('Status code: ${e.statusCode}, Original error: ${e.originalError}');
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('🚨 Unexpected error in fetchDailyBatch', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
