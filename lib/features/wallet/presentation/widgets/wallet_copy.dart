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

  /// The action on a purchase that may still be refundable.
  static const String requestRefund = 'Request refund';

  /// The step that confirms a refund, which can't be undone.
  static const String refundConfirmTitle = 'Refund this purchase?';
  static const String confirmRefund = 'Refund purchase';
  static const String goBack = 'Go back';

  /// "We'll take 3 tokens out of your wallet and send £20.00 back to the card you paid with."
  static String refundConfirmBody(String tokens, String? money) =>
      'We\'ll take $tokens out of your wallet and send ${money ?? 'your payment'} back to the '
      'card you paid with. This can\'t be undone.';

  /// Shown once the backend has accepted the refund.
  static const String refundDoneTitle = 'Refund on its way';
  static const String done = 'Done';

  /// How long the bank takes is the payment provider's usual figure, not ours to promise.
  static String refundDoneBody(String tokens, String? money) =>
      '$tokens left your wallet and ${money ?? 'your payment'} is going back to the card you '
      'paid with. It usually takes 5 to 10 working days to show on your statement.';

  /// A purchase the app can already tell is too old.
  static const String refundWindowClosed =
      'This purchase is more than $refundDays days old, so it can no longer be refunded.';

  static const String alreadyRefunded = 'This purchase has been refunded.';

  /// A purchase with no card payment behind it.
  static const String refundUnavailable = 'This purchase can\'t be refunded in the app.';

  /// The backend's one refusal for "already refunded", "too old" and "tokens used", which it
  /// doesn't tell apart.
  static const String refundNotAllowed =
      'This purchase can\'t be refunded. Either it has already been refunded, it is more than '
      '$refundDays days old, or one of its tokens has been used.';

  /// The wallet holds fewer tokens than the purchase added.
  static const String refundTokensMissing =
      'Your wallet holds fewer tokens than this purchase added, so it can\'t be refunded.';

  static const String refundAccountBlocked = 'Refunds aren\'t available on this account.';

  static const String refundPurchaseNotFound =
      'We couldn\'t find this purchase. Refresh your wallet and try again.';

  static const String refundNoConnection =
      'We couldn\'t reach Muse. Check your connection and try again.';

  static const String refundTryAgain = 'We couldn\'t request this refund. Please try again.';

  /// The request may have gone through: say so, and don't invite a blind retry.
  static const String refundUnconfirmed =
      'Something went wrong and we can\'t tell whether this refund went through. Check your '
      'wallet history before trying again. If tokens have left your wallet and no money '
      'arrives, contact support.';

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
