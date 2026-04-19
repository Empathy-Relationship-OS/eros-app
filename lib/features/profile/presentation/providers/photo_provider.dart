import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/profile/data/repositories/photo_repository.dart';
import 'package:eros_app/features/profile/domain/models/photo_models.dart';
import 'package:eros_app/core/constants/media_constants.dart';
import 'package:path/path.dart' as path;

/// Provider for PhotoRepository
final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return PhotoRepository(authService: authService);
});

/// Provider for ImagePicker
final imagePickerProvider = Provider<ImagePicker>((ref) {
  return ImagePicker();
});

/// State class for photo upload management
class PhotoUploadState {
  final List<PhotoUploadDraft> photos;
  final bool isUploading;
  final String? error;
  final double? uploadProgress; // 0.0 to 1.0

  PhotoUploadState({
    this.photos = const [],
    this.isUploading = false,
    this.error,
    this.uploadProgress,
  });

  PhotoUploadState copyWith({
    List<PhotoUploadDraft>? photos,
    bool? isUploading,
    String? error,
    double? uploadProgress,
    bool clearError = false,
  }) {
    return PhotoUploadState(
      photos: photos ?? this.photos,
      isUploading: isUploading ?? this.isUploading,
      error: clearError ? null : (error ?? this.error),
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }

  /// Get the primary photo (first in list)
  PhotoUploadDraft? get primaryPhoto =>
      photos.isEmpty ? null : photos.first;

  /// Check if minimum photos requirement is met
  bool get hasMinimumPhotos => photos.length >= MediaConstants.minPhotos;

  /// Check if maximum photos limit is reached
  bool get hasMaximumPhotos => photos.length >= MediaConstants.maxPhotos;

  /// Check if ready to proceed
  bool get canProceed => hasMinimumPhotos && !isUploading;
}

/// StateNotifier for managing photo uploads during profile creation
class PhotoUploadNotifier extends StateNotifier<PhotoUploadState> {
  final PhotoRepository _photoRepository;
  final ImagePicker _imagePicker;
  final Logger _logger;

  PhotoUploadNotifier({
    required PhotoRepository photoRepository,
    required ImagePicker imagePicker,
    Logger? logger,
  })  : _photoRepository = photoRepository,
        _imagePicker = imagePicker,
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
            ),
        super(PhotoUploadState());

  /// Pick an image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      _logger.i('📸 Opening image picker...');
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Compress to reduce file size
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (pickedFile == null) {
        _logger.i('User cancelled image selection');
        return null;
      }

      final file = File(pickedFile.path);
      final fileSize = await file.length();

      _logger.i('Image selected: ${pickedFile.name}');
      _logger.i('File size: ${MediaConstants.formatBytes(fileSize)}');

      // Validate file size
      if (!MediaConstants.isFileSizeValid(fileSize)) {
        state = state.copyWith(
          error: 'Photo must be between ${MediaConstants.formatBytes(MediaConstants.minFileSizeBytes)} and ${MediaConstants.formatBytes(MediaConstants.maxFileSizeBytes)}',
        );
        return null;
      }

      return file;
    } catch (e, stackTrace) {
      _logger.e('Error picking image', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        error: 'Failed to select image. Please try again.',
      );
      return null;
    }
  }

  /// Add a photo to the list (without uploading yet)
  /// Used during profile creation to queue photos for later upload
  void addPhoto({
    required String localPath,
    String? caption,
  }) {
    if (state.hasMaximumPhotos) {
      state = state.copyWith(
        error: 'Maximum ${MediaConstants.maxPhotos} photos allowed',
      );
      return;
    }

    final displayOrder = state.photos.length + 1;
    final isPrimary = displayOrder == 1;

    final photo = PhotoUploadDraft(
      localPath: localPath,
      displayOrder: displayOrder,
      isPrimary: isPrimary,
      caption: caption,
    );

    state = state.copyWith(
      photos: [...state.photos, photo],
      clearError: true,
    );

    _logger.i('✅ Photo added (${state.photos.length}/${MediaConstants.maxPhotos})');
  }

  /// Remove a photo from the list
  void removePhoto(int index) {
    if (index < 0 || index >= state.photos.length) {
      _logger.w('Invalid photo index: $index');
      return;
    }

    final updatedPhotos = List<PhotoUploadDraft>.from(state.photos);
    updatedPhotos.removeAt(index);

    // Re-index remaining photos
    final reindexedPhotos = <PhotoUploadDraft>[];
    for (var i = 0; i < updatedPhotos.length; i++) {
      reindexedPhotos.add(
        updatedPhotos[i].copyWith(
          displayOrder: i + 1,
          isPrimary: i == 0,
        ),
      );
    }

    state = state.copyWith(
      photos: reindexedPhotos,
      clearError: true,
    );

    _logger.i('Photo removed. Remaining: ${state.photos.length}');
  }

  /// Update photo caption
  void updatePhotoCaption(int index, String? caption) {
    if (index < 0 || index >= state.photos.length) {
      _logger.w('Invalid photo index: $index');
      return;
    }

    final updatedPhotos = List<PhotoUploadDraft>.from(state.photos);
    updatedPhotos[index] = updatedPhotos[index].copyWith(caption: caption);

    state = state.copyWith(
      photos: updatedPhotos,
      clearError: true,
    );
  }

  /// Replace a photo at a specific index
  void replacePhoto(int index, String newLocalPath) {
    if (index < 0 || index >= state.photos.length) {
      _logger.w('Invalid photo index: $index');
      return;
    }

    final updatedPhotos = List<PhotoUploadDraft>.from(state.photos);
    final oldPhoto = updatedPhotos[index];

    updatedPhotos[index] = PhotoUploadDraft(
      localPath: newLocalPath,
      displayOrder: oldPhoto.displayOrder,
      isPrimary: oldPhoto.isPrimary,
      caption: oldPhoto.caption,
    );

    state = state.copyWith(
      photos: updatedPhotos,
      clearError: true,
    );

    _logger.i('Photo replaced at index $index');
  }

  /// Upload all photos to backend
  /// This should be called when user completes profile creation
  Future<bool> uploadAllPhotos() async {
    if (state.photos.isEmpty) {
      _logger.w('No photos to upload');
      return false;
    }

    if (!state.hasMinimumPhotos) {
      state = state.copyWith(
        error: 'At least ${MediaConstants.minPhotos} photos required',
      );
      return false;
    }

    state = state.copyWith(
      isUploading: true,
      uploadProgress: 0.0,
      clearError: true,
    );

    try {
      final uploadedPhotos = <PhotoUploadDraft>[];
      final totalPhotos = state.photos.length;

      for (var i = 0; i < state.photos.length; i++) {
        final photo = state.photos[i];
        _logger.i('Uploading photo ${i + 1}/$totalPhotos...');

        // Update progress
        state = state.copyWith(
          uploadProgress: (i / totalPhotos),
        );

        final file = File(photo.localPath);
        if (!await file.exists()) {
          _logger.e('File not found: ${photo.localPath}');
          throw Exception('Photo file not found. Please try selecting again.');
        }

        // Get file metadata
        final fileName = path.basename(file.path);
        final fileSize = await file.length();
        final extension = path.extension(fileName).toLowerCase();

        // Determine content type
        String contentType;
        switch (extension) {
          case '.jpg':
          case '.jpeg':
            contentType = 'image/jpeg';
            break;
          case '.png':
            contentType = 'image/png';
            break;
          case '.heic':
            contentType = 'image/heic';
            break;
          case '.heif':
            contentType = 'image/heif';
            break;
          default:
            contentType = 'image/jpeg';
        }

        // Upload photo
        final mediaItem = await _photoRepository.uploadPhoto(
          file: file,
          fileName: fileName,
          contentType: contentType,
          fileSizeBytes: fileSize,
          displayOrder: photo.displayOrder,
          isPrimary: photo.isPrimary,
        );

        // Update photo with backend IDs
        uploadedPhotos.add(
          photo.copyWith(
            objectKey: mediaItem.mediaUrl, // Store media URL as objectKey for reference
            mediaId: mediaItem.id,
          ),
        );

        _logger.i('✅ Photo ${i + 1}/$totalPhotos uploaded successfully');
      }

      // Update state with uploaded photos
      state = state.copyWith(
        photos: uploadedPhotos,
        isUploading: false,
        uploadProgress: 1.0,
        clearError: true,
      );

      _logger.i('✅ All photos uploaded successfully');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Failed to upload photos', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isUploading: false,
        uploadProgress: null,
        error: e is PhotoRepositoryException
            ? e.message
            : 'Failed to upload photos. Please try again.',
      );
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Reset all photos (useful when starting over)
  void reset() {
    state = PhotoUploadState();
    _logger.i('Photo upload state reset');
  }

  /// Load photos from saved draft
  void loadFromDraft(List<PhotoUploadDraft> photos) {
    state = state.copyWith(photos: photos, clearError: true);
    _logger.i('Loaded ${photos.length} photos from draft');
  }
}

/// Provider for PhotoUploadNotifier
final photoUploadProvider =
    StateNotifierProvider<PhotoUploadNotifier, PhotoUploadState>((ref) {
  final photoRepository = ref.watch(photoRepositoryProvider);
  final imagePicker = ref.watch(imagePickerProvider);

  return PhotoUploadNotifier(
    photoRepository: photoRepository,
    imagePicker: imagePicker,
  );
});
