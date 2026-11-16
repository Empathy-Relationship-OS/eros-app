import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/wallet/data/repositories/wallet_repository.dart';
import 'package:eros_app/features/wallet/domain/models/wallet_models.dart';
import 'package:eros_app/features/wallet/presentation/providers/refund_provider.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:eros_app/features/wallet/presentation/widgets/wallet_copy.dart';

void main() {
  late _FakeWalletRepository repository;
  late ProviderContainer container;
  late PurchaseRefunder refunder;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _FakeWalletRepository();
    container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    refunder = container.read(purchaseRefunderProvider);
  });

  RefundResponse accepted() =>
      RefundResponse(transactionId: 99, clientSecret: 're_123', status: 'succeeded');

  group('the idempotency key', () {
    test('is reused after a timeout, so the retry can\'t refund twice', () async {
      repository.answers = [
        () => throw const NetworkException('timeout'),
        accepted,
      ];

      final first = await refunder.refund(_purchase);
      final second = await refunder.refund(_purchase);

      expect(first.kind, RefundResultKind.failed);
      expect(first.message, WalletCopy.refundNoConnection);
      expect(second.kind, RefundResultKind.refunded);
      expect(repository.keys, hasLength(2));
      expect(repository.keys[0], repository.keys[1]);
    });

    test('is reused after a server error, where the refund may have gone through', () async {
      repository.answers = [
        () => throw const ServerException('Internal server error'),
        accepted,
      ];

      final first = await refunder.refund(_purchase);
      await refunder.refund(_purchase);

      expect(first.kind, RefundResultKind.unconfirmed);
      expect(first.message, WalletCopy.refundUnconfirmed);
      expect(repository.keys[0], repository.keys[1]);
    });

    test('is replaced after a refusal, which the backend stores against the key', () async {
      repository.answers = [
        () => throw const ConflictException('Transaction has already been refunded or not refundable.'),
        accepted,
      ];

      await refunder.refund(_purchase);
      await refunder.refund(_purchase);

      expect(repository.keys[0], isNot(repository.keys[1]));
    });
  });

  group('what the backend says', () {
    test('a refund the provider took is a refund, and the wallet is refreshed', () async {
      repository.answers = [accepted];

      final result = await refunder.refund(_purchase);

      expect(result.kind, RefundResultKind.refunded);
      expect(refunder.wasRefunded(_purchase.transactionId), isTrue);
      expect(repository.balanceFetches, 1);
      expect(repository.historyFetches, 1);
    });

    test('a stored refusal replayed as a 201 is still a refusal', () async {
      repository.answers = [
        () => RefundResponse(transactionId: 99, clientSecret: 'error', status: 'REFUND_FAILED'),
      ];

      final result = await refunder.refund(_purchase);

      expect(result.kind, RefundResultKind.refused);
      expect(result.message, WalletCopy.refundNotAllowed);
      expect(refunder.wasRefunded(_purchase.transactionId), isFalse);
      expect(repository.balanceFetches, 0);
    });

    test('a refund the provider never took is not called a success', () async {
      repository.answers = [
        () => RefundResponse(transactionId: 99, clientSecret: '', status: 'PENDING'),
      ];

      final result = await refunder.refund(_purchase);

      expect(result.kind, RefundResultKind.unconfirmed);
      expect(refunder.wasRefunded(_purchase.transactionId), isFalse);
      // The tokens may have gone, so the wallet is brought up to date.
      expect(repository.balanceFetches, 1);
    });

    test('too few tokens in the wallet gets its own plain reason', () async {
      repository.answers = [
        () => throw const ValidationException('Insufficient tokens in wallet. Need 3.00, have 1.00'),
      ];

      final result = await refunder.refund(_purchase);

      expect(result.kind, RefundResultKind.refused);
      expect(result.message, WalletCopy.refundTokensMissing);
    });

    test('a banned account is refused without the backend\'s wording', () async {
      repository.answers = [
        () => throw const ForbiddenException('A banned account can\'t refund token purchases.'),
      ];

      final result = await refunder.refund(_purchase);

      expect(result.kind, RefundResultKind.refused);
      expect(result.message, WalletCopy.refundAccountBlocked);
    });

    test('a purchase the backend can\'t find can be tried again', () async {
      repository.answers = [() => throw const NotFoundException('Transaction not found')];

      final result = await refunder.refund(_purchase);

      expect(result.kind, RefundResultKind.failed);
      expect(result.message, WalletCopy.refundPurchaseNotFound);
    });
  });

  test('a purchase with no card payment is never sent', () async {
    final result = await refunder.refund(_transaction(paymentIntent: null));

    expect(result.kind, RefundResultKind.refused);
    expect(repository.keys, isEmpty);
  });

  test('a second call while the first is in flight sends nothing', () async {
    repository.answers = [accepted];

    final results = await Future.wait([refunder.refund(_purchase), refunder.refund(_purchase)]);

    expect(results.map((r) => r.kind), everyElement(RefundResultKind.refunded));
    expect(repository.keys, hasLength(1));
  });
}

final Transaction _purchase = _transaction(paymentIntent: 'pi_123');

Transaction _transaction({required String? paymentIntent}) {
  final at = DateTime.now().toUtc().subtract(const Duration(days: 1));
  return Transaction(
    transactionId: 1,
    type: TransactionType.purchase,
    amount: 3,
    balanceAfter: 3,
    description: 'Purchased 3.00 tokens',
    stripePaymentIntentId: paymentIntent,
    amountPaid: 2000,
    paymentCurrency: 'GBP',
    createdAt: at,
    updatedAt: at,
    status: TransactionStatus.completed,
  );
}

/// Answers each refund request with the next of [answers], and records the key it came with.
class _FakeWalletRepository implements WalletRepository {
  List<RefundResponse Function()> answers = [];
  final List<String> keys = [];
  int balanceFetches = 0;
  int historyFetches = 0;

  @override
  Future<RefundResponse> refundTokens({
    required int transactionId,
    required String stripePaymentIntent,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    return answers.removeAt(0)();
  }

  @override
  Future<WalletBalance> getBalance() async {
    balanceFetches++;
    return WalletBalance(
      balance: 0,
      pendingBalance: 0,
      lifetimeSpent: 0,
      lifetimePurchased: 3,
      currency: 'GBP',
    );
  }

  @override
  Future<TransactionHistory> getTransactions({
    required int limit,
    required int offset,
    String? type,
    List<TransactionStatus>? statuses,
  }) async {
    historyFetches++;
    return TransactionHistory(transactions: const [], total: 0, hasMore: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Fake method ${invocation.memberName} not implemented: a refund should not call it',
      );
}
