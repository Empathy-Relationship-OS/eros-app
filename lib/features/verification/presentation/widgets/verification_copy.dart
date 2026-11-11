import 'package:eros_app/features/verification/domain/models/verification_models.dart';

/// Copy for selfie verification (RFC-008 §7), shared by the consent and camera flow, the
/// status screen and the wall on a date.
///
/// Short and practical. No em dashes. Reasons, never scores, and nothing about anyone else's
/// verification (primer rule 21).
class VerificationCopy {
  VerificationCopy._();

  /// The wall on a date.
  static const String wallTitle = 'Verify it\'s you to continue with this date';

  /// Shown while an attempt is with staff.
  static const String inReview = 'We\'re checking your selfie';

  /// Why the last attempt was rejected. A retry with no reason reads as [RetryReason.other].
  static String retryReason(RetryReason? reason) => switch (reason ?? RetryReason.other) {
        RetryReason.poseMissing => 'We couldn\'t see the pose',
        RetryReason.unclear => 'The picture was too dark or blurry',
        RetryReason.notSamePerson =>
          'Your selfie doesn\'t look like your profile photos. Update your photos or try again',
        RetryReason.profilePhotosUnsuitable => 'Add a clear photo of just you to your profile',
        RetryReason.other => 'We couldn\'t verify that selfie. Please try again',
      };

  /// Why a selfie has to be retaken straight away.
  static String selfieProblem(SelfieProblem problem) => switch (problem) {
        SelfieProblem.noFace => 'We couldn\'t see your face. Try again',
        SelfieProblem.severalFaces => 'Make sure you\'re the only person in the picture',
        SelfieProblem.faceTooSmall => 'Move closer so your face fills the oval',
        SelfieProblem.tooDark => 'Try again in better light',
        SelfieProblem.tooBlurry => 'The picture was blurry. Hold still and try again',
        SelfieProblem.eyesNotVisible => 'Make sure we can see your eyes',
        SelfieProblem.sunglasses => 'Take off your sunglasses and try again',
        SelfieProblem.other => 'We couldn\'t use that picture. Try again',
      };

  // Consent (VF-F2). PLACEHOLDER until the lawyer answers RFC-008 Q-8: the wording may change,
  // and the server's `consentVersion` with it. Keep every consent line here.

  static const String consentTitle = 'Verify it\'s you';
  static const String consentIntro =
      'Before your first date, take a selfie copying a pose we show you. It shows you\'re the '
      'person in your photos.';
  static const List<String> consentPoints = [
    'Software compares your selfie with your profile photos, then someone on our team checks it.',
    'Only our team sees your selfie. It\'s never shown to anyone you match with.',
    'We delete it when it\'s no longer needed.',
  ];
  static const String privacyPolicyLink = 'Read our privacy policy';
  static const String consentAgree = 'I agree';
  static const String consentPersonInstead = 'Have a person check it instead';
  static const String consentPersonInsteadHint =
      'No software comparison. Someone on our team compares your selfie with your photos.';

  static const String photosRequiredTitle = 'Add more photos first';
  static const String photosRequiredBody =
      'You need at least 3 photos on your profile. We compare your selfie with them.';
  static const String photosRequiredAction = 'Add photos';

  // Camera and review (VF-F2).

  static const String poseHeading = 'Copy this pose';
  static const List<String> cameraTips = ['Face the light', 'No sunglasses or hats'];
  static const String shutterLabel = 'Take selfie';
  static const String closeLabel = 'Close';
  static const String cameraPermissionDenied =
      'Muse needs your camera to take your selfie. Turn on camera access in Settings.';
  static const String openSettings = 'Open Settings';
  static const String noFrontCamera =
      'We couldn\'t find a front camera on this phone, so it can\'t take your selfie.';
  static const String cameraFailed = 'We couldn\'t open the camera. Try again.';

  static const String reviewTitle = 'Check your selfie';
  static const String reviewHint = 'Make sure we can see your face and the pose.';
  static const String useThis = 'Use this';
  static const String retake = 'Retake';
  static const String sending = 'Sending your selfie';

  // Results (VF-F2).

  static const String submitted = 'Thanks. We\'re checking your selfie and will let you know.';
  static const String verified = 'You\'re verified';
  static const String somethingWentWrong = 'Something went wrong. Try again.';
  static const String tryAgain = 'Try again';
  static const String done = 'Done';
  static const String locked =
      'You\'ve used all your verification attempts. Contact support and we\'ll help you.';

  /// Out of attempts for now (429). [retryAfter] from the server says when they can try again.
  static String limitReached(Duration? retryAfter) {
    const lead = 'You\'ve used your attempts for now.';
    if (retryAfter == null) return '$lead Try again tomorrow.';
    if (retryAfter.inMinutes < 60) return '$lead Try again in under an hour.';
    final hours = (retryAfter.inMinutes / 60).ceil();
    return hours == 1 ? '$lead Try again in about an hour.' : '$lead Try again in about $hours hours.';
  }
}
