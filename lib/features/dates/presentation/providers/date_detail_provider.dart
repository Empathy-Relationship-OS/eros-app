import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_list_provider.dart';

// ====================
// STATE MODEL
// ====================

/// State for date detail screen
class DateDetailState {
  final DateDetail? dateDetail;
  final bool isLoading;
  final String? errorMessage;

  const DateDetailState({
    this.dateDetail,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;

  DateDetailState copyWith({
    DateDetail? dateDetail,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DateDetailState(
      dateDetail: dateDetail ?? this.dateDetail,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ====================
// STATE NOTIFIER
// ====================

/// Notifier for date detail screen
class DateDetailNotifier extends StateNotifier<DateDetailState> {
  final DatesRepository _repository;
  final String _dateId;
  final Logger _logger = Logger();

  // Request generation counter to prevent race conditions
  int _requestGeneration = 0;

  DateDetailNotifier(this._repository, this._dateId)
      : super(const DateDetailState()) {
    // Auto-fetch on creation
    fetch();
  }

  /// Fetch date detail
  Future<void> fetch() async {
    // Increment generation before starting fetch
    final currentGeneration = ++_requestGeneration;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      _logger.d('📅 Fetching date detail: $_dateId (gen: $currentGeneration)');

      final dateDetail = await _repository.getDateById(_dateId);

      // Check if this response is still valid (not superseded by newer request)
      if (currentGeneration != _requestGeneration || !mounted) {
        _logger.d('⚠️  Discarding stale response (gen: $currentGeneration, current: $_requestGeneration)');
        return;
      }

      if (dateDetail == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Date not found',
        );
        return;
      }

      state = state.copyWith(
        dateDetail: dateDetail,
        isLoading: false,
      );

      _logger.d('✅ Fetched date detail (state: ${dateDetail.state})');
    } catch (e, stackTrace) {
      // Only update state if this request is still current
      if (currentGeneration == _requestGeneration && mounted) {
        _logger.e('🚨 Failed to fetch date detail', error: e, stackTrace: stackTrace);
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        );
      }
    }
  }

  /// Refresh date detail (for refetch after actions)
  Future<void> refresh() async {
    await fetch();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ====================
// PROVIDER
// ====================

/// Provider family for date detail by ID
/// Uses autoDispose to clean up when screen is no longer active
final dateDetailProvider = StateNotifierProvider.autoDispose.family<
    DateDetailNotifier,
    DateDetailState,
    String>((ref, dateId) {
  final repository = ref.watch(datesRepositoryProvider);
  return DateDetailNotifier(repository, dateId);
});
