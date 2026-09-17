import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';
import 'package:eros_app/core/network/api_client.dart';

/// Provider for deposit payment (UI-6)
///
/// Use `.notifier` to pay deposit.
final depositProvider =
    Provider.autoDispose.family<DepositNotifier, String>((ref, dateId) {
  final repository = ref.watch(datesRepositoryProvider);
  return DepositNotifier(repository, dateId);
});

class DepositNotifier {
  final DatesRepository _repository;
  final String _dateId;

  DepositNotifier(this._repository, this._dateId);

  /// Pay deposit for the date
  ///
  /// Returns [DepositPaymentResponse] with:
  /// - newBalance: updated wallet balance
  /// - bothPaid: true if both participants have paid
  /// - transitionedToRanking: true if ready to rank venues
  ///
  /// Throws:
  /// - [ConflictException] with 'insufficient_balance' if not enough tokens
  /// - [ConflictException] if wrong state, already paid, or deadline passed
  /// - Other [ApiException] subclasses for other errors
  Future<DepositPaymentResponse> payDeposit() async {
    return _repository.payDeposit(_dateId);
  }
}

/// Repository provider (reuse from existing dates module)
final datesRepositoryProvider = Provider<DatesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DatesRepository(apiClient);
});
