import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/profile/domain/models/photo_models.dart';

/// Repository for the user's photos (RFC-004 §4.3).
///
/// Uploads are staged, never confirmed one by one: [stageUpload] presigns and PUTs a photo to S3,
/// and [commitPhotoSet] saves the whole ordered set at once. Onboarding and the photo editor both
/// work this way.
class PhotoRepository {
  final ApiClient _apiClient;
  final Logger _logger;

  PhotoRepository({
    required ApiClient apiClient,
    required AuthService authService,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ??
            Logger(
              printer: PrettyPrinter(
                methodCount: 0,
                errorMethodCount: 5,
                lineLength: 80,
                colors: true,
                printEmojis: true,
                dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
              ),
            );

  /// Requests a presigned S3 PUT URL.
  /// POST /users/me/photos/presigned-url
  Future<PresignedUploadResponse> getPresignedUrl(
    PresignedUploadRequest request,
  ) async {
    try {
      _logger.i('📸 Requesting presigned URL');

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.photos.getPresignedUrl(),
        data: request.toJson(),
      );

      _logger.i('✅ Presigned URL obtained successfully');
      return PresignedUploadResponse.fromJson(response);
    } on ValidationException catch (e) {
      _logger.w('⚠️  Validation error: ${e.message}');
      throw PhotoRepositoryException(
        e.message,
      );
    } on UnauthorizedException {
      _logger.e('🔒 Authentication failed (401)');
      throw PhotoRepositoryException(
        'Please sign in again to upload photos',
      );
    } on NetworkException catch (e) {
      _logger.e('💥 Network error', error: e);
      throw PhotoRepositoryException(
        'Unable to connect to the server. Please check your internet connection.',
      );
    } on ApiException catch (e) {
      _logger.e('❌ Unexpected error', error: e);
      throw PhotoRepositoryException(
        'Failed to prepare photo upload. Please try again.',
      );
    }
  }

  /// Delete a photo
  /// DELETE /users/me/photos/{photoId}
  Future<void> deletePhoto(int photoId) async {
    try {
      _logger.i('🗑️  Deleting photo: $photoId');

      await _apiClient.delete<void>(
        ApiEndpoints.photos.delete(photoId.toString()),
      );

      _logger.i('✅ Photo deleted successfully');
    } on NotFoundException {
      _logger.w('⚠️  Photo not found (404)');
      throw PhotoRepositoryException('Photo not found');
    } on UnauthorizedException {
      _logger.e('🔒 Authentication failed (401)');
      throw PhotoRepositoryException('Please sign in again to delete photos');
    } on NetworkException catch (e) {
      _logger.e('💥 Network error', error: e);
      throw PhotoRepositoryException(
        'Unable to connect to the server. Please check your internet connection.',
      );
    } on ApiException catch (e) {
      _logger.e('❌ Unexpected error', error: e);
      throw PhotoRepositoryException('Failed to delete photo. Please try again.');
    }
  }

  // ---------------------------------------------------------------------------
  // Stage uploads, then commit the whole set (RFC-004 §4.3)
  // ---------------------------------------------------------------------------

  /// The user's photos and the set's `revision`. GET /users/me/photos
  Future<MyPhotoCollection> getMyPhotos() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.photos.list());
      return MyPhotoCollection.fromJson(response);
    } on UnauthorizedException {
      throw PhotoRepositoryException('Please sign in again to edit your photos');
    } on NetworkException {
      throw PhotoRepositoryException(
        'Unable to connect to the server. Please check your internet connection.',
      );
    } on ApiException catch (e) {
      _logger.e('❌ Loading photos failed', error: e);
      throw PhotoRepositoryException('We couldn\'t load your photos. Please try again.');
    }
  }

  /// Presigns [file] and uploads it to S3 with the presign's `requiredHeaders`, **without
  /// confirming it**. Returns the object key to send in [commitPhotoSet]. An upload that is never
  /// committed stays tagged `upload_confirmed=false` and expires after a day.
  ///
  /// [displayOrder] is the position the photo will take (1–6); the presign uses it only to check
  /// the photo limit.
  Future<String> stageUpload({
    required File file,
    required String contentType,
    required int sizeBytes,
    required int displayOrder,
    void Function(double progress)? onProgress,
  }) async {
    final presigned = await getPresignedUrl(
      PresignedUploadRequest(
        fileName: file.path.split('/').last,
        contentType: contentType,
        fileSizeBytes: sizeBytes,
        displayOrder: displayOrder,
      ),
    );
    try {
      await _apiClient.uploadToS3(
        presignedUrl: presigned.uploadUrl,
        fileBytes: await file.readAsBytes(),
        contentType: contentType,
        extraHeaders: presigned.requiredHeaders,
        onProgress: onProgress,
      );
    } on ApiException catch (e) {
      _logger.e('💥 Staged S3 upload failed', error: e);
      throw PhotoRepositoryException('Upload failed. Tap to try again.');
    }
    return presigned.objectKey;
  }

  /// Makes the stored set exactly [entries], in order. PUT /users/me/photos
  ///
  /// Throws [PhotoSetConflictException] if the set changed since [revision] (409), and
  /// [PhotoRepositoryException] with the server's message for a refused set (400 or 403).
  Future<MyPhotoCollection> commitPhotoSet(String revision, List<PhotoSetEntry> entries) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        ApiEndpoints.photos.commit(),
        data: {'revision': revision, 'photos': entries.map((e) => e.toJson()).toList()},
      );
      return MyPhotoCollection.fromJson(response);
    } on ConflictException {
      throw PhotoSetConflictException();
    } on ValidationException catch (e) {
      throw PhotoRepositoryException(e.message);
    } on ForbiddenException catch (e) {
      throw PhotoRepositoryException(e.message);
    } on UnauthorizedException {
      throw PhotoRepositoryException('Please sign in again to save your photos');
    } on NetworkException {
      throw PhotoRepositoryException(
        'Unable to connect to the server. Please check your internet connection.',
      );
    } on ApiException catch (e) {
      _logger.e('❌ Photo commit failed', error: e);
      throw PhotoRepositoryException('We couldn\'t save your photos. Please try again.');
    }
  }
}

/// Riverpod provider for PhotoRepository
final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final authService = ref.watch(authServiceProvider);
  return PhotoRepository(
    apiClient: apiClient,
    authService: authService,
  );
});

/// Exception for photo repository errors
class PhotoRepositoryException implements Exception {
  final String message;

  PhotoRepositoryException(this.message);

  @override
  String toString() => 'PhotoRepositoryException: $message';
}

/// The photo set changed since it was read, for example on another device (409, RFC-004 D-4).
class PhotoSetConflictException extends PhotoRepositoryException {
  PhotoSetConflictException()
      : super('Your photos were changed on another device. Please check and try again.');
}
