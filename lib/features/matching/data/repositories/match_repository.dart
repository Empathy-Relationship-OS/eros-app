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

  /// Take action on a match (like or pass)
  ///
  /// Sends user's action (like/pass) on a match they've been served.
  ///
  /// Returns:
  /// - [MutualMatchInfo] if both users liked each other (200)
  /// - `null` if action recorded but no mutual match (204 No Content)
  ///
  /// Throws:
  /// - [ValidationException] if invalid matchId (400)
  /// - [UnauthorizedException] if not authenticated (401)
  /// - [ForbiddenException] if user doesn't own this match (403)
  /// - [ConflictException] if user already took action on this match (409)
  /// - Other [ApiException] subclasses for other errors
  Future<MutualMatchInfo?> takeMatchAction(int matchId, bool liked) async {
    try {
      _logger.d('💘 Taking action on match $matchId: ${liked ? "LIKE" : "PASS"}');

      final request = MatchActionRequest(liked: liked);
      final response = await _apiClient.patch<Map<String, dynamic>?>(
        ApiEndpoints.match.action(matchId.toString()),
        data: request.toJson(),
      );

      // Handle 204 No Content (action recorded, no mutual match)
      if (response == null) {
        _logger.d('✅ Action recorded, no mutual match');
        return null;
      }

      // 200 OK - mutual match!
      final mutualMatch = MutualMatchInfo.fromJson(response);
      _logger.d('🎉 MUTUAL MATCH! matchId=${mutualMatch.matchId}');
      return mutualMatch;
    } on ConflictException {
      _logger.w('⚠️  User already took action on match $matchId');
      rethrow;
    } on ForbiddenException {
      _logger.e('🚫 User does not own match $matchId');
      rethrow;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to take match action. Type: ${e.runtimeType}, Message: ${e.message}');
      _logger.d('Status code: ${e.statusCode}, Original error: ${e.originalError}');
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('🚨 Unexpected error in takeMatchAction', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
