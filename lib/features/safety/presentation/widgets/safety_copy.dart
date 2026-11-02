import 'package:eros_app/features/safety/data/models/safety_models.dart';

/// Copy for reports and safety cancels (RFC-006 §6.5, CH-F5).
///
/// Calm and plain. No em dashes. The partner is called by name. Nothing here may hint at who
/// reported whom, or why (D-10).
class SafetyCopy {
  SafetyCopy._();

  // Entry points
  static const String reportAndBlock = 'Report and block';
  static const String report = 'Report';

  // Sheet
  static String sheetIntro(String partnerName, {required bool dateFinished}) => dateFinished
      ? 'You won\'t see $partnerName again. We\'ll review what happened.'
      : 'This ends your date, and you won\'t see $partnerName again. We\'ll review what happened.';
  static const String reasonHeading = 'What happened?';
  static const String descriptionHint = 'Tell us more (optional)';
  static const String imagesHeading = 'Add screenshots or photos (optional)';
  static const String addImage = 'Add image';
  static const String reviewButton = 'Continue';
  static const String reasonsFailed = 'We couldn\'t load the reasons. Please try again.';
  static const String retry = 'Try again';

  // Confirmation
  static const String confirmTitle = 'Send this report?';
  static String confirmBody(String partnerName, {required bool dateFinished}) => dateFinished
      ? 'You can\'t undo this. You won\'t see $partnerName again.'
      : 'You can\'t undo this. Your date ends now, and you won\'t see $partnerName again.';
  static const String confirmButton = 'Send report';
  static const String goBack = 'Go back';

  // Images
  static const String imageUploading = 'Uploading';
  static const String imageFailed =
      'This image didn\'t upload. Remove it, or send the report without it.';
  static const String removeImage = 'Remove image';
  static const String imageWrongType = 'Please choose a JPEG, PNG or HEIC image.';
  static const String imageTooBig = 'Images must be 10 MB or smaller.';
  static const String imagePickFailed = 'We couldn\'t open that image. Please try another.';

  // Errors
  static const String chooseReason = 'Choose what happened.';
  static const String alreadyReported = 'You\'ve already reported this date.';
  static const String alreadyEndedOnCancel =
      'This date has already ended. You can still report it from the date page.';
  static const String imagesNotAttached =
      'We couldn\'t attach your images. Remove them to send the report without them.';
  static const String networkError = 'Connection error. Check your internet and try again.';
  static const String submitFailed = 'We couldn\'t send your report. Please try again.';

  // Cancel dialog
  static const String cancelSomethingCameUp = 'Something came up';
  static const String cancelNotSafe = 'I don\'t feel safe';
  static const String cancelSafetyTitle = 'Cancel this date?';
  static const String cancelSafetyBody = 'We\'ll cancel the date and review what happened.';

  // Result
  static const String resultHeading = 'Thanks for telling us';
  static String resultBody({required bool dateEnded}) => dateEnded
      ? 'Your date is cancelled. We\'ll review what happened.'
      : 'We\'ll review what happened.';
  static String? refundLine(RefundOutcome outcome) => switch (outcome) {
        RefundOutcome.refunded => 'We\'ve refunded your deposit.',
        RefundOutcome.underReview => 'We\'ll review this and let you know about your deposit.',
        RefundOutcome.none => null,
      };
  static const String done = 'Done';

  /// Shown on a date's terminal panel when the viewer's deposit is held or under review. The
  /// same words for both, so it never says who reported whom.
  static const String depositOnHold =
      'We\'re reviewing what happened. Your deposit is on hold until we\'ve finished.';

  /// "If you're in danger, call 999." for UK cities, 911 for US ones.
  ///
  /// `DateDetail` has the city's name but not its country, so the number comes from the
  /// cities the backend knows. Any other city gets wording without a number, which is never
  /// wrong. See the PR: the backend should send the number, or the country, with the date.
  static String emergencyLine(String cityName) {
    final number = _emergencyNumbers[cityName.trim().toLowerCase()];
    return number == null
        ? 'If you\'re in danger, call your local emergency number.'
        : 'If you\'re in danger, call $number.';
  }

  static const Map<String, String> _emergencyNumbers = {
    'london': '999',
    'manchester': '999',
    'houston': '911',
    'new york': '911',
  };
}
