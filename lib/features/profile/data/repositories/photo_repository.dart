import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/profile/domain/models/photo_models.dart';

/// Repository for photo upload operations
/// Handles the three-step S3 upload flow:
/// 1. Request presigned URL from backend
/// 2. Upload directly to S3
/// 3. Confirm upload with backend
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

  /// Step 1: Request a presigned S3 URL for upload
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

  /// Step 2: Upload file directly to S3 using presigned URL
  /// This bypasses the backend and uploads directly to AWS S3
  Future<void> uploadToS3({
    required String presignedUrl,
    required File file,
    required String contentType,
  }) async {
    try {
      _logger.i('📤 Uploading to S3');
      _logger.d('File path: ${file.path}');
      _logger.d('Content-Type: $contentType');

      final fileBytes = await file.readAsBytes();
      _logger.d('File size: ${fileBytes.length} bytes');

      // Use ApiClient's uploadToS3 method
      await _apiClient.uploadToS3(
        presignedUrl: presignedUrl,
        fileBytes: fileBytes,
        contentType: contentType,
      );

      _logger.i('✅ File uploaded to S3 successfully');
    } on NetworkException catch (e) {
      _logger.e('💥 S3 upload error', error: e);
      throw PhotoRepositoryException(
        'Failed to upload photo. Please check your internet connection.',
      );
    } on ApiException catch (e) {
      _logger.e('❌ S3 upload failed', error: e);
      throw PhotoRepositoryException(
        'Failed to upload photo to storage. Please try again.',
      );
    }
  }

  /// Step 3: Confirm upload with backend
  /// POST /users/me/photos
  /// Backend will verify the file exists in S3 before saving metadata
  Future<UserMediaItemDTO> confirmUpload(
    ConfirmUploadRequest request,
  ) async {
    try {
      _logger.i('✓ Confirming upload with backend');

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.photos.confirmUpload(),
        data: request.toJson(),
      );

      _logger.i('✅ Upload confirmed successfully');
      return UserMediaItemDTO.fromJson(response);
    } on ValidationException catch (e) {
      _logger.w('⚠️  Validation error: ${e.message}');
      throw PhotoRepositoryException(
        e.message,
      );
    } on NotFoundException {
      _logger.w('⚠️  Photo not found in S3 (404)');
      throw PhotoRepositoryException(
        'Photo upload verification failed. Please try uploading again.',
      );
    } on UnauthorizedException {
      _logger.e('🔒 Authentication failed (401)');
      throw PhotoRepositoryException(
        'Please sign in again to complete photo upload',
      );
    } on NetworkException catch (e) {
      _logger.e('💥 Network error', error: e);
      throw PhotoRepositoryException(
        'Unable to connect to the server. Please check your internet connection.',
      );
    } on ApiException catch (e) {
      _logger.e('❌ Unexpected error', error: e);
      throw PhotoRepositoryException(
        'Failed to save photo. Please try again.',
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

  /// Complete upload flow: get presigned URL → upload to S3 → confirm with backend
  /// Returns the confirmed UserMediaItemDTO
  Future<UserMediaItemDTO> uploadPhoto({
    required File file,
    required String fileName,
    required String contentType,
    required int fileSizeBytes,
    required int displayOrder,
    bool isPrimary = false,
  }) async {
    _logger.i('🚀 Starting complete upload flow for $fileName');

    try {
      // Step 1: Get presigned URL
      _logger.i('Step 1/3: Requesting presigned URL...');
      final presignedResponse = await getPresignedUrl(
        PresignedUploadRequest(
          fileName: fileName,
          contentType: contentType,
          fileSizeBytes: fileSizeBytes,
          displayOrder: displayOrder,
          isPrimary: isPrimary,
        ),
      );

      // Step 2: Upload to S3
      _logger.i('Step 2/3: Uploading to S3...');
      await uploadToS3(
        presignedUrl: presignedResponse.uploadUrl,
        file: file,
        contentType: contentType,
      );

      // Step 3: Confirm with backend
      _logger.i('Step 3/3: Confirming upload with backend...');
      final mediaItem = await confirmUpload(
        ConfirmUploadRequest(
          objectKey: presignedResponse.objectKey,
          displayOrder: displayOrder,
          isPrimary: isPrimary,
        ),
      );

      _logger.i('✅ Complete upload flow finished successfully');
      return mediaItem;
    } catch (e) {
      _logger.e('❌ Upload flow failed', error: e);
      rethrow;
    }
  }

  /// Batch upload multiple photos
  /// Uploads photos sequentially to maintain order and avoid overwhelming the server
  /// Returns list of uploaded media items in the same order as input
  /// Throws BatchPhotoUploadException with partial results if any upload fails
  Future<List<UserMediaItemDTO>> batchUploadPhotos({
    required List<PhotoUploadDraft> photos,
    void Function(int current, int total)? onProgress,
  }) async {
    _logger.i('🚀 Starting batch upload of ${photos.length} photos');

    final results = <UserMediaItemDTO>[];

    try {
      for (var i = 0; i < photos.length; i++) {
        final photo = photos[i];
        _logger.i('📸 Uploading photo ${i + 1}/${photos.length}');

        onProgress?.call(i + 1, photos.length);

        final file = File(photo.localPath);
        final fileBytes = await file.readAsBytes();

        final mediaItem = await uploadPhoto(
          file: file,
          fileName: photo.fileName,
          contentType: photo.contentType,
          fileSizeBytes: fileBytes.length,
          displayOrder: i + 1, // Display order is 1-indexed (1-6)
          isPrimary: i == 0, // First photo is always primary
        );

        results.add(mediaItem);
      }

      _logger.i('✅ Batch upload completed successfully (${results.length}/${photos.length})');
      return results;
    } catch (e, stackTrace) {
      _logger.e(
        '❌ Batch upload failed after uploading ${results.length}/${photos.length} photos',
        error: e,
        stackTrace: stackTrace,
      );

      throw BatchPhotoUploadException(
        message: 'Failed to upload all photos',
        uploadedPhotos: results,
        totalPhotos: photos.length,
        failedAtIndex: results.length,
        originalError: e,
      );
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

/// Exception thrown when batch photo upload fails
class BatchPhotoUploadException implements Exception {
  final String message;
  final List<UserMediaItemDTO> uploadedPhotos;
  final int totalPhotos;
  final int failedAtIndex;
  final Object originalError;

  BatchPhotoUploadException({
    required this.message,
    required this.uploadedPhotos,
    required this.totalPhotos,
    required this.failedAtIndex,
    required this.originalError,
  });

  @override
  String toString() {
    return 'BatchPhotoUploadException: $message '
        '(uploaded ${uploadedPhotos.length}/$totalPhotos, failed at index $failedAtIndex)';
  }

  String getUserMessage() {
    return 'Uploaded ${uploadedPhotos.length} out of $totalPhotos photos. '
        'Please try again to upload the remaining photos.';
  }
}

/// Exception for photo repository errors
class PhotoRepositoryException implements Exception {
  final String message;

  PhotoRepositoryException(this.message);

  @override
  String toString() => 'PhotoRepositoryException: $message';
}
