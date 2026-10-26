import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/features/profile/data/repositories/photo_repository.dart';
import 'package:eros_app/features/profile/domain/models/photo_models.dart';
import 'package:eros_app/core/constants/media_constants.dart';
import 'package:eros_app/core/utils/image_content_type.dart';

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

  /// Content type accepted for each picked file, keyed by its local path. Picking can use the
  /// picker's reported MIME type, which isn't available later, so [addPhoto] and
  /// [replacePhoto] copy it onto the draft for upload to reuse.
  final Map<String, String> _acceptedContentTypes = {};

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

      // Validate file type
      final contentType = await detectFileContentType(
        file,
        reportedMimeType: pickedFile.mimeType,
      );
      if (contentType == null) {
        state = state.copyWith(error: MediaConstants.unsupportedTypeMessage);
        return null;
      }

      // Validate file size
      if (!MediaConstants.isFileSizeValid(fileSize)) {
        state = state.copyWith(error: MediaConstants.invalidSizeMessage);
        return null;
      }

      _acceptedContentTypes[file.path] = contentType;

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
      contentType: _acceptedContentTypes[localPath],
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
      contentType: _acceptedContentTypes[newLocalPath],
    );

    state = state.copyWith(
      photos: updatedPhotos,
      clearError: true,
    );

    _logger.i('Photo replaced at index $index');
  }

  /// Reorder photos by moving a photo from oldIndex to newIndex
  void reorderPhotos(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.photos.length ||
        newIndex < 0 || newIndex >= state.photos.length) {
      _logger.w('Invalid reorder indices: $oldIndex -> $newIndex');
      return;
    }

    if (oldIndex == newIndex) {
      return; // No change needed
    }

    final updatedPhotos = List<PhotoUploadDraft>.from(state.photos);

    // Remove the photo from the old position
    final photo = updatedPhotos.removeAt(oldIndex);

    // Insert it at the new position
    updatedPhotos.insert(newIndex, photo);

    // Re-index all photos to update displayOrder and isPrimary
    final reindexedPhotos = <PhotoUploadDraft>[];
    for (var i = 0; i < updatedPhotos.length; i++) {
      reindexedPhotos.add(
        updatedPhotos[i].copyWith(
          displayOrder: i + 1,
          isPrimary: i == 0, // First photo is always primary
        ),
      );
    }

    state = state.copyWith(
      photos: reindexedPhotos,
      clearError: true,
    );

    _logger.i('Photo reordered: $oldIndex -> $newIndex');
  }

  /// Puts the onboarding photos on the profile: stage every photo, then commit them all at once
  /// (RFC-004 D-8, PE-F7).
  ///
  /// 1. Every photo not yet uploaded is presigned and PUT to S3 ([PhotoRepository.stageUpload]),
  ///    at most [maxParallelUploads] at a time. Each success keeps its object key on its draft,
  ///    so a later call uploads only the photos that failed.
  /// 2. Only when every photo is uploaded, one `PUT /users/me/photos` commits them in order with
  ///    the (empty) set's current revision. Position 1 becomes the main photo.
  ///
  /// So the server never holds part of the set: a failure leaves it with no photos, and the
  /// staged uploads expire on their own. [onProgress] gets how many photos are uploaded so far.
  ///
  /// Returns true when the photos are saved. On failure, sets [PhotoUploadState.error] and returns
  /// false.
  Future<bool> submitPhotos({void Function(int uploaded, int total)? onProgress}) async {
    if (!state.hasMinimumPhotos) {
      state = state.copyWith(error: 'At least ${MediaConstants.minPhotos} photos required');
      return false;
    }

    state = state.copyWith(isUploading: true, uploadProgress: 0.0, clearError: true);
    final total = state.photos.length;
    void report() {
      final uploaded = state.photos.where((p) => p.isUploaded).length;
      state = state.copyWith(uploadProgress: uploaded / total);
      onProgress?.call(uploaded, total);
    }

    try {
      report();
      final failures = await _stageMissing(report);
      if (failures.isNotEmpty) {
        state = state.copyWith(
          isUploading: false,
          error: failures.length == 1
              ? 'One photo didn\'t upload. Please try again.'
              : '${failures.length} photos didn\'t upload. Please try again.',
        );
        return false;
      }

      final keys = state.photos.map((p) => p.objectKey!).toList();
      final current = await _photoRepository.getMyPhotos();
      final saved = _alreadyCommitted(current, keys)
          ? current
          : await _photoRepository.commitPhotoSet(
              current.revision,
              keys.map(PhotoSetEntry.staged).toList(),
            );

      state = state.copyWith(
        photos: [
          for (var i = 0; i < state.photos.length; i++)
            state.photos[i].copyWith(mediaId: saved.photos[i].id),
        ],
        isUploading: false,
        uploadProgress: 1.0,
        clearError: true,
      );
      _logger.i('✅ ${saved.photos.length} onboarding photos committed');
      return true;
    } on PhotoSetConflictException catch (e) {
      state = state.copyWith(isUploading: false, error: e.message);
      return false;
    } on PhotoRepositoryException catch (e) {
      // The server refused the set, for example because a staged upload expired: upload them
      // all again next time.
      state = state.copyWith(
        photos: [for (final p in state.photos) p.withoutUpload()],
        isUploading: false,
        error: e.message,
      );
      return false;
    } catch (e, stackTrace) {
      _logger.e('Failed to submit photos', error: e, stackTrace: stackTrace);
      state = state.copyWith(isUploading: false, error: 'Failed to upload photos. Please try again.');
      return false;
    }
  }

  /// How many photos upload at once.
  static const maxParallelUploads = 3;

  /// Stages every photo without an object key, [maxParallelUploads] at a time. Returns the local
  /// paths that failed; the rest now carry their object keys.
  Future<List<String>> _stageMissing(void Function() onEachDone) async {
    final pending = state.photos.where((p) => !p.isUploaded).map((p) => p.localPath).toList();
    final failures = <String>[];
    var next = 0;

    Future<void> worker() async {
      while (next < pending.length) {
        final path = pending[next++];
        try {
          final key = await _stageOne(path);
          _setObjectKey(path, key);
        } catch (e) {
          _logger.w('Staging $path failed', error: e);
          failures.add(path);
        }
        onEachDone();
      }
    }

    await Future.wait(List.generate(maxParallelUploads, (_) => worker()));
    return failures;
  }

  Future<String> _stageOne(String localPath) async {
    final index = state.photos.indexWhere((p) => p.localPath == localPath);
    final photo = state.photos[index];
    final file = File(photo.localPath);
    if (!await file.exists()) {
      throw PhotoRepositoryException('Photo file not found. Please try selecting again.');
    }
    // Reuse the type accepted at selection; otherwise detect it from the file, never guess.
    final contentType = photo.acceptedContentType ?? await detectFileContentType(file);
    if (contentType == null) throw PhotoRepositoryException(MediaConstants.unsupportedTypeMessage);
    return _photoRepository.stageUpload(
      file: file,
      contentType: contentType,
      sizeBytes: await file.length(),
      displayOrder: index + 1,
    );
  }

  void _setObjectKey(String localPath, String objectKey) {
    state = state.copyWith(photos: [
      for (final p in state.photos) p.localPath == localPath ? p.copyWith(objectKey: objectKey) : p,
    ]);
  }

  /// True when [current] already holds exactly [keys], in order: an earlier commit succeeded but
  /// its response was lost. Committing the same keys again would replace those rows with new
  /// ones pointing at the same objects.
  bool _alreadyCommitted(MyPhotoCollection current, List<String> keys) {
    if (current.photos.length != keys.length) return false;
    for (var i = 0; i < keys.length; i++) {
      if (!Uri.parse(current.photos[i].mediaUrl).path.endsWith('/${keys[i]}')) return false;
    }
    return true;
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Reset all photos (useful when starting over)
  void reset() {
    state = PhotoUploadState();
    _acceptedContentTypes.clear();
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
