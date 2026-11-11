import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';

/// What the verification calls can refuse with (RFC-008 §6 "User").
///
/// Anything else (a 409 for an attempt already in review, a network failure) reaches the
/// caller as the usual [ApiException].
sealed class VerificationFailure implements Exception {
  /// The response this was read from.
  final ApiException cause;

  const VerificationFailure(this.cause);

  @override
  String toString() => '$runtimeType (status: ${cause.statusCode})';
}

/// 422 `SELFIE_UNUSABLE`: the automated check couldn't use the picture. The attempt stays
/// open and isn't counted; the user retakes it and uploads to [upload].
class SelfieUnusableFailure extends VerificationFailure {
  final SelfieProblem problem;

  /// A fresh link for the retake. Null if the server sent none: start a new attempt then.
  final SelfieUpload? upload;

  /// When [upload] stops working, if the server said.
  final DateTime? expiresAt;

  const SelfieUnusableFailure(super.cause, {required this.problem, this.upload, this.expiresAt});
}

/// 409 `PHOTOS_REQUIRED`: fewer than 3 profile photos, so there's nothing to compare with.
class PhotosRequiredFailure extends VerificationFailure {
  const PhotosRequiredFailure(super.cause);
}

/// 409 `ALREADY_VERIFIED`.
class AlreadyVerifiedFailure extends VerificationFailure {
  const AlreadyVerifiedFailure(super.cause);
}

/// 429: out of attempts for now (RFC-008 §5.8). Refetch the status to tell a daily limit
/// from `LOCKED`.
class VerificationLimitFailure extends VerificationFailure {
  /// From `Retry-After`, when the server sent one.
  final Duration? retryAfter;

  const VerificationLimitFailure(super.cause, {this.retryAfter});
}

/// 503: verification isn't switched on in this environment, or is down.
class VerificationUnavailableFailure extends VerificationFailure {
  const VerificationUnavailableFailure(super.cause);
}
