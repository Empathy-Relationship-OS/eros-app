import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/features/wallet/data/repositories/wallet_repository.dart';
import 'package:eros_app/features/wallet/domain/models/wallet_models.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:eros_app/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:eros_app/features/wallet/presentation/widgets/purchase_detail_sheet.dart';
import 'package:eros_app/features/wallet/presentation/widgets/wallet_copy.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a purchase in the wallet history', () {
    testWidgets('opens its details with the refund rule and the way to ask', (tester) async {
      final purchase = _purchase(boughtDaysAgo: 2);
      await _pumpWallet(tester, _FakeWalletRepository(transactions: [purchase]));

      await tester.tap(find.text(purchase.description));
      await tester.pumpAndSettle();

      expect(find.byType(PurchaseDetailSheet), findsOneWidget);
      expect(find.text('Popular package'), findsOneWidget);
      expect(find.text('3 tokens'), findsWidgets);
      expect(find.text('£20.00'), findsOneWidget);
      expect(
        find.text(DateFormat('d MMMM y').format(purchase.createdAt.toLocal())),
        findsOneWidget,
      );
      expect(find.text(WalletCopy.refundRule), findsOneWidget);
      expect(find.text(WalletCopy.requestRefund), findsOneWidget);
    });

    testWidgets('past 14 days says so and offers no refund', (tester) async {
      final purchase = _purchase(boughtDaysAgo: 15);
      await _pumpWallet(tester, _FakeWalletRepository(transactions: [purchase]));

      await tester.tap(find.text(purchase.description));
      await tester.pumpAndSettle();

      expect(find.text('Popular package'), findsOneWidget);
      expect(find.text(WalletCopy.refundWindowClosed), findsOneWidget);
      expect(find.text(WalletCopy.refundRule), findsNothing);
      expect(find.text(WalletCopy.requestRefund), findsNothing);
    });

    testWidgets('on its last refundable day still offers the refund', (tester) async {
      final purchase = _purchase(boughtDaysAgo: 13);
      await _pumpWallet(tester, _FakeWalletRepository(transactions: [purchase]));

      await tester.tap(find.text(purchase.description));
      await tester.pumpAndSettle();

      expect(find.text(WalletCopy.requestRefund), findsOneWidget);
    });

    testWidgets('with no card payment behind it offers no refund', (tester) async {
      final purchase = _purchase(boughtDaysAgo: 1, paymentIntent: null);
      await _pumpWallet(tester, _FakeWalletRepository(transactions: [purchase]));

      await tester.tap(find.text(purchase.description));
      await tester.pumpAndSettle();

      expect(find.text(WalletCopy.refundUnavailable), findsOneWidget);
      expect(find.text(WalletCopy.requestRefund), findsNothing);
    });
  });

  group('asking for a refund', () {
    testWidgets('asks to confirm first, and "Go back" sends nothing', (tester) async {
      final purchase = _purchase(boughtDaysAgo: 2);
      final repository = _FakeWalletRepository(transactions: [purchase]);
      await _pumpWallet(tester, repository);
      await _openConfirmStep(tester, purchase);

      expect(find.text(WalletCopy.refundConfirmTitle), findsOneWidget);
      expect(
        find.text(WalletCopy.refundConfirmBody('3 tokens', '£20.00')),
        findsOneWidget,
      );

      await tester.tap(find.text(WalletCopy.goBack));
      await tester.pumpAndSettle();

      expect(repository.refundRequests, isEmpty);
      expect(find.text(WalletCopy.requestRefund), findsOneWidget);
    });

    testWidgets('a refund that goes through says so and refreshes balance and history',
        (tester) async {
      final purchase = _purchase(boughtDaysAgo: 2);
      final repository = _FakeWalletRepository(balance: 3, transactions: [purchase]);
      repository.onRefund = (_) {
        // What the backend does: the tokens leave and a refund row is added.
        repository.balance = 0;
        repository.transactions = [_purchaseRefund(of: purchase), purchase];
        return RefundResponse(transactionId: 99, clientSecret: 're_123', status: 'succeeded');
      };
      await _pumpWallet(tester, repository);
      expect(find.text('3 tokens'), findsOneWidget);

      await _openConfirmStep(tester, purchase);
      await tester.tap(find.text(WalletCopy.confirmRefund));
      await tester.pumpAndSettle();

      final request = repository.refundRequests.single;
      expect(request.transactionId, purchase.transactionId);
      expect(request.stripePaymentIntent, purchase.stripePaymentIntentId);
      expect(request.idempotencyKey, isNotEmpty);

      expect(find.text(WalletCopy.refundDoneTitle), findsOneWidget);
      expect(find.text(WalletCopy.refundDoneBody('3 tokens', '£20.00')), findsOneWidget);
      expect(repository.balanceFetches, 2);
      expect(repository.historyFetches, 2);

      await tester.tap(find.text(WalletCopy.done));
      await tester.pumpAndSettle();

      expect(find.byType(PurchaseDetailSheet), findsNothing);
      expect(find.text('0 tokens'), findsOneWidget);
      expect(find.text('Refund of 3.00'), findsOneWidget);

      // Opened again, the purchase no longer offers what was just done.
      await tester.tap(find.text(purchase.description));
      await tester.pumpAndSettle();
      expect(find.text(WalletCopy.alreadyRefunded), findsOneWidget);
      expect(find.text(WalletCopy.requestRefund), findsNothing);
    });

    testWidgets('a refusal shows a plain reason and changes nothing', (tester) async {
      final purchase = _purchase(boughtDaysAgo: 2);
      final repository = _FakeWalletRepository(balance: 3, transactions: [purchase]);
      const backendMessage = 'Transaction has already been refunded or not refundable.';
      repository.onRefund = (_) => throw const ConflictException(backendMessage);
      await _pumpWallet(tester, repository);

      await _openConfirmStep(tester, purchase);
      await tester.tap(find.text(WalletCopy.confirmRefund));
      await tester.pumpAndSettle();

      expect(repository.refundRequests, hasLength(1));
      expect(find.text(WalletCopy.refundNotAllowed), findsOneWidget);
      expect(find.text(backendMessage), findsNothing);
      expect(find.text(WalletCopy.refundDoneTitle), findsNothing);
      // Asking again from here would only be refused again.
      expect(find.text(WalletCopy.requestRefund), findsNothing);
      expect(find.text(WalletCopy.confirmRefund), findsNothing);

      // Nothing was refreshed, and the wallet behind the sheet is as it was.
      expect(repository.balanceFetches, 1);
      expect(repository.historyFetches, 1);
      expect(find.text('3 tokens'), findsWidgets);
      expect(find.text('Refund of 3.00'), findsNothing);
    });

    testWidgets('a lost connection can be tried again', (tester) async {
      final purchase = _purchase(boughtDaysAgo: 2);
      final repository = _FakeWalletRepository(transactions: [purchase]);
      repository.onRefund = (_) => throw const NetworkException('timeout');
      await _pumpWallet(tester, repository);

      await _openConfirmStep(tester, purchase);
      await tester.tap(find.text(WalletCopy.confirmRefund));
      await tester.pumpAndSettle();

      expect(find.text(WalletCopy.refundNoConnection), findsOneWidget);
      expect(find.text(WalletCopy.requestRefund), findsOneWidget);
    });

    testWidgets('a double tap on the confirm button sends one request', (tester) async {
      final purchase = _purchase(boughtDaysAgo: 2);
      final repository = _FakeWalletRepository(transactions: [purchase]);
      final answer = Completer<RefundResponse>();
      repository.onRefund = (_) => answer.future;
      await _pumpWallet(tester, repository);
      await _openConfirmStep(tester, purchase);

      // Two taps with no frame between them: the button hasn't been rebuilt as loading yet.
      await tester.tap(find.text(WalletCopy.confirmRefund));
      await tester.tap(find.text(WalletCopy.confirmRefund));
      await tester.pump();

      // And once it is loading, it takes no taps and neither does the way back.
      final sheet = find.byType(PurchaseDetailSheet);
      final confirm = tester.widget<ElevatedButton>(
        find.descendant(of: sheet, matching: find.byType(ElevatedButton)),
      );
      expect(confirm.onPressed, isNull);
      expect(
        find.descendant(of: sheet, matching: find.byType(CircularProgressIndicator)),
        findsOneWidget,
      );
      await tester.tap(find.text(WalletCopy.goBack));
      await tester.pump();
      expect(find.text(WalletCopy.refundConfirmTitle), findsOneWidget);

      expect(repository.refundRequests, hasLength(1));

      answer.complete(
        RefundResponse(transactionId: 99, clientSecret: 're_123', status: 'succeeded'),
      );
      await tester.pumpAndSettle();

      expect(repository.refundRequests, hasLength(1));
      expect(find.text(WalletCopy.refundDoneTitle), findsOneWidget);
    });

    testWidgets('a sheet swiped away mid-request still gets told the result', (tester) async {
      final purchase = _purchase(boughtDaysAgo: 2);
      final repository = _FakeWalletRepository(balance: 3, transactions: [purchase]);
      final answer = Completer<RefundResponse>();
      repository.onRefund = (_) {
        repository.balance = 0;
        return answer.future;
      };
      await _pumpWallet(tester, repository);
      await _openConfirmStep(tester, purchase);

      await tester.tap(find.text(WalletCopy.confirmRefund));
      await tester.pump();
      Navigator.of(tester.element(find.byType(PurchaseDetailSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(PurchaseDetailSheet), findsNothing);

      answer.complete(
        RefundResponse(transactionId: 99, clientSecret: 're_123', status: 'succeeded'),
      );
      await tester.pumpAndSettle();

      expect(find.text(WalletCopy.refundDoneTitle), findsOneWidget);
      expect(find.text('0 tokens'), findsOneWidget);
    });
  });

  group('rows that open nothing', () {
    testWidgets('only purchases take a tap', (tester) async {
      final purchase = _purchase(boughtDaysAgo: 2);
      final spend = _transaction(
        id: 2,
        type: TransactionType.spend,
        amount: -1,
        description: 'Deposit for date 12',
        relatedDateId: 12,
      );
      final depositRefund = _transaction(
        id: 3,
        type: TransactionType.refund,
        amount: 1,
        description: 'Deposit refund for date 12',
        relatedDateId: 12,
      );
      final adjustment = _transaction(
        id: 4,
        type: TransactionType.adjustment,
        amount: 2,
        description: 'Goodwill tokens',
      );
      await _pumpWallet(
        tester,
        _FakeWalletRepository(transactions: [adjustment, depositRefund, spend, purchase]),
      );

      // One ripple and one chevron, both on the purchase.
      final history = find.byType(SliverList);
      expect(find.descendant(of: history, matching: find.byType(InkWell)), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      for (final row in [spend, depositRefund, adjustment]) {
        await tester.tap(find.text(row.description), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(PurchaseDetailSheet), findsNothing);
      }
    });

    testWidgets('a purchase refund reads as tokens leaving, a deposit refund as tokens back',
        (tester) async {
      final purchase = _purchase(boughtDaysAgo: 2);
      final depositRefund = _transaction(
        id: 3,
        type: TransactionType.refund,
        amount: 1,
        description: 'Deposit refund for date 12',
        relatedDateId: 12,
      );
      await _pumpWallet(
        tester,
        _FakeWalletRepository(
          transactions: [_purchaseRefund(of: purchase), depositRefund, purchase],
        ),
      );

      // The purchase and the deposit refund add tokens; the purchase refund takes its 3 out.
      expect(find.text('+3'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}

Future<void> _pumpWallet(WidgetTester tester, _FakeWalletRepository repository) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [walletRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const WalletScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openConfirmStep(WidgetTester tester, Transaction purchase) async {
  await tester.tap(find.text(purchase.description));
  await tester.pumpAndSettle();
  await tester.tap(find.text(WalletCopy.requestRefund));
  await tester.pumpAndSettle();
}

/// A completed Popular package: 3 tokens for £20.00.
Transaction _purchase({required int boughtDaysAgo, String? paymentIntent = 'pi_123'}) {
  return _transaction(
    id: 1,
    type: TransactionType.purchase,
    amount: 3,
    description: 'Purchased 3.00 tokens',
    // An hour short of the whole days, so a test never sits on the boundary.
    createdAt: DateTime.now().toUtc().subtract(Duration(days: boughtDaysAgo, hours: -1)),
    paymentIntent: paymentIntent,
    amountPaid: 2000,
  );
}

/// The row the backend adds when a purchase is refunded: type REFUND, a positive amount, no date.
Transaction _purchaseRefund({required Transaction of}) {
  return _transaction(
    id: 99,
    type: TransactionType.refund,
    amount: of.amount,
    description: 'Refund of 3.00',
    paymentIntent: 're_123',
  );
}

Transaction _transaction({
  required int id,
  required TransactionType type,
  required double amount,
  required String description,
  DateTime? createdAt,
  int? relatedDateId,
  String? paymentIntent,
  int? amountPaid,
}) {
  final at = createdAt ?? DateTime.now().toUtc();
  return Transaction(
    transactionId: id,
    type: type,
    amount: amount,
    balanceAfter: 0,
    description: description,
    relatedDateId: relatedDateId,
    stripePaymentIntentId: paymentIntent,
    amountPaid: amountPaid,
    paymentCurrency: amountPaid == null ? null : 'GBP',
    createdAt: at,
    updatedAt: at,
    status: TransactionStatus.completed,
  );
}

typedef _RefundRequest = ({int transactionId, String stripePaymentIntent, String idempotencyKey});

/// A wallet backend in memory. Anything the wallet screen doesn't call throws.
class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository({this.balance = 3, required this.transactions});

  double balance;
  List<Transaction> transactions;

  /// What `POST /wallet/refund` does. Throw an [ApiException] for a refusal.
  FutureOr<RefundResponse> Function(_RefundRequest request)? onRefund;

  int balanceFetches = 0;
  int historyFetches = 0;
  final List<_RefundRequest> refundRequests = [];

  @override
  Future<WalletBalance> getBalance() async {
    balanceFetches++;
    return WalletBalance(
      balance: balance,
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
    return TransactionHistory(
      transactions: offset == 0 ? transactions : const [],
      total: transactions.length,
      hasMore: false,
    );
  }

  @override
  Future<RefundResponse> refundTokens({
    required int transactionId,
    required String stripePaymentIntent,
    required String idempotencyKey,
  }) async {
    final request = (
      transactionId: transactionId,
      stripePaymentIntent: stripePaymentIntent,
      idempotencyKey: idempotencyKey,
    );
    refundRequests.add(request);
    return await onRefund!(request);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Fake method ${invocation.memberName} not implemented: the wallet screen should not call it',
      );
}
