/// Wallet-related data models matching backend DTOs
library;

/// Token package types - matches backend
enum TokenPackageType {
  starter,
  popular,
  premium,
  mega;

  /// Number of tokens in this package
  int get tokens {
    switch (this) {
      case TokenPackageType.starter:
        return 1;
      case TokenPackageType.popular:
        return 3;
      case TokenPackageType.premium:
        return 5;
      case TokenPackageType.mega:
        return 10;
    }
  }

  /// Price in pence
  int get priceInPence {
    switch (this) {
      case TokenPackageType.starter:
        return 700; // £7.00
      case TokenPackageType.popular:
        return 2000; // £20.00
      case TokenPackageType.premium:
        return 3250; // £32.50
      case TokenPackageType.mega:
        return 4500; // £45.00
    }
  }

  /// Price in pounds
  double get priceInPounds => priceInPence / 100;

  /// Price per token
  double get pricePerToken => priceInPounds / tokens;

  /// Display name
  String get displayName {
    switch (this) {
      case TokenPackageType.starter:
        return 'Starter';
      case TokenPackageType.popular:
        return 'Popular';
      case TokenPackageType.premium:
        return 'Premium';
      case TokenPackageType.mega:
        return 'Mega';
    }
  }

  /// Formatted price
  String get formattedPrice => '£${priceInPounds.toStringAsFixed(2)}';

  /// Formatted price per token
  String get formattedPricePerToken => '£${pricePerToken.toStringAsFixed(2)}';

  /// JSON value for API
  String get apiValue => name.toUpperCase();

  /// Parse from API string value
  static TokenPackageType fromApiValue(String value) {
    return TokenPackageType.values.firstWhere(
      (type) => type.apiValue == value.toUpperCase(),
    );
  }
}

/// Transaction type enum - matches backend
enum TransactionType {
  purchase,
  spend,
  refund,
  adjustment;

  String get apiValue => name.toUpperCase();

  static TransactionType fromApiValue(String value) {
    return TransactionType.values.firstWhere(
      (type) => type.apiValue == value.toUpperCase(),
    );
  }
}

/// Transaction status enum - matches backend
enum TransactionStatus {
  pending,
  completed,
  failed,
  cancelled,
  refunded,
  refundFailed;

  String get apiValue {
    switch (this) {
      case TransactionStatus.refundFailed:
        return 'REFUND_FAILED';
      default:
        return name.toUpperCase();
    }
  }

  static TransactionStatus fromApiValue(String value) {
    return TransactionStatus.values.firstWhere(
      (status) => status.apiValue == value.toUpperCase(),
    );
  }
}

/// Wallet balance DTO
class WalletBalance {
  final double balance;
  final double pendingBalance;
  final double lifetimeSpent;
  final double lifetimePurchased;
  final String currency;

  WalletBalance({
    required this.balance,
    required this.pendingBalance,
    required this.lifetimeSpent,
    required this.lifetimePurchased,
    required this.currency,
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      balance: (json['balance'] as num).toDouble(),
      pendingBalance: (json['pendingBalance'] as num).toDouble(),
      lifetimeSpent: (json['lifetimeSpent'] as num).toDouble(),
      lifetimePurchased: (json['lifetimePurchased'] as num).toDouble(),
      currency: json['currency'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'balance': balance,
      'pendingBalance': pendingBalance,
      'lifetimeSpent': lifetimeSpent,
      'lifetimePurchased': lifetimePurchased,
      'currency': currency,
    };
  }

  /// Calculate available balance (balance - pending)
  double get availableBalance => balance - pendingBalance;

  /// Format balance for display
  String get formattedBalance => balance.toStringAsFixed(1);

  /// Format available balance for display
  String get formattedAvailableBalance => availableBalance.toStringAsFixed(1);
}

/// Wallet transaction entity
class Transaction {
  final int transactionId;
  final TransactionType type;
  final double amount; // Positive for credit, negative for debit
  final double balanceAfter;
  final String description;
  final int? relatedDateId;
  final String? stripePaymentIntentId;
  final int? amountPaid; // Real money paid in pence
  final String? paymentCurrency;
  final bool? acceptedTerms;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TransactionStatus status;

  Transaction({
    required this.transactionId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    this.relatedDateId,
    this.stripePaymentIntentId,
    this.amountPaid,
    this.paymentCurrency,
    this.acceptedTerms,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      transactionId: json['transactionId'] as int,
      type: TransactionType.fromApiValue(json['type'] as String),
      amount: (json['amount'] as num).toDouble(),
      balanceAfter: (json['balanceAfter'] as num).toDouble(),
      description: json['description'] as String,
      relatedDateId: json['relatedDateId'] as int?,
      stripePaymentIntentId: json['stripePaymentIntentId'] as String?,
      amountPaid: json['amountPaid'] as int?,
      paymentCurrency: json['paymentCurrency'] as String?,
      acceptedTerms: json['acceptedTerms'] as bool?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      status: TransactionStatus.fromApiValue(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'type': type.apiValue,
      'amount': amount,
      'balanceAfter': balanceAfter,
      'description': description,
      if (relatedDateId != null) 'relatedDateId': relatedDateId,
      if (stripePaymentIntentId != null)
        'stripePaymentIntentId': stripePaymentIntentId,
      if (amountPaid != null) 'amountPaid': amountPaid,
      if (paymentCurrency != null) 'paymentCurrency': paymentCurrency,
      if (acceptedTerms != null) 'acceptedTerms': acceptedTerms,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status.apiValue,
    };
  }

  /// Whether this is a credit (positive) transaction
  bool get isCredit => amount > 0;

  /// Get formatted amount with sign
  String get formattedAmount {
    final sign = amount > 0 ? '+' : '';
    return '$sign${amount.abs().toStringAsFixed(0)}';
  }

  /// Get formatted money amount if applicable
  String? get formattedMoneyAmount {
    if (amountPaid == null) return null;
    return '£${(amountPaid! / 100).toStringAsFixed(2)}';
  }

  /// Get display text for the transaction
  String get displayText => description;

  /// Whether this transaction can be refunded
  bool get canRefund {
    return type == TransactionType.purchase &&
        status != TransactionStatus.refunded &&
        stripePaymentIntentId != null;
  }
}

/// Transaction history response with pagination
class TransactionHistory {
  final List<Transaction> transactions;
  final int total;
  final bool hasMore;

  TransactionHistory({
    required this.transactions,
    required this.total,
    required this.hasMore,
  });

  factory TransactionHistory.fromJson(Map<String, dynamic> json) {
    return TransactionHistory(
      transactions: (json['transactions'] as List)
          .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      hasMore: json['hasMore'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'total': total,
      'hasMore': hasMore,
    };
  }
}

/// Purchase response from backend
class PurchaseResponse {
  final String clientSecret;
  final String paymentIntentId;
  final double amount; // In pence
  final String currency;
  final double tokenAmount;
  final String status;
  final double? newBalance;
  final int? transactionId;
  final bool? acceptedTerms;

  PurchaseResponse({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.amount,
    required this.currency,
    required this.tokenAmount,
    required this.status,
    this.newBalance,
    this.transactionId,
    this.acceptedTerms,
  });

  factory PurchaseResponse.fromJson(Map<String, dynamic> json) {
    return PurchaseResponse(
      clientSecret: json['clientSecret'] as String,
      paymentIntentId: json['paymentIntentId'] as String,
      // Backend sends BigDecimal as string, convert to double
      amount: _parseNumericValue(json['amount']),
      currency: json['currency'] as String,
      // Backend sends BigDecimal as string, convert to double
      tokenAmount: _parseNumericValue(json['tokenAmount']),
      status: json['status'] as String,
      newBalance: json['newBalance'] != null
          ? _parseNumericValue(json['newBalance'])
          : null,
      transactionId: json['transactionId'] as int?,
      acceptedTerms: json['acceptedTerms'] as bool?,
    );
  }

  /// Helper method to parse numeric values that may come as num or String
  static double _parseNumericValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    } else if (value is String) {
      return double.parse(value);
    } else {
      throw FormatException('Cannot parse numeric value from $value');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'clientSecret': clientSecret,
      'paymentIntentId': paymentIntentId,
      'amount': amount,
      'currency': currency,
      'tokenAmount': tokenAmount,
      'status': status,
      if (newBalance != null) 'newBalance': newBalance,
      if (transactionId != null) 'transactionId': transactionId,
      if (acceptedTerms != null) 'acceptedTerms': acceptedTerms,
    };
  }
}

/// Refund response from backend
class RefundResponse {
  final int transactionId;
  final String clientSecret;
  final String status;

  RefundResponse({
    required this.transactionId,
    required this.clientSecret,
    required this.status,
  });

  factory RefundResponse.fromJson(Map<String, dynamic> json) {
    return RefundResponse(
      transactionId: json['transactionId'] as int,
      clientSecret: json['clientSecret'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'clientSecret': clientSecret,
      'status': status,
    };
  }
}
