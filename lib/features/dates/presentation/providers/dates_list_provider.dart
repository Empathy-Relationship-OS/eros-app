import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';

// ====================
// REPOSITORY PROVIDER
// ====================

/// Provider for DatesRepository
final datesRepositoryProvider = Provider<DatesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DatesRepository(apiClient);
});

// ====================
// STATE MODELS
// ====================

/// State for dates list
class DatesListState {
  final List<DateSummary> dates;
  final bool isLoading;
  final String? errorMessage;

  const DatesListState({
    this.dates = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isEmpty => dates.isEmpty && !isLoading && errorMessage == null;
  bool get hasError => errorMessage != null;

  DatesListState copyWith({
    List<DateSummary>? dates,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DatesListState(
      dates: dates ?? this.dates,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ====================
// STATE NOTIFIER
// ====================

/// Notifier for dates list (active, past, cancelled)
class DatesListNotifier extends StateNotifier<DatesListState> {
  final DatesRepository _repository;
  final String? _filter; // 'active', 'past', 'cancelled', or null for all
  final Logger _logger = Logger();

  DatesListNotifier(this._repository, {String? filter})
      : _filter = filter,
        super(const DatesListState()) {
    // Auto-fetch on creation
    fetch();
  }

  /// Fetch dates with current filter
  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      _logger.d('📅 Fetching dates (filter: ${_filter ?? 'all'})');

      final dates = await _repository.fetchDates(filter: _filter);

      // Sort by scheduledStart (nulls last), then by createdAt descending
      dates.sort((a, b) {
        if (a.scheduledStart != null && b.scheduledStart != null) {
          return a.scheduledStart!.compareTo(b.scheduledStart!);
        } else if (a.scheduledStart != null) {
          return -1; // a comes first
        } else if (b.scheduledStart != null) {
          return 1; // b comes first
        } else {
          return b.createdAt.compareTo(a.createdAt); // Most recent first
        }
      });

      state = state.copyWith(
        dates: dates,
        isLoading: false,
      );

      _logger.d('✅ Fetched ${dates.length} dates');
    } catch (e, stackTrace) {
      _logger.e('🚨 Failed to fetch dates', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Refresh dates list
  Future<void> refresh() async {
    await fetch();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ====================
// PROVIDER INSTANCES
// ====================

/// Provider for active dates list
final activeDatesProvider =
    StateNotifierProvider<DatesListNotifier, DatesListState>((ref) {
  final repository = ref.watch(datesRepositoryProvider);
  return DatesListNotifier(repository, filter: 'active');
});

/// Provider for past dates list
final pastDatesProvider =
    StateNotifierProvider<DatesListNotifier, DatesListState>((ref) {
  final repository = ref.watch(datesRepositoryProvider);
  return DatesListNotifier(repository, filter: 'past');
});

/// Provider for cancelled dates list
final cancelledDatesProvider =
    StateNotifierProvider<DatesListNotifier, DatesListState>((ref) {
  final repository = ref.watch(datesRepositoryProvider);
  return DatesListNotifier(repository, filter: 'cancelled');
});
