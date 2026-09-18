import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';

/// Repository for date-related API operations
class DatesRepository {
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  DatesRepository(this._apiClient);

  /// Fetch dates list with optional filter
  ///
  /// Filter options: DateListFilter.active, DateListFilter.past, DateListFilter.cancelled
  /// - active: non-terminal states
  /// - past: COMPLETED
  /// - cancelled: CANCELLED and EXPIRED
  ///
  /// Returns empty list if no dates match filter.
  ///
  /// Throws:
  /// - [UnauthorizedException] if not authenticated (401)
  /// - Other [ApiException] subclasses for other errors
  Future<List<DateSummary>> fetchDates({DateListFilter? filter}) async {
    try {
      _logger.d('📅 Fetching dates (filter: ${filter ?? 'all'})');

      final response = await _apiClient.get<List<dynamic>>(
        ApiEndpoints.dates.getList(filter: filter),
      );

      final dates = response
          .map((json) => DateSummary.fromJson(json as Map<String, dynamic>))
          .toList();

      _logger.d('✅ Fetched ${dates.length} dates');
      return dates;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to fetch dates', error: e);
      rethrow;
    }
  }

  /// Get date detail by ID
  ///
  /// Returns null if date not found (404).
  ///
  /// Throws:
  /// - [ForbiddenException] if user is not a participant (403)
  /// - [UnauthorizedException] if not authenticated (401)
  /// - Other [ApiException] subclasses for other errors
  Future<DateDetail?> getDateById(String dateId) async {
    try {
      _logger.d('🔍 Getting date: $dateId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.dates.getById(dateId),
      );

      final dateDetail = DateDetail.fromJson(response);
      _logger.d('✅ Got date $dateId (state: ${dateDetail.state})');
      return dateDetail;
    } on NotFoundException {
      _logger.d('ℹ️  Date not found: $dateId');
      return null;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to get date', error: e);
      rethrow;
    }
  }

  /// Get availability view for a date
  ///
  /// Returns availability slots for both participants.
  ///
  /// Throws:
  /// - [NotFoundException] if date not found (404)
  /// - [ConflictException] if date not in AWAITING_AVAILABILITY state (409)
  /// - Other [ApiException] subclasses for other errors
  Future<AvailabilityView> getAvailability(String dateId) async {
    try {
      _logger.d('📆 Getting availability for date: $dateId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.dates.getAvailability(dateId),
      );

      final availability = AvailabilityView.fromJson(response);
      _logger.d(
          '✅ Got availability (round ${availability.currentRound}, my slots: ${availability.mySlots.length}, partner slots: ${availability.partnerSlots.length})');
      return availability;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to get availability', error: e);
      rethrow;
    }
  }

  /// Submit availability slots
  ///
  /// Returns updated availability view.
  /// May transition date to AWAITING_DEPOSIT if both submitted and time found.
  ///
  /// Throws:
  /// - [ValidationException] if slots invalid (400) - shows user-readable message
  /// - [ConflictException] if wrong state or deadline passed (409)
  /// - Other [ApiException] subclasses for other errors
  Future<AvailabilityView> submitAvailability(
    String dateId,
    SubmitAvailabilityRequest request,
  ) async {
    try {
      _logger.d(
          '📤 Submitting availability for date: $dateId (${request.slots.length} slots)');

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.dates.submitAvailability(dateId),
        data: request.toJson(),
      );

      final availability = AvailabilityView.fromJson(response);
      _logger.d('✅ Availability submitted');
      return availability;
    } on ValidationException catch (e) {
      _logger.w('⚠️  Validation error: ${e.message}');
      rethrow;
    } on ConflictException catch (e) {
      _logger.w('⚠️  Conflict: ${e.message}');
      rethrow;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to submit availability', error: e);
      rethrow;
    }
  }

  /// Pay deposit for date
  ///
  /// Returns deposit payment response with new balance and transition info.
  ///
  /// Throws:
  /// - [ConflictException] with 'insufficient_balance' if not enough tokens (409)
  /// - [ConflictException] if wrong state, already paid, or deadline passed (409)
  /// - Other [ApiException] subclasses for other errors
  Future<DepositPaymentResponse> payDeposit(String dateId) async {
    try {
      _logger.d('💳 Paying deposit for date: $dateId');

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.dates.payDeposit(dateId),
      );

      final result = DepositPaymentResponse.fromJson(response);
      _logger.d(
          '✅ Deposit paid (bothPaid: ${result.bothPaid}, transitioned: ${result.transitionedToRanking})');
      return result;
    } on ConflictException catch (e) {
      _logger.w('⚠️  Deposit conflict: ${e.message}');
      rethrow;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to pay deposit', error: e);
      rethrow;
    }
  }

  /// Get venue options for date
  ///
  /// Returns 1-3 venue options and user's rankings (if submitted).
  ///
  /// Throws:
  /// - [ConflictException] if wrong state (409)
  /// - Other [ApiException] subclasses for other errors
  Future<VenueOptions> getVenueOptions(String dateId) async {
    try {
      _logger.d('🏛️  Getting venue options for date: $dateId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.dates.getVenueOptions(dateId),
      );

      final options = VenueOptions.fromJson(response);
      _logger.d(
          '✅ Got ${options.options.length} venue options (ranked: ${options.myRankings.isNotEmpty})');
      return options;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to get venue options', error: e);
      rethrow;
    }
  }

  /// Submit venue rankings
  ///
  /// Returns ranking submission response with assignment info.
  ///
  /// Throws:
  /// - [ValidationException] if rankings invalid (400)
  /// - [ConflictException] if wrong state, already ranked, or deadline passed (409)
  /// - Other [ApiException] subclasses for other errors
  Future<RankingSubmissionResponse> submitVenueRankings(
    String dateId,
    SubmitRankingsRequest request,
  ) async {
    try {
      _logger.d(
          '📤 Submitting venue rankings for date: $dateId (${request.rankings.length} venues)');

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.dates.submitVenueRankings(dateId),
        data: request.toJson(),
      );

      final result = RankingSubmissionResponse.fromJson(response);
      _logger.d(
          '✅ Rankings submitted (venueAssigned: ${result.venueAssigned})');
      return result;
    } on ValidationException catch (e) {
      _logger.w('⚠️  Validation error: ${e.message}');
      rethrow;
    } on ConflictException catch (e) {
      _logger.w('⚠️  Conflict: ${e.message}');
      rethrow;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to submit rankings', error: e);
      rethrow;
    }
  }

  /// Get presence confirmation status
  ///
  /// Returns presence status for both participants.
  /// Only available when state is AWAITING_PRESENCE_CONFIRMATION.
  ///
  /// Throws:
  /// - [ConflictException] if wrong state (409)
  /// - Other [ApiException] subclasses for other errors
  Future<PresenceConfirmationStatus> getPresenceStatus(String dateId) async {
    try {
      _logger.d('🔍 Getting presence status for date: $dateId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.dates.getPresenceStatus(dateId),
      );

      final status = PresenceConfirmationStatus.fromJson(response);
      _logger.d('✅ Got presence status');
      return status;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to get presence status', error: e);
      rethrow;
    }
  }

  /// Confirm presence for date
  ///
  /// Returns presence confirmation status for both participants.
  ///
  /// Throws:
  /// - [ConflictException] if wrong state, already confirmed, or outside window (409)
  /// - Other [ApiException] subclasses for other errors
  Future<PresenceConfirmationStatus> confirmPresence(String dateId) async {
    try {
      _logger.d('✅ Confirming presence for date: $dateId');

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.dates.confirmPresence(dateId),
      );

      final status = PresenceConfirmationStatus.fromJson(response);
      _logger.d('✅ Presence confirmed');
      return status;
    } on ConflictException catch (e) {
      _logger.w('⚠️  Conflict: ${e.message}');
      rethrow;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to confirm presence', error: e);
      rethrow;
    }
  }

  /// Cancel date
  ///
  /// Returns cancellation result with refund info.
  ///
  /// Throws:
  /// - [ConflictException] if date already terminal or scheduled end passed (409)
  /// - Other [ApiException] subclasses for other errors
  Future<CancellationResult> cancelDate(
    String dateId,
    CancelDateRequest request,
  ) async {
    try {
      _logger.d('🚫 Cancelling date: $dateId');

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.dates.cancel(dateId),
        data: request.toJson(),
      );

      final result = CancellationResult.fromJson(response);
      _logger.d('✅ Date cancelled (tier: ${result.tier})');
      return result;
    } on ConflictException catch (e) {
      _logger.w('⚠️  Conflict: ${e.message}');
      rethrow;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to cancel date', error: e);
      rethrow;
    }
  }
}
