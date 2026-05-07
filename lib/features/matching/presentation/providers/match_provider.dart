import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/matching/data/repositories/match_repository.dart';
import 'package:eros_app/features/matching/data/services/match_storage_service.dart';
import 'package:eros_app/features/matching/domain/models/match_models.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

// ====================
// REPOSITORY PROVIDERS
// ====================

/// Provider for MatchRepository
final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MatchRepository(apiClient);
});

/// Provider for MatchStorageService
final matchStorageServiceProvider = Provider<MatchStorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return MatchStorageService(prefs);
});

// ====================
// STATE MODELS
// ====================

/// State for daily match batch
class MatchBatchState {
  final List<UserMatchProfile> profiles;
  final int batchNumber;
  final int remainingBatches;
  final bool isLoading;
  final String? errorMessage;
  final DateTime? limitResetAt;
  final int? batchesUsed;
  final int? maxBatches;

  const MatchBatchState({
    this.profiles = const [],
    this.batchNumber = 0,
    this.remainingBatches = 0,
    this.isLoading = false,
    this.errorMessage,
    this.limitResetAt,
    this.batchesUsed,
    this.maxBatches,
  });

  bool get hasProfiles => profiles.isNotEmpty;
  bool get isLimitExceeded => limitResetAt != null;
  bool get hasError => errorMessage != null;

  MatchBatchState copyWith({
    List<UserMatchProfile>? profiles,
    int? batchNumber,
    int? remainingBatches,
    bool? isLoading,
    String? errorMessage,
    DateTime? limitResetAt,
    int? batchesUsed,
    int? maxBatches,
    bool clearError = false,
    bool clearLimit = false,
  }) {
    return MatchBatchState(
      profiles: profiles ?? this.profiles,
      batchNumber: batchNumber ?? this.batchNumber,
      remainingBatches: remainingBatches ?? this.remainingBatches,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      limitResetAt: clearLimit ? null : (limitResetAt ?? this.limitResetAt),
      batchesUsed: clearLimit ? null : (batchesUsed ?? this.batchesUsed),
      maxBatches: clearLimit ? null : (maxBatches ?? this.maxBatches),
    );
  }
}

// ====================
// STATE NOTIFIER
// ====================

/// StateNotifier for managing match batch state
class MatchBatchNotifier extends StateNotifier<MatchBatchState> {
  final MatchRepository _repository;
  final MatchStorageService _storageService;
  final Logger _logger = Logger();

  MatchBatchNotifier(this._repository, this._storageService)
      : super(const MatchBatchState()) {
    _checkStoredLimitState();
  }

  /// Check if there's a stored batch limit reset time on initialization
  void _checkStoredLimitState() {
    final resetAt = _storageService.getBatchLimitResetTime();
    if (resetAt != null) {
      state = state.copyWith(limitResetAt: resetAt);
    }
  }

  /// Fetch daily batch of matches
  /// Returns true if successful, false if no matches or limit exceeded
  Future<bool> fetchDailyBatch() async {
    // Check if limit is still active from local storage
    if (_storageService.isBatchLimitActive()) {
      final resetAt = _storageService.getBatchLimitResetTime();
      state = state.copyWith(
        isLoading: false,
        limitResetAt: resetAt,
        errorMessage: 'Daily batch limit exceeded. Try again later.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearLimit: true);

    try {
      final response = await _repository.fetchDailyBatch();

      if (response == null) {
        // No matches available (204 No Content)
        state = state.copyWith(
          isLoading: false,
          profiles: [],
          errorMessage: 'No matches available right now',
        );
        return false;
      }

      // Successfully fetched batch
      state = state.copyWith(
        isLoading: false,
        profiles: response.profiles,
        batchNumber: response.batchNumber,
        remainingBatches: response.remainingBatches,
        clearError: true,
        clearLimit: true,
      );
      return true;
    } on RateLimitException catch (e) {
      // Daily batch limit exceeded - parse DailyBatchLimitError from response
      _logger.w('⏰ Caught RateLimitException in provider');
      _logger.d('Original error type: ${e.originalError.runtimeType}');
      _logger.d('Original error: ${e.originalError}');

      DateTime? resetAt;
      int? batchesUsed;
      int? maxBatches;
      String? errorMessage;

      if (e.originalError is Map<String, dynamic>) {
        try {
          final errorData = e.originalError as Map<String, dynamic>;
          _logger.d('Attempting to parse DailyBatchLimitError from: $errorData');
          final limitError = DailyBatchLimitError.fromJson(errorData);

          resetAt = limitError.resetAt;
          batchesUsed = limitError.batchesUsed;
          maxBatches = limitError.maxBatches;
          errorMessage = limitError.error;

          _logger.d('✅ Parsed DailyBatchLimitError: resetAt=$resetAt, batches=$batchesUsed/$maxBatches');

          // Save to local storage to avoid unnecessary API calls
          await _storageService.saveBatchLimitResetTime(resetAt);
        } catch (parseError, stackTrace) {
          // Failed to parse DailyBatchLimitError, fallback to generic handling
          _logger.e('Failed to parse DailyBatchLimitError', error: parseError, stackTrace: stackTrace);
          errorMessage = 'Daily batch limit exceeded';

          // Try to get resetAt from raw response
          final errorData = e.originalError as Map<String, dynamic>;
          final resetAtString = errorData['resetAt'] as String?;
          if (resetAtString != null) {
            try {
              resetAt = DateTime.parse(resetAtString);
              await _storageService.saveBatchLimitResetTime(resetAt);
            } catch (_) {
              // Use Retry-After header if available
              if (e.retryAfter != null) {
                resetAt = DateTime.now().add(e.retryAfter!);
                await _storageService.saveBatchLimitResetTime(resetAt);
              }
            }
          }
        }
      } else if (e.retryAfter != null) {
        // Fallback: use Retry-After header
        _logger.d('Using Retry-After header fallback');
        resetAt = DateTime.now().add(e.retryAfter!);
        errorMessage = 'Daily batch limit exceeded';
        await _storageService.saveBatchLimitResetTime(resetAt);
      }

      _logger.d('Setting state with limitResetAt: $resetAt');
      state = state.copyWith(
        isLoading: false,
        limitResetAt: resetAt,
        batchesUsed: batchesUsed,
        maxBatches: maxBatches,
        errorMessage: errorMessage ?? 'Daily batch limit exceeded',
      );
      return false;
    } on ApiException catch (e) {
      _logger.e('🚨 Caught ApiException in provider: ${e.runtimeType}');
      _logger.d('Message: ${e.message}, Status: ${e.statusCode}');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e, stackTrace) {
      _logger.e('🚨 Unexpected error in provider', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unexpected error: $e',
      );
      return false;
    }
  }

  /// Remove a profile from the current batch (after user action)
  void removeProfile(int matchId) {
    final updatedProfiles = state.profiles
        .where((profile) => profile.matchId != matchId)
        .toList();

    state = state.copyWith(profiles: updatedProfiles);

    // If no more profiles in current batch and there are remaining batches,
    // auto-fetch the next batch
    if (updatedProfiles.isEmpty && state.remainingBatches > 0) {
      fetchDailyBatch();
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Get time remaining until limit resets
  Duration? getTimeUntilReset() {
    return _storageService.getTimeUntilReset();
  }
}

// ====================
// PROVIDER
// ====================

/// Provider for MatchBatchNotifier
final matchBatchProvider =
    StateNotifierProvider<MatchBatchNotifier, MatchBatchState>((ref) {
  final repository = ref.watch(matchRepositoryProvider);
  final storageService = ref.watch(matchStorageServiceProvider);
  return MatchBatchNotifier(repository, storageService);
});
