import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/verification/domain/models/verification_failures.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';

/// Selfie verification: read my state, start an attempt, upload, submit (RFC-008 §6 "User").
///
/// Logs ids, states and sizes only. Never an upload link or image bytes (primer rule 19).
/// The coded refusals are thrown as [VerificationFailure]s; everything else stays an
/// [ApiException].
class VerificationRepository {
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  VerificationRepository(this._apiClient);

  /// The selfie is always uploaded as a JPEG (RFC-008 §5.4).
  static const String selfieContentType = 'image/jpeg';

  /// GET /users/me/verification
  Future<VerificationStatus> getStatus() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.verification.status(),
      );
      return VerificationStatus.fromJson(response);
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to get verification status (status ${e.statusCode})');
      throw _mapFailure(e);
    }
  }

  /// POST /users/me/verification/attempts
  ///
  /// [automatedCheck] false is "Have a person check it instead". Throws
  /// [AlreadyVerifiedFailure], [PhotosRequiredFailure], [VerificationLimitFailure] at the
  /// limits, and [ConflictException] while an attempt is in review.
  Future<VerificationAttemptStart> startAttempt({
    required String consentVersion,
    required bool automatedCheck,
  }) async {
    try {
      _logger.d('🤳 Starting a verification attempt');
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.verification.attempts(),
        data: {'consentVersion': consentVersion, 'automatedCheck': automatedCheck},
      );
      final start = VerificationAttemptStart.fromJson(response);
      _logger.d('✅ Verification attempt ${start.attemptId} started');
      return start;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to start a verification attempt (status ${e.statusCode})');
      throw _mapFailure(e);
    }
  }

  /// PUT the selfie to the presigned link in [start], with exactly the headers it came with.
  ///
  /// Goes straight to S3 on a client with no interceptors, so no auth header is sent.
  /// Throws [NetworkException] when S3 refuses it (an expired link, for one).
  Future<void> uploadSelfie(VerificationAttemptStart start, Uint8List bytes) {
    _logger.d('📤 Uploading the selfie for attempt ${start.attemptId} (${bytes.length} bytes)');
    return _apiClient.uploadToS3(
      presignedUrl: start.upload.url,
      fileBytes: bytes,
      contentType: selfieContentType,
      extraHeaders: start.upload.headers,
    );
  }

  /// POST /users/me/verification/attempts/{id}/submit
  ///
  /// Returns the new state, `inReview` or `verified`. Refetch [getStatus] afterwards rather
  /// than keeping it (primer rule 22). Throws [SelfieUnusableFailure] for a retake.
  Future<VerificationState> submit(String attemptId) async {
    try {
      _logger.d('🤳 Submitting verification attempt $attemptId');
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.verification.submit(attemptId),
      );
      final state = VerificationState.fromWire(response['state']);
      _logger.d('✅ Verification attempt $attemptId is ${state.name}');
      return state;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to submit verification attempt $attemptId (status ${e.statusCode})');
      throw _mapFailure(e);
    }
  }

  /// The [VerificationFailure] for a coded refusal, or [e] itself.
  static Object _mapFailure(ApiException e) {
    final body = e.originalError;
    final json = body is Map<String, dynamic> ? body : const <String, dynamic>{};

    switch (json['error']) {
      case 'SELFIE_UNUSABLE':
        final upload = json['upload'];
        return SelfieUnusableFailure(
          e,
          problem: SelfieProblem.fromWire(json['problem']),
          upload: upload is Map<String, dynamic> && upload['url'] is String
              ? SelfieUpload.fromJson(upload)
              : null,
          expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
        );
      case 'PHOTOS_REQUIRED':
        return PhotosRequiredFailure(e);
      case 'ALREADY_VERIFIED':
        return AlreadyVerifiedFailure(e);
    }
    if (e is RateLimitException) return VerificationLimitFailure(e, retryAfter: e.retryAfter);
    if (e.statusCode == 503) return VerificationUnavailableFailure(e);
    return e;
  }
}
