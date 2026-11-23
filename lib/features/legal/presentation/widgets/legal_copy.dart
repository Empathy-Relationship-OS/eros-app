/// Short app copy for safety notices (RFC-009 §5.7, CF-F5). The legal wording is the
/// `FRAUD_NOTICE` document the server links to; this is the app's summary of it (primer rule 18).
/// No em dashes.
abstract final class SafetyNoticeCopy {
  static const String title = 'A safety notice';

  /// Says what happened without naming anyone: the API doesn't say who, and the app mustn't guess.
  static const String fraudContactBanned =
      "We've removed someone you spoke to on Muse because they broke our rules on fraud. If they "
      "asked you for money or personal details, don't send them, and contact your bank if you "
      'already have.';

  static const String readMore = 'Read more';
  static const String ok = 'OK';
}
