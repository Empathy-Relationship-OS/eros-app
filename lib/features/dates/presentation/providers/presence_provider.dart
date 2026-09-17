import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';
import 'package:eros_app/core/network/api_client.dart';

/// Provider for presence confirmation (UI-8)
///
/// Fetches presence status when state is AWAITING_PRESENCE_CONFIRMATION.
/// Use `.notifier` to confirm presence.
final presenceProvider = FutureProvider.autoDispose
    .family<PresenceConfirmationStatus?, String>((ref, dateId) async {
  final repository = ref.watch(datesRepositoryProvider);
  try {
    return await repository.getPresenceStatus(dateId);
  } catch (e) {
    // Return null if not available yet
    return null;
  }
});

/// Notifier for presence confirmation mutations
final presenceNotifierProvider =
    Provider.autoDispose.family<PresenceNotifier, String>((ref, dateId) {
  final repository = ref.watch(datesRepositoryProvider);
  return PresenceNotifier(repository, dateId);
});

class PresenceNotifier {
  final DatesRepository _repository;
  final String _dateId;

  PresenceNotifier(this._repository, this._dateId);

  /// Confirm presence for the date
  ///
  /// Returns [PresenceConfirmationStatus] with:
  /// - you: true (always, since this user just confirmed)
  /// - partner: true if partner has also confirmed
  ///
  /// Throws:
  /// - [ConflictException] if wrong state, already confirmed, or too early (409)
  /// - Other [ApiException] subclasses for other errors
  Future<PresenceConfirmationStatus> confirmPresence() async {
    return _repository.confirmPresence(_dateId);
  }
}

/// Repository provider (reuse from existing dates module)
final datesRepositoryProvider = Provider<DatesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DatesRepository(apiClient);
});
