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
}
