import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';
import 'package:eros_app/core/network/api_client.dart';

/// Provider for availability view (UI-5)
///
/// Fetches availability slots for a specific date.
/// Use `.future` to await initial load, then `.notifier` to submit.
final availabilityProvider = FutureProvider.autoDispose
    .family<AvailabilityView, String>((ref, dateId) async {
  final repository = ref.watch(datesRepositoryProvider);
  return repository.getAvailability(dateId);
});

/// Notifier for availability mutations
final availabilityNotifierProvider =
    Provider.autoDispose.family<AvailabilityNotifier, String>((ref, dateId) {
  final repository = ref.watch(datesRepositoryProvider);
  return AvailabilityNotifier(repository, dateId);
});

class AvailabilityNotifier {
  final DatesRepository _repository;
  final String _dateId;

  AvailabilityNotifier(this._repository, this._dateId);

  /// Submit availability slots
  ///
  /// Returns [AvailabilityView] after submission.
  /// State transition is detected by refetching DateDetail.
  ///
  /// Throws [ApiException] on failure.
  Future<AvailabilityView> submitAvailability(
      SubmitAvailabilityRequest request) async {
    return _repository.submitAvailability(_dateId, request);
  }
}

/// Repository provider (reuse from existing dates module)
final datesRepositoryProvider = Provider<DatesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DatesRepository(apiClient);
});
