import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/wallet/data/repositories/wallet_repository.dart';
import 'package:eros_app/features/wallet/domain/models/wallet_models.dart';

// ====================
// REPOSITORY PROVIDERS
// ====================

/// Provider for WalletRepository
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WalletRepository(apiClient);
});

// ====================
// STATE MODELS
// ====================

/// State for wallet balance and statistics
class WalletBalanceState {
  final WalletBalance? balance;
  final bool isLoading;
  final String? errorMessage;

  const WalletBalanceState({
    this.balance,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasBalance => balance != null;
  bool get hasError => errorMessage != null;

  WalletBalanceState copyWith({
    WalletBalance? balance,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WalletBalanceState(
      balance: balance ?? this.balance,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// State for transaction history with pagination
class TransactionHistoryState {
  final List<Transaction> transactions;
  final int total;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final int currentOffset;

  const TransactionHistoryState({
    this.transactions = const [],
    this.total = 0,
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.currentOffset = 0,
  });

  bool get hasTransactions => transactions.isNotEmpty;
  bool get hasError => errorMessage != null;

  TransactionHistoryState copyWith({
    List<Transaction>? transactions,
    int? total,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    int? currentOffset,
    bool clearError = false,
  }) {
    return TransactionHistoryState(
      transactions: transactions ?? this.transactions,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentOffset: currentOffset ?? this.currentOffset,
    );
  }
}

// ====================
// STATE NOTIFIERS
// ====================

/// Notifier for wallet balance
class WalletBalanceNotifier extends StateNotifier<WalletBalanceState> {
  final WalletRepository _repository;
  final Logger _logger = Logger();

  WalletBalanceNotifier(this._repository)
      : super(const WalletBalanceState());

  /// Fetch wallet balance
  Future<void> fetchBalance() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final balance = await _repository.getBalance();
      state = state.copyWith(
        balance: balance,
        isLoading: false,
      );
    } on ApiException catch (e) {
      _logger.e('Failed to fetch balance: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      _logger.e('Unexpected error fetching balance: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Refresh balance (force reload)
  Future<void> refresh() async {
    await fetchBalance();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Notifier for transaction history with pagination
class TransactionHistoryNotifier
    extends StateNotifier<TransactionHistoryState> {
  final WalletRepository _repository;
  final Logger _logger = Logger();

  static const int _pageSize = 20;

  TransactionHistoryNotifier(this._repository)
      : super(const TransactionHistoryState());

  /// Fetch initial page of transactions
  Future<void> fetchTransactions({String? filterType}) async {
    if (state.isLoading) return;

    state = const TransactionHistoryState(isLoading: true);

    try {
      final history = await _repository.getTransactions(
        limit: _pageSize,
        offset: 0,
        type: filterType,
      );

      state = TransactionHistoryState(
        transactions: history.transactions,
        total: history.total,
        hasMore: history.hasMore,
        isLoading: false,
        currentOffset: _pageSize,
      );
    } on ApiException catch (e) {
      _logger.e('Failed to fetch transactions: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      _logger.e('Unexpected error fetching transactions: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Load more transactions (pagination)
  Future<void> loadMore({String? filterType}) async {
    if (!state.hasMore || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final history = await _repository.getTransactions(
        limit: _pageSize,
        offset: state.currentOffset,
        type: filterType,
      );

      state = state.copyWith(
        transactions: [...state.transactions, ...history.transactions],
        total: history.total,
        hasMore: history.hasMore,
        isLoadingMore: false,
        currentOffset: state.currentOffset + _pageSize,
      );
    } on ApiException catch (e) {
      _logger.e('Failed to load more transactions: ${e.message}');
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: e.message,
      );
    } catch (e) {
      _logger.e('Unexpected error loading more transactions: $e');
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Refresh transactions (force reload)
  Future<void> refresh({String? filterType}) async {
    await fetchTransactions(filterType: filterType);
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ====================
// PROVIDER INSTANCES
// ====================

/// Provider for wallet balance state
final walletBalanceProvider =
    StateNotifierProvider<WalletBalanceNotifier, WalletBalanceState>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  return WalletBalanceNotifier(repository);
});

/// Provider for transaction history state
final transactionHistoryProvider = StateNotifierProvider<
    TransactionHistoryNotifier, TransactionHistoryState>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  return TransactionHistoryNotifier(repository);
});
