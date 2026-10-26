import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eros_app/core/constants/media_constants.dart';
import 'package:eros_app/core/utils/image_content_type.dart';
import 'package:eros_app/features/profile/data/repositories/photo_repository.dart';
import 'package:eros_app/features/profile/domain/models/photo_models.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/user_profile_provider.dart';

// ---------------------------------------------------------------------------
// State (RFC-004 §6.3)
// ---------------------------------------------------------------------------

/// One tile of the photo editor: a photo already saved, or a new one being staged.
sealed class EditablePhoto {
  const EditablePhoto();
}

/// A photo on the server, by its id.
class SavedPhoto extends EditablePhoto {
  final int id;

  /// Signed URL; cache the image by [id] (`photo-$id`), never by URL.
  final String url;
  final bool isVerificationPhoto;

  const SavedPhoto({required this.id, required this.url, this.isVerificationPhoto = false});

  factory SavedPhoto.fromDTO(MyPhotoDTO dto) =>
      SavedPhoto(id: dto.id, url: dto.mediaUrl, isVerificationPhoto: dto.isVerificationPhoto);
}

/// A photo picked in this session, uploading to S3 in the background. It reaches the profile
/// only when Save commits it.
class StagedPhoto extends EditablePhoto {
  /// Identifies this tile while it moves around and its upload finishes.
  final String localId;
  final String localPath;
  final String contentType;
  final int sizeBytes;
  final StageStatus status;

  const StagedPhoto({
    required this.localId,
    required this.localPath,
    required this.contentType,
    required this.sizeBytes,
    required this.status,
  });

  StagedPhoto withStatus(StageStatus status) => StagedPhoto(
        localId: localId,
        localPath: localPath,
        contentType: contentType,
        sizeBytes: sizeBytes,
        status: status,
      );
}

/// Where a [StagedPhoto]'s upload is.
sealed class StageStatus {
  const StageStatus();
}

class StageUploading extends StageStatus {
  /// Fraction sent, 0 to 1.
  final double progress;
  const StageUploading(this.progress);
}

class StageReady extends StageStatus {
  final String objectKey;
  const StageReady(this.objectKey);
}

class StageFailed extends StageStatus {
  final String message;
  const StageFailed(this.message);
}

class PhotoEditState {
  /// The photos in their edited order; position 1 is the main photo.
  final List<EditablePhoto> photos;

  /// The loaded set's revision, sent back on Save.
  final String revision;

  /// The photos as loaded, to tell whether anything changed.
  final List<EditablePhoto> original;
  final bool isLoading;
  final bool isSaving;

  /// A load, pick or save problem to show.
  final String? error;

  const PhotoEditState({
    this.photos = const [],
    this.revision = '',
    this.original = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.error,
  });

  PhotoEditState copyWith({
    List<EditablePhoto>? photos,
    String? revision,
    List<EditablePhoto>? original,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) =>
      PhotoEditState(
        photos: photos ?? this.photos,
        revision: revision ?? this.revision,
        original: original ?? this.original,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        error: clearError ? null : (error ?? this.error),
      );

  /// Something differs from what was loaded: a new photo, or saved photos removed or moved.
  bool get isDirty {
    if (photos.any((p) => p is StagedPhoto)) return true;
    return !_sameIds(photos, original);
  }

  /// Every staged photo has finished uploading.
  bool get allStagedReady =>
      photos.whereType<StagedPhoto>().every((p) => p.status is StageReady);

  /// 3–6 photos, all uploaded, something changed, and no save running.
  bool get canSave =>
      !isLoading &&
      !isSaving &&
      photos.length >= MediaConstants.minPhotos &&
      photos.length <= MediaConstants.maxPhotos &&
      allStagedReady &&
      isDirty;

  /// The commit body, in order. Only valid when [allStagedReady].
  List<PhotoSetEntry> get entries => [
        for (final photo in photos)
          switch (photo) {
            SavedPhoto(:final id) => PhotoSetEntry.saved(id),
            StagedPhoto(status: StageReady(:final objectKey)) => PhotoSetEntry.staged(objectKey),
            StagedPhoto() => throw StateError('A staged photo is not ready'),
          },
      ];

  static bool _sameIds(List<EditablePhoto> a, List<EditablePhoto> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i], y = b[i];
      if (x is! SavedPhoto || y is! SavedPhoto || x.id != y.id) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// Picking
// ---------------------------------------------------------------------------

/// A photo picked from the gallery that passed the type and size checks.
class PickedPhoto {
  final String path;
  final String contentType;
  final int sizeBytes;

  const PickedPhoto({required this.path, required this.contentType, required this.sizeBytes});
}

/// A picked photo the upload rules refuse; [message] is for the user.
class PhotoPickException implements Exception {
  final String message;
  const PhotoPickException(this.message);
}

/// Picks one photo the same way onboarding does: at most 2000px, quality 85, then checks its
/// type (from its bytes) and size against [MediaConstants].
class PhotoPicker {
  final ImagePicker _imagePicker;

  PhotoPicker(this._imagePicker);

  /// Returns null if the user cancels; throws [PhotoPickException] for a photo the rules refuse.
  Future<PickedPhoto?> pick() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (picked == null) return null;

    final file = File(picked.path);
    final contentType = await detectFileContentType(file, reportedMimeType: picked.mimeType);
    if (contentType == null) throw const PhotoPickException(MediaConstants.unsupportedTypeMessage);
    final size = await file.length();
    if (!MediaConstants.isFileSizeValid(size)) throw PhotoPickException(MediaConstants.invalidSizeMessage);
    return PickedPhoto(path: picked.path, contentType: contentType, sizeBytes: size);
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => PhotoPicker(ref.watch(imagePickerProvider)));

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// The photo editor (RFC-004 §4.3, §6.3, PE-F4).
///
/// New photos upload to S3 as soon as they are picked, without being confirmed. Remove,
/// replace and reorder only change the local list. [save] sends the whole ordered list in one
/// `PUT /users/me/photos`, so the server never sees a half-edited set, and leaving without
/// saving changes nothing: abandoned uploads expire through the S3 lifecycle rule.
class PhotoEditNotifier extends StateNotifier<PhotoEditState> {
  final Ref _ref;
  var _nextLocalId = 0;

  /// Bumped whenever the list is replaced from the server (a save, or a reload after a
  /// conflict). A pick started before that belongs to a list that no longer exists.
  var _generation = 0;

  PhotoEditNotifier(this._ref) : super(const PhotoEditState()) {
    load();
  }

  PhotoRepository get _repository => _ref.read(photoRepositoryProvider);

  /// Reads the saved photos and their revision, replacing any local edits.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      _apply(await _repository.getMyPhotos());
    } on PhotoRepositoryException catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  // Edits are ignored while a save runs: its result replaces the whole list, so an edit made
  // meanwhile would be lost without a word. A pick that finishes during a save, or after the
  // list was replaced from the server, is dropped too: image_picker resizes the photo after it
  // is chosen, and Save can be tapped meanwhile.

  /// Picks a photo and adds it at the end, uploading it in the background.
  Future<void> add() async {
    if (state.isSaving || state.photos.length >= MediaConstants.maxPhotos) return;
    final generation = _generation;
    final picked = await _pick();
    if (picked == null || !mounted || state.isSaving || generation != _generation) return;
    final staged = _stage(picked);
    state = state.copyWith(photos: [...state.photos, staged], clearError: true);
    _upload(staged);
  }

  /// Picks a photo and puts it in place of the one at [index], uploading it in the background.
  Future<void> replace(int index) async {
    if (state.isSaving || index < 0 || index >= state.photos.length) return;
    final generation = _generation;
    final picked = await _pick();
    if (picked == null || !mounted || state.isSaving || generation != _generation || index >= state.photos.length) {
      return;
    }
    final staged = _stage(picked);
    state = state.copyWith(photos: [...state.photos]..[index] = staged, clearError: true);
    _upload(staged);
  }

  void remove(int index) {
    if (state.isSaving || index < 0 || index >= state.photos.length) return;
    state = state.copyWith(photos: [...state.photos]..removeAt(index), clearError: true);
  }

  /// Moves the photo at [from] to [to]; position 1 is the main photo.
  void reorder(int from, int to) {
    final count = state.photos.length;
    if (state.isSaving || from < 0 || from >= count || to < 0 || to >= count || from == to) return;
    final photos = [...state.photos];
    photos.insert(to, photos.removeAt(from));
    state = state.copyWith(photos: photos);
  }

  /// Uploads a failed staged photo again.
  void retry(String localId) {
    final photo = _find(localId);
    if (photo == null || photo.status is! StageFailed) return;
    _upload(photo);
  }

  /// Commits the photos in their current order.
  ///
  /// On success the state becomes the server's set, and the profile providers are invalidated
  /// so the Profile tab and the hub show the change (primer rule 11). Returns the saved set,
  /// whose `verificationReset` says whether the verification photo was removed or replaced.
  ///
  /// Throws [PhotoSetConflictException] after reloading if the photos changed elsewhere since
  /// they were loaded, and [PhotoRepositoryException] with the server's message if it refused
  /// the set. Either way the error is also in [PhotoEditState.error].
  Future<MyPhotoCollection> save() async {
    if (!state.canSave) throw StateError('Nothing to save');
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final saved = await _repository.commitPhotoSet(state.revision, state.entries);
      _ref.invalidate(userProfileProvider);
      _ref.invalidate(myProfileProvider);
      if (mounted) _apply(saved);
      return saved;
    } on PhotoSetConflictException catch (e) {
      if (mounted) {
        // Before reloading: a failed reload keeps the rest of the state.
        state = state.copyWith(isSaving: false);
        await load();
        if (mounted) state = state.copyWith(error: e.message);
      }
      rethrow;
    } on PhotoRepositoryException catch (e) {
      if (mounted) state = state.copyWith(isSaving: false, error: e.message);
      rethrow;
    } catch (_) {
      if (mounted) state = state.copyWith(isSaving: false);
      rethrow;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  // -------------------------------------------------------------------------

  void _apply(MyPhotoCollection collection) {
    if (!mounted) return;
    _generation++;
    final photos = collection.photos.map(SavedPhoto.fromDTO).toList();
    state = PhotoEditState(photos: photos, original: photos, revision: collection.revision, isLoading: false);
  }

  Future<PickedPhoto?> _pick() async {
    try {
      return await _ref.read(photoPickerProvider).pick();
    } on PhotoPickException catch (e) {
      if (mounted) state = state.copyWith(error: e.message);
      return null;
    }
  }

  StagedPhoto _stage(PickedPhoto picked) => StagedPhoto(
        localId: 'staged-${_nextLocalId++}',
        localPath: picked.path,
        contentType: picked.contentType,
        sizeBytes: picked.sizeBytes,
        status: const StageUploading(0),
      );

  /// Starts [photo]'s upload without waiting for it. Results for a tile that has since been
  /// removed or replaced, or after the editor closed, are dropped.
  void _upload(StagedPhoto photo) {
    _setStatus(photo.localId, const StageUploading(0));
    final position = state.photos.indexWhere((p) => p is StagedPhoto && p.localId == photo.localId) + 1;
    _repository
        .stageUpload(
          file: File(photo.localPath),
          contentType: photo.contentType,
          sizeBytes: photo.sizeBytes,
          displayOrder: position.clamp(MediaConstants.minDisplayOrder, MediaConstants.maxDisplayOrder),
          onProgress: (progress) => _setStatus(photo.localId, StageUploading(progress)),
        )
        .then(
          (objectKey) => _setStatus(photo.localId, StageReady(objectKey)),
          onError: (Object e) => _setStatus(
            photo.localId,
            StageFailed(e is PhotoRepositoryException ? e.message : 'Upload failed. Tap to try again.'),
          ),
        );
  }

  StagedPhoto? _find(String localId) {
    for (final p in state.photos) {
      if (p is StagedPhoto && p.localId == localId) return p;
    }
    return null;
  }

  void _setStatus(String localId, StageStatus status) {
    if (!mounted) return;
    final index = state.photos.indexWhere((p) => p is StagedPhoto && p.localId == localId);
    if (index < 0) return;
    final photo = state.photos[index] as StagedPhoto;
    state = state.copyWith(photos: [...state.photos]..[index] = photo.withStatus(status));
  }
}

/// The photo editor's state. Disposed when the editor closes, so each visit starts from the
/// server's set.
final photoEditProvider = StateNotifierProvider.autoDispose<PhotoEditNotifier, PhotoEditState>(
  (ref) => PhotoEditNotifier(ref),
);
