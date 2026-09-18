import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';

/// State for date cancellation
class CancelState {
  final bool isLoading;
  final CancellationResult? result;
  final String? errorMessage;

  const CancelState({
    this.isLoading = false,
    this.result,
    this.errorMessage,
  });

  CancelState copyWith({
    bool? isLoading,
    CancellationResult? result,
    String? errorMessage,
  }) {
    return CancelState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider for cancelling a date
class CancelNotifier extends StateNotifier<CancelState> {
  final Ref ref;
  final String dateId;

  CancelNotifier(this.ref, this.dateId) : super(const CancelState());

  /// Cancel the date with optional reason
  Future<void> cancelDate({String? reason}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final repository = ref.read(datesRepositoryProvider);
      final request = CancelDateRequest(reason: reason);
      final result = await repository.cancelDate(dateId, request);

      state = state.copyWith(
        isLoading: false,
        result: result,
      );
    } on ConflictException catch (e) {
      // Date already moved on (expired/completed/cancelled)
      // Don't treat as error - trigger refetch instead
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'conflict', // Special marker for refetch
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to cancel date',
      );
    }
  }

  void reset() {
    state = const CancelState();
  }
}

/// Provider family for date cancellation
final cancelProvider =
    StateNotifierProvider.family<CancelNotifier, CancelState, String>(
  (ref, dateId) => CancelNotifier(ref, dateId),
);
