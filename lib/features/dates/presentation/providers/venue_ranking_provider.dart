import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';
import 'package:eros_app/core/network/api_client_provider.dart';

/// Provider for venue options (UI-7)
///
/// Fetches venue options for ranking.
/// Use `.future` to await initial load, then `.notifier` to submit rankings.
final venueOptionsProvider = FutureProvider.autoDispose
    .family<VenueOptions, String>((ref, dateId) async {
  final repository = ref.watch(datesRepositoryProvider);
  return repository.getVenueOptions(dateId);
});

/// Notifier for venue ranking mutations
final venueRankingProvider =
    Provider.autoDispose.family<VenueRankingNotifier, String>((ref, dateId) {
  final repository = ref.watch(datesRepositoryProvider);
  return VenueRankingNotifier(repository, dateId);
});

class VenueRankingNotifier {
  final DatesRepository _repository;
  final String _dateId;

  VenueRankingNotifier(this._repository, this._dateId);

  /// Submit venue rankings
  ///
  /// Returns [RankingSubmissionResponse] with:
  /// - bothSubmitted: true if both participants have ranked
  /// - venueAssigned: true if a venue was assigned
  /// - assignedVenueId: ID of assigned venue (null if not assigned)
  ///
  /// Throws:
  /// - [ValidationException] if rankings invalid (400)
  /// - [ConflictException] if wrong state or already ranked (409)
  /// - Other [ApiException] subclasses for other errors
  Future<RankingSubmissionResponse> submitRankings(
      SubmitRankingsRequest request) async {
    return _repository.submitVenueRankings(_dateId, request);
  }
}

/// Repository provider (reuse from existing dates module)
final datesRepositoryProvider = Provider<DatesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DatesRepository(apiClient);
});
