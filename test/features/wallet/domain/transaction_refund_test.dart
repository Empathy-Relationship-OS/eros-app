import 'package:flutter_test/flutter_test.dart';
import 'package:eros_app/features/wallet/domain/models/wallet_models.dart';

void main() {
  final now = DateTime.utc(2026, 11, 16, 12);

  Transaction transaction({
    TransactionType type = TransactionType.purchase,
    double amount = 3,
    DateTime? createdAt,
    int? relatedDateId,
    int? amountPaid = 2000,
    String? currency = 'GBP',
  }) {
    final at = createdAt ?? now;
    return Transaction(
      transactionId: 1,
      type: type,
      amount: amount,
      balanceAfter: 3,
      description: 'A transaction',
      relatedDateId: relatedDateId,
      stripePaymentIntentId: 'pi_123',
      amountPaid: amountPaid,
      paymentCurrency: currency,
      createdAt: at,
      updatedAt: at,
      status: TransactionStatus.completed,
    );
  }

  group('the refund window', () {
    const window = Duration(days: 14);

    test('is open up to and on the 14th day, as the backend counts it', () {
      final justInside = now.subtract(const Duration(days: 14));
      expect(transaction(createdAt: justInside).isWithin(window, now), isTrue);
      expect(transaction(createdAt: now).isWithin(window, now), isTrue);
    });

    test('is closed a moment past 14 days', () {
      final justOutside = now.subtract(const Duration(days: 14, seconds: 1));
      expect(transaction(createdAt: justOutside).isWithin(window, now), isFalse);
    });
  });

  group('what a row says about tokens', () {
    test('a purchase refund takes tokens out, though the backend stores it as a positive', () {
      final refund = transaction(type: TransactionType.refund, amountPaid: null);
      expect(refund.isPurchaseRefund, isTrue);
      expect(refund.isCredit, isFalse);
      expect(refund.formattedAmount, '3');
    });

    test('a deposit refund puts tokens back', () {
      final refund = transaction(type: TransactionType.refund, amount: 1, relatedDateId: 12);
      expect(refund.isPurchaseRefund, isFalse);
      expect(refund.isCredit, isTrue);
      expect(refund.formattedAmount, '+1');
    });

    test('tokens are counted in words', () {
      expect(transaction(amount: 1).formattedTokens, '1 token');
      expect(transaction(amount: 10).formattedTokens, '10 tokens');
    });
  });

  group('what a purchase was', () {
    test('its package comes from its token count', () {
      expect(transaction(amount: 1).package, TokenPackageType.starter);
      expect(transaction(amount: 10).package, TokenPackageType.mega);
      expect(transaction(amount: 4).package, isNull);
      expect(transaction(type: TransactionType.adjustment).package, isNull);
    });

    test('its price is shown in the currency it was paid in', () {
      expect(transaction().formattedMoneyAmount, '£20.00');
      expect(transaction(amountPaid: 2700, currency: 'USD').formattedMoneyAmount, r'$27.00');
      expect(transaction(amountPaid: 2700, currency: 'CAD').formattedMoneyAmount, '27.00 CAD');
      expect(transaction(amountPaid: null).formattedMoneyAmount, isNull);
    });
  });

  group('a refund response', () {
    RefundOutcome outcome(String status, String providerId) =>
        RefundResponse(transactionId: 9, clientSecret: providerId, status: status).outcome;

    test('is accepted when the provider has taken it', () {
      expect(outcome('succeeded', 're_1'), RefundOutcome.accepted);
      expect(outcome('pending', 're_1'), RefundOutcome.accepted);
      expect(outcome('COMPLETED', 're_1'), RefundOutcome.accepted);
    });

    test('is refused when it replays a stored refusal', () {
      expect(outcome('REFUND_FAILED', 'error'), RefundOutcome.refused);
    });

    test('is unconfirmed without a provider id, or when the provider failed it', () {
      expect(outcome('PENDING', ''), RefundOutcome.unconfirmed);
      expect(outcome('failed', 're_1'), RefundOutcome.unconfirmed);
      expect(outcome('canceled', 're_1'), RefundOutcome.unconfirmed);
    });
  });
}
