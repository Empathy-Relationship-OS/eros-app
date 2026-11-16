import 'package:eros_app/features/wallet/domain/models/wallet_models.dart';

/// Wallet wording that appears on more than one screen, kept here so the screens can't disagree.
class WalletCopy {
  WalletCopy._();

  /// How long after a purchase it can be refunded. The backend applies the same limit.
  static const int refundDays = 14;

  /// The refund rule for bought tokens, as the backend applies it: within [refundDays] days,
  /// and only while no token from that purchase has been used.
  static const String refundRule =
      'A purchase can be refunded within $refundDays days, as long as none of its tokens have '
      'been used.';

  /// What a package's refund means in practice: it is all or nothing.
  static const String packageRefundRule =
      'A package is refunded whole. Once one of its tokens is used, the rest can\'t be refunded.';

  /// The line beside the checkbox on the package screen.
  static const String acceptTerms = 'I accept the terms and conditions. $refundRule';

  /// "You can save up to 36% by buying tokens in a pack.", from the packages' own prices.
  static String get packSaving =>
      'You can save up to ${TokenPackageType.bestSavingPercent}% by buying tokens in a pack.';

  /// "In Muse, you use date tokens to pay for your dates. A single token costs £7.00."
  static String get singleTokenPrice =>
      'In Muse, you use date tokens to pay for your dates. A single token costs '
      '${TokenPackageType.starter.formattedPrice}.';
}
