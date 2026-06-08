import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/wallet/domain/models/wallet_models.dart';

/// Repository for wallet-related API operations
class WalletRepository {
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  WalletRepository(this._apiClient);

  /// Get wallet balance
  ///
  /// Retrieves current wallet balance and statistics for the authenticated user.
  ///
  /// Returns:
  /// - [WalletBalance] on success (200)
  ///
  /// Throws:
  /// - [UnauthorizedException] if not authenticated (401)
  /// - [NotFoundException] if wallet doesn't exist (404)
  /// - Other [ApiException] subclasses for other errors
  Future<WalletBalance> getBalance() async {
    try {
      _logger.d('💰 Fetching wallet balance');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.wallet.getBalance(),
      );

      final balance = WalletBalance.fromJson(response);
      _logger.d(
        '✅ Balance: ${balance.formattedBalance} tokens (available: ${balance.formattedAvailableBalance})',
      );

      return balance;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to fetch balance: ${e.message}');
      rethrow;
    }
  }

  /// Get transaction history
  ///
  /// Retrieves paginated transaction history with optional filtering.
  ///
  /// Parameters:
  /// - [limit]: Number of transactions to fetch (1-100)
  /// - [offset]: Pagination offset
  /// - [type]: Optional filter by transaction type (PURCHASE, SPEND, REFUND, ADJUSTMENT)
  ///
  /// Returns:
  /// - [TransactionHistory] on success (200)
  ///
  /// Throws:
  /// - [ValidationException] if invalid parameters (400)
  /// - [UnauthorizedException] if not authenticated (401)
  /// - Other [ApiException] subclasses for other errors
  Future<TransactionHistory> getTransactions({
    required int limit,
    required int offset,
    String? type,
  }) async {
    try {
      _logger.d('📜 Fetching transactions (limit=$limit, offset=$offset, type=$type)');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.wallet.getTransactions(
          limit: limit,
          offset: offset,
          type: type,
        ),
      );

      final history = TransactionHistory.fromJson(response);
      _logger.d(
        '✅ Fetched ${history.transactions.length} transactions (total: ${history.total}, hasMore: ${history.hasMore})',
      );

      return history;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to fetch transactions: ${e.message}');
      rethrow;
    }
  }

  /// Purchase tokens
  ///
  /// Initiates a token purchase via Stripe.
  /// Returns a client secret for confirming the payment with Stripe SDK.
  ///
  /// Parameters:
  /// - [packageType]: Type of token package to purchase
  /// - [paymentMethodId]: Stripe payment method ID from Stripe Elements
  /// - [idempotencyKey]: Client-generated UUID for duplicate prevention
  /// - [acceptedTerms]: Must be true
  ///
  /// Returns:
  /// - [PurchaseResponse] with clientSecret for Stripe confirmation (201)
  ///
  /// Throws:
  /// - [ValidationException] if invalid parameters (400)
  /// - [UnauthorizedException] if not authenticated (401)
  /// - Other [ApiException] subclasses for other errors
  Future<PurchaseResponse> purchaseTokens({
    required TokenPackageType packageType,
    required String paymentMethodId,
    required String idempotencyKey,
    required bool acceptedTerms,
  }) async {
    try {
      _logger.d('🛒 Purchasing ${packageType.displayName} package (${packageType.tokens} tokens)');

      final requestBody = {
        'packageType': packageType.apiValue,
        'paymentMethodId': paymentMethodId,
        'idempotencyKey': idempotencyKey,
        'acceptedTerms': acceptedTerms,
      };

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.wallet.purchase(),
        data: requestBody,
      );

      final purchase = PurchaseResponse.fromJson(response);
      _logger.d('✅ Purchase initiated: ${purchase.tokenAmount} tokens, status: ${purchase.status}');

      return purchase;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to purchase tokens: ${e.message}');
      rethrow;
    }
  }

  /// Spend tokens on a date
  ///
  /// Spends tokens to commit to a date.
  ///
  /// Parameters:
  /// - [relatedDateId]: ID of the date to commit to
  /// - [activity]: Type of date activity
  /// - [idempotencyKey]: Client-generated UUID for duplicate prevention
  ///
  /// Returns:
  /// - [Transaction] on success (201)
  ///
  /// Throws:
  /// - [ValidationException] if invalid parameters or insufficient balance (400)
  /// - [UnauthorizedException] if not authenticated (401)
  /// - [ConflictException] if already paid for this date (409)
  /// - Other [ApiException] subclasses for other errors
  Future<Transaction> spendTokens({
    required int relatedDateId,
    required String activity,
    required String idempotencyKey,
  }) async {
    try {
      _logger.d('💸 Spending tokens on date $relatedDateId ($activity)');

      final requestBody = {
        'relatedDateId': relatedDateId,
        'activity': activity,
        'idempotencyKey': idempotencyKey,
      };

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.wallet.spend(),
        data: requestBody,
      );

      final transaction = Transaction.fromJson(response);
      _logger.d('✅ Spent ${transaction.amount.abs()} tokens. New balance: ${transaction.balanceAfter}');

      return transaction;
    } on ValidationException catch (e) {
      if (e.message.contains('insufficient') || e.message.contains('balance')) {
        _logger.w('⚠️  Insufficient balance to spend tokens');
      } else {
        _logger.e('🚨 Validation error: ${e.message}');
      }
      rethrow;
    } on ConflictException {
      _logger.w('⚠️  Already paid for date $relatedDateId');
      rethrow;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to spend tokens: ${e.message}');
      rethrow;
    }
  }

  /// Request refund for a purchase
  ///
  /// Requests a refund for a token purchase.
  ///
  /// Parameters:
  /// - [transactionId]: ID of the purchase transaction to refund
  /// - [stripePaymentIntent]: Stripe payment intent ID
  /// - [idempotencyKey]: Client-generated UUID for duplicate prevention
  ///
  /// Returns:
  /// - [RefundResponse] on success (201)
  ///
  /// Throws:
  /// - [ValidationException] if invalid parameters (400)
  /// - [UnauthorizedException] if not authenticated (401)
  /// - [NotFoundException] if transaction not found (404)
  /// - [ConflictException] if transaction already refunded (409)
  /// - Other [ApiException] subclasses for other errors
  Future<RefundResponse> refundTokens({
    required int transactionId,
    required String stripePaymentIntent,
    required String idempotencyKey,
  }) async {
    try {
      _logger.d('♻️  Requesting refund for transaction $transactionId');

      final requestBody = {
        'transactionId': transactionId,
        'stripePaymentIntent': stripePaymentIntent,
        'idempotencyKey': idempotencyKey,
      };

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.wallet.refund(),
        data: requestBody,
      );

      final refund = RefundResponse.fromJson(response);
      _logger.d('✅ Refund processed: ${refund.status}');

      return refund;
    } on ConflictException {
      _logger.w('⚠️  Transaction $transactionId already refunded');
      rethrow;
    } on NotFoundException {
      _logger.e('🚫 Transaction $transactionId not found');
      rethrow;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to refund tokens: ${e.message}');
      rethrow;
    }
  }
}
