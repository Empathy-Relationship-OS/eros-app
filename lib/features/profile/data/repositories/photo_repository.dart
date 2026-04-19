import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/profile/domain/models/photo_models.dart';

/// Repository for photo upload operations
/// Handles the two-step S3 upload flow:
/// 1. Request presigned URL from backend
/// 2. Upload directly to S3
/// 3. Confirm upload with backend
class PhotoRepository {
  final String baseUrl;
  final AuthService _authService;
  final Logger _logger;

  PhotoRepository({
    this.baseUrl = 'http://localhost:8940',
    required AuthService authService,
    Logger? logger,
  })  : _authService = authService,
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
    final endpoint = '$baseUrl/users/me/photos/presigned-url';
    _logger.i('📤 POST $endpoint');

    try {
      final token = await _authService.getIdToken();
      final requestBody = request.toJson();

      _logger.d('Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      _logger.i('📥 Response status: ${response.statusCode}');
      _logger.d('Response body: ${response.body}');

      if (response.statusCode == 200) {
        _logger.i('✅ Presigned URL obtained successfully');
        return PresignedUploadResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        _logger.w('⚠️  Validation error: ${error['message']}');
        throw PhotoRepositoryException(
          error['message'] ?? 'Invalid photo metadata',
        );
      } else if (response.statusCode == 401) {
        _logger.e('🔒 Authentication failed (401)');
        throw PhotoRepositoryException(
          'Please sign in again to upload photos',
        );
      } else {
        _logger.e('❌ Unexpected status code: ${response.statusCode}');
        throw PhotoRepositoryException(
          'Failed to prepare photo upload. Please try again.',
        );
      }
    } on PhotoRepositoryException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('💥 Network error', error: e, stackTrace: stackTrace);
      throw PhotoRepositoryException(
        'Unable to connect to the server. Please check your internet connection.',
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
    _logger.i('📤 PUT to S3 (presigned URL)');
    _logger.d('File path: ${file.path}');
    _logger.d('Content-Type: $contentType');

    try {
      final fileBytes = await file.readAsBytes();
      _logger.d('File size: ${fileBytes.length} bytes');

      final response = await http.put(
        Uri.parse(presignedUrl),
        headers: {
          'Content-Type': contentType,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      _logger.i('📥 S3 Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        _logger.i('✅ File uploaded to S3 successfully');
      } else {
        _logger.e('❌ S3 upload failed: ${response.statusCode}');
        _logger.e('S3 response: ${response.body}');
        throw PhotoRepositoryException(
          'Failed to upload photo to storage. Please try again.',
        );
      }
    } on PhotoRepositoryException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('💥 S3 upload error', error: e, stackTrace: stackTrace);
      throw PhotoRepositoryException(
        'Failed to upload photo. Please check your internet connection.',
      );
    }
  }

  /// Step 3: Confirm upload with backend
  /// POST /users/me/photos
  /// Backend will verify the file exists in S3 before saving metadata
  Future<UserMediaItemDTO> confirmUpload(
    ConfirmUploadRequest request,
  ) async {
    final endpoint = '$baseUrl/users/me/photos';
    _logger.i('📤 POST $endpoint');

    try {
      final token = await _authService.getIdToken();
      final requestBody = request.toJson();

      _logger.d('Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      _logger.i('📥 Response status: ${response.statusCode}');
      _logger.d('Response body: ${response.body}');

      if (response.statusCode == 201) {
        _logger.i('✅ Upload confirmed successfully');
        return UserMediaItemDTO.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        _logger.w('⚠️  Validation error: ${error['message']}');
        throw PhotoRepositoryException(
          error['message'] ?? 'Photo validation failed',
        );
      } else if (response.statusCode == 404) {
        _logger.w('⚠️  Photo not found in S3 (404)');
        throw PhotoRepositoryException(
          'Photo upload verification failed. Please try uploading again.',
        );
      } else if (response.statusCode == 401) {
        _logger.e('🔒 Authentication failed (401)');
        throw PhotoRepositoryException(
          'Please sign in again to complete photo upload',
        );
      } else {
        _logger.e('❌ Unexpected status code: ${response.statusCode}');
        throw PhotoRepositoryException(
          'Failed to save photo. Please try again.',
        );
      }
    } on PhotoRepositoryException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('💥 Network error', error: e, stackTrace: stackTrace);
      throw PhotoRepositoryException(
        'Unable to connect to the server. Please check your internet connection.',
      );
    }
  }

  /// Delete a photo
  /// DELETE /users/me/photos/{photoId}
  Future<void> deletePhoto(int photoId) async {
    final endpoint = '$baseUrl/users/me/photos/$photoId';
    _logger.i('📤 DELETE $endpoint');

    try {
      final token = await _authService.getIdToken();

      final response = await http.delete(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      _logger.i('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        _logger.i('✅ Photo deleted successfully');
      } else if (response.statusCode == 404) {
        _logger.w('⚠️  Photo not found (404)');
        throw PhotoRepositoryException('Photo not found');
      } else if (response.statusCode == 401) {
        _logger.e('🔒 Authentication failed (401)');
        throw PhotoRepositoryException('Please sign in again to delete photos');
      } else {
        _logger.e('❌ Unexpected status code: ${response.statusCode}');
        throw PhotoRepositoryException('Failed to delete photo. Please try again.');
      }
    } on PhotoRepositoryException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('💥 Network error', error: e, stackTrace: stackTrace);
      throw PhotoRepositoryException(
        'Unable to connect to the server. Please check your internet connection.',
      );
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
}

/// Exception for photo repository errors
class PhotoRepositoryException implements Exception {
  final String message;

  PhotoRepositoryException(this.message);

  @override
  String toString() => 'PhotoRepositoryException: $message';
}
