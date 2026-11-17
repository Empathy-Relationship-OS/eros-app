import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/wallet/data/repositories/wallet_repository.dart';
import 'package:eros_app/features/wallet/domain/models/wallet_models.dart';
import 'package:eros_app/features/wallet/presentation/providers/purchase_provider.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:eros_app/features/wallet/presentation/widgets/wallet_copy.dart';
import 'package:eros_app/features/wallet/services/idempotency_manager.dart';

/// How a refund request ended.
enum RefundResultKind {
  /// The backend took the refund: the tokens are out and the money is on its way back.
  refunded,

  /// The backend said no and changed nothing. Asking again from the same sheet won't help.
  refused,

  /// The request didn't get an answer, or got one that may differ next time. Asking again is
  /// safe: it goes out under the same idempotency key.
  failed,

  /// The request may have gone through. The wallet has been refreshed so the person can see.
  unconfirmed,
}

/// The end of one refund request, with the words to show for anything but a success.
class RefundResult {
  final RefundResultKind kind;

  /// Null when [kind] is [RefundResultKind.refunded]: the sheet has its own success step.
  final String? message;

  const RefundResult._(this.kind, this.message);

  const RefundResult.refunded() : this._(RefundResultKind.refunded, null);
  const RefundResult.refused(String message) : this._(RefundResultKind.refused, message);
  const RefundResult.failed(String message) : this._(RefundResultKind.failed, message);
  const RefundResult.unconfirmed()
      : this._(RefundResultKind.unconfirmed, WalletCopy.refundUnconfirmed);

  bool get isRefunded => kind == RefundResultKind.refunded;
}

/// Asks the backend to refund a token purchase (`POST /wallet/refund`) and brings the wallet
/// up to date afterwards.
///
/// It lives in a provider, not in the sheet, so a request still finishes and the wallet still
/// refreshes if the sheet is swiped away while it is in flight.
class PurchaseRefunder {
  final WalletRepository _repository;
  final IdempotencyManager _keys;
  final Ref _ref;
  final Logger _logger = Logger();

  final Map<int, Future<RefundResult>> _inFlight = {};
  final Set<int> _refunded = {};

  PurchaseRefunder(this._repository, this._keys, this._ref);

  /// Whether this purchase was refunded since the app started. The history can't say: the
  /// backend leaves a refunded purchase's row as it was and adds a refund row that doesn't
  /// name it.
  bool wasRefunded(int transactionId) => _refunded.contains(transactionId);

  /// Refunds [purchase] in full. A second call for the same purchase while the first is still
  /// going returns the first one's result and sends nothing.
  Future<RefundResult> refund(Transaction purchase) {
    final id = purchase.transactionId;
    // Refunded already, from a sheet opened while that refund was in flight: say so and send
    // nothing. A second request would go out under a new key and come back refused.
    if (_refunded.contains(id)) return Future.value(const RefundResult.refunded());
    // A block body: an arrow would hand whenComplete the removed future, its own, to wait on.
    return _inFlight[id] ??= _refund(purchase).whenComplete(() {
      _inFlight.remove(id);
    });
  }

  Future<RefundResult> _refund(Transaction purchase) async {
    final paymentIntent = purchase.stripePaymentIntentId;
    if (!purchase.canRefund || paymentIntent == null) {
      return const RefundResult.refused(WalletCopy.refundUnavailable);
    }

    // One key per purchase, kept until the backend gives a definite answer. If the request
    // times out after the backend acted on it, the retry carries the same key and gets the
    // first attempt's result back instead of a second refund.
    final operation = 'refund_${purchase.transactionId}';

    try {
      final key = await _keys.getOrCreateKey(operation);
      final response = await _repository.refundTokens(
        transactionId: purchase.transactionId,
        stripePaymentIntent: paymentIntent,
        idempotencyKey: key,
      );

      switch (response.outcome) {
        case RefundOutcome.accepted:
          _refunded.add(purchase.transactionId);
          await _keys.clearKey(operation);
          await _refreshWallet();
          return const RefundResult.refunded();
        case RefundOutcome.refused:
          // A refusal is stored against its key, so the key has to go or every later attempt
          // would get this same refusal back.
          await _keys.clearKey(operation);
          return const RefundResult.refused(WalletCopy.refundNotAllowed);
        case RefundOutcome.unconfirmed:
          await _refreshWallet();
          return const RefundResult.unconfirmed();
      }
    } on ConflictException {
      await _keys.clearKey(operation);
      return const RefundResult.refused(WalletCopy.refundNotAllowed);
    } on ValidationException catch (e) {
      await _keys.clearKey(operation);
      return e.message.toLowerCase().contains('insufficient')
          ? const RefundResult.refused(WalletCopy.refundTokensMissing)
          : const RefundResult.failed(WalletCopy.refundTryAgain);
    } on ForbiddenException {
      await _keys.clearKey(operation);
      return const RefundResult.refused(WalletCopy.refundAccountBlocked);
    } on NotFoundException {
      await _keys.clearKey(operation);
      return const RefundResult.failed(WalletCopy.refundPurchaseNotFound);
    } on NetworkException {
      // Covers timeouts, so the backend may have acted. The key stays for the retry.
      return const RefundResult.failed(WalletCopy.refundNoConnection);
    } on UnauthorizedException {
      return const RefundResult.failed(WalletCopy.refundTryAgain);
    } on RateLimitException {
      return const RefundResult.failed(WalletCopy.refundTryAgain);
    } catch (e) {
      // A server error, or a reply we couldn't read: the backend takes the tokens before it
      // calls the payment provider, so either may have happened. The key stays.
      _logger.e('Refund of purchase ${purchase.transactionId} ended without an answer: $e');
      await _refreshWallet();
      return const RefundResult.unconfirmed();
    }
  }

  Future<void> _refreshWallet() async {
    await Future.wait([
      _ref.read(walletBalanceProvider.notifier).refresh(),
      _ref.read(transactionHistoryProvider.notifier).refresh(),
    ]);
  }
}

/// Provider for [PurchaseRefunder]
final purchaseRefunderProvider = Provider<PurchaseRefunder>((ref) {
  return PurchaseRefunder(
    ref.watch(walletRepositoryProvider),
    ref.watch(idempotencyManagerProvider),
    ref,
  );
});
