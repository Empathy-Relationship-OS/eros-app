import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:eros_app/features/wallet/data/repositories/wallet_repository.dart';
import 'package:eros_app/features/wallet/domain/models/wallet_models.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_provider.dart';

void main() {
  late _SlowWalletRepository repository;

  setUp(() => repository = _SlowWalletRepository());

  group('the balance', () {
    test('a refresh during a fetch ends with a fetch that started after it', () async {
      final notifier = WalletBalanceNotifier(repository);
      addTearDown(notifier.dispose);

      // A fetch starts before the change, and answers with the balance from before it.
      final early = notifier.fetchBalance();
      repository.balance = 0;
      final refreshed = notifier.refresh();
      await pumpEventQueue();
      expect(repository.balanceCalls, 1, reason: 'the refresh waits for the fetch under way');

      repository.answerNextBalance();
      await early;

      // The refresh's own fetch, started after the change.
      await pumpEventQueue();
      expect(repository.balanceCalls, 2);
      repository.answerNextBalance();
      await refreshed;

      expect(notifier.state.balance!.balance, 0);
      expect(notifier.state.isLoading, isFalse);
    });

    test('two fetches at once make one request', () async {
      final notifier = WalletBalanceNotifier(repository);
      addTearDown(notifier.dispose);

      final both = Future.wait([notifier.fetchBalance(), notifier.fetchBalance()]);
      repository.answerNextBalance();
      await both;

      expect(repository.balanceCalls, 1);
    });
  });

  group('the history', () {
    test('a refresh during a fetch ends with a fetch that started after it', () async {
      final notifier = TransactionHistoryNotifier(repository);
      addTearDown(notifier.dispose);

      final early = notifier.fetchTransactions();
      repository.transactions = [_refund];
      final refreshed = notifier.refresh();
      await pumpEventQueue();
      expect(repository.historyCalls, 1, reason: 'the refresh waits for the fetch under way');

      repository.answerNextHistory();
      await early;
      await pumpEventQueue();
      expect(repository.historyCalls, 2);
      repository.answerNextHistory();
      await refreshed;

      expect(notifier.state.transactions, [_refund]);
      expect(notifier.state.isLoading, isFalse);
    });
  });
}

final Transaction _refund = Transaction(
  transactionId: 99,
  type: TransactionType.refund,
  amount: 3,
  balanceAfter: 0,
  description: 'Refund of 3.00',
  createdAt: DateTime.utc(2026, 11, 17),
  updatedAt: DateTime.utc(2026, 11, 17),
  status: TransactionStatus.completed,
);

/// Holds each request until the test answers it, with whatever the wallet holds at that point.
class _SlowWalletRepository implements WalletRepository {
  double balance = 3;
  List<Transaction> transactions = const [];
  int balanceCalls = 0;
  int historyCalls = 0;
  final List<Completer<void>> _balanceGates = [];
  final List<Completer<void>> _historyGates = [];

  /// Each request reads the wallet when it is sent, as the backend would.
  void answerNextBalance() => _balanceGates.removeAt(0).complete();
  void answerNextHistory() => _historyGates.removeAt(0).complete();

  @override
  Future<WalletBalance> getBalance() async {
    balanceCalls++;
    final seen = balance;
    final gate = Completer<void>();
    _balanceGates.add(gate);
    await gate.future;
    return WalletBalance(
      balance: seen,
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
    historyCalls++;
    final seen = transactions;
    final gate = Completer<void>();
    _historyGates.add(gate);
    await gate.future;
    return TransactionHistory(transactions: seen, total: seen.length, hasMore: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Fake method ${invocation.memberName} not implemented',
      );
}
