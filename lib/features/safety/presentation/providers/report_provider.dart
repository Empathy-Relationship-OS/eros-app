import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:eros_app/core/constants/user_text_limits.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/utils/image_content_type.dart';
import 'package:eros_app/core/utils/user_text.dart';
import 'package:eros_app/features/safety/data/models/safety_models.dart';
import 'package:eros_app/features/safety/data/repositories/safety_repository.dart';
import 'package:eros_app/features/safety/presentation/widgets/safety_copy.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SafetyRepository(apiClient);
});

/// Picks evidence images. Overridden in tests.
final evidenceImagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

/// Report reasons from the API (primer rule 21).
final safetyReasonsProvider = FutureProvider.autoDispose<List<SafetyReason>>((ref) {
  return ref.watch(safetyRepositoryProvider).getReasons();
});

enum EvidenceUploadStatus { uploading, uploaded, failed }

/// One picked image and how its upload went.
class EvidenceImage {
  /// Local key, so a remove or an upload result finds the right image.
  final String localId;
  final Uint8List bytes;
  final String contentType;
  final EvidenceUploadStatus status;

  /// Set once uploaded.
  final String? evidenceId;

  const EvidenceImage({
    required this.localId,
    required this.bytes,
    required this.contentType,
    this.status = EvidenceUploadStatus.uploading,
    this.evidenceId,
  });

  EvidenceImage copyWith({EvidenceUploadStatus? status, String? evidenceId}) => EvidenceImage(
        localId: localId,
        bytes: bytes,
        contentType: contentType,
        status: status ?? this.status,
        evidenceId: evidenceId ?? this.evidenceId,
      );
}

/// The report form: what's chosen, what's uploaded, and how the submit went.
class ReportState {
  final String? reasonCode;

  /// As typed. Cleaned with `UserText` only when submitted.
  final String description;
  final List<EvidenceImage> images;
  final bool isSubmitting;

  /// Set once the report is filed.
  final ReportResult? result;

  /// A problem with the whole form, shown near the submit button.
  final String? errorMessage;

  /// A picked image that was refused before upload (type or size).
  final String? imageError;

  /// The last submit got a 409: already reported, or the date had already ended.
  final bool conflict;

  const ReportState({
    this.reasonCode,
    this.description = '',
    this.images = const [],
    this.isSubmitting = false,
    this.result,
    this.errorMessage,
    this.imageError,
    this.conflict = false,
  });

  bool get canAddImage => images.length < SafetyLimits.maxEvidenceImages;
  bool get hasFailedImage => images.any((i) => i.status == EvidenceUploadStatus.failed);

  ReportState copyWith({
    String? reasonCode,
    String? description,
    List<EvidenceImage>? images,
    bool? isSubmitting,
    ReportResult? result,
    String? errorMessage,
    String? imageError,
    bool? conflict,
    bool clearErrorMessage = false,
    bool clearImageError = false,
  }) {
    return ReportState(
      reasonCode: reasonCode ?? this.reasonCode,
      description: description ?? this.description,
      images: images ?? this.images,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: result ?? this.result,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      imageError: clearImageError ? null : (imageError ?? this.imageError),
      conflict: conflict ?? this.conflict,
    );
  }
}

/// Holds one report form for one date (RFC-006 §6.5).
///
/// Images upload as soon as they're picked. A failed upload never blocks the report: the
/// person can remove it, or submit and only the uploaded images are attached.
class ReportNotifier extends StateNotifier<ReportState> {
  final SafetyRepository _repository;
  final String _dateId;
  final Logger _logger = Logger();
  final Map<String, Future<void>> _uploads = {};

  ReportNotifier(this._repository, this._dateId) : super(const ReportState());

  void selectReason(String code) {
    state = state.copyWith(reasonCode: code, clearErrorMessage: true);
  }

  /// Selects [code] only if nothing is chosen yet.
  void preselectReason(String code) {
    if (state.reasonCode == null) state = state.copyWith(reasonCode: code);
  }

  void setDescription(String raw) {
    state = state.copyWith(description: raw);
  }

  /// Checks [bytes] and starts uploading them. [path] and [reportedMimeType] come from the
  /// picker and only help recognise the type.
  Future<void> addImage({
    required Uint8List bytes,
    required String path,
    String? reportedMimeType,
  }) async {
    if (!state.canAddImage) return;

    final contentType = detectImageContentType(
      path: path,
      headerBytes: bytes.length > imageHeaderBytesLength
          ? bytes.sublist(0, imageHeaderBytesLength)
          : bytes,
      reportedMimeType: reportedMimeType,
    );
    if (contentType == null || !SafetyLimits.evidenceContentTypes.contains(contentType)) {
      state = state.copyWith(imageError: SafetyCopy.imageWrongType);
      return;
    }
    if (bytes.isEmpty || bytes.length > SafetyLimits.maxEvidenceBytes) {
      state = state.copyWith(imageError: SafetyCopy.imageTooBig);
      return;
    }

    final image = EvidenceImage(
      localId: const Uuid().v4(),
      bytes: bytes,
      contentType: contentType,
    );
    state = state.copyWith(images: [...state.images, image], clearImageError: true);

    final upload = _upload(image);
    _uploads[image.localId] = upload;
    await upload;
    _uploads.remove(image.localId);
  }

  Future<void> _upload(EvidenceImage image) async {
    try {
      final ticket = await _repository.requestEvidenceUpload(
        _dateId,
        contentType: image.contentType,
        fileSizeBytes: image.bytes.length,
      );
      await _repository.uploadEvidence(ticket, bytes: image.bytes, contentType: image.contentType);
      _updateImage(
        image.localId,
        (i) => i.copyWith(status: EvidenceUploadStatus.uploaded, evidenceId: ticket.evidenceId),
      );
    } catch (e) {
      _logger.w('⚠️  Evidence upload failed for date $_dateId', error: e);
      _updateImage(image.localId, (i) => i.copyWith(status: EvidenceUploadStatus.failed));
    }
  }

  void _updateImage(String localId, EvidenceImage Function(EvidenceImage) update) {
    if (!mounted) return;
    state = state.copyWith(
      images: [for (final i in state.images) i.localId == localId ? update(i) : i],
    );
  }

  void removeImage(String localId) {
    state = state.copyWith(
      images: state.images.where((i) => i.localId != localId).toList(),
      clearErrorMessage: true,
    );
  }

  void showImageError(String message) {
    state = state.copyWith(imageError: message);
  }

  void clearImageError() {
    state = state.copyWith(clearImageError: true);
  }

  /// The first problem that stops the form being submitted, or null.
  String? validate() {
    if (state.reasonCode == null) return SafetyCopy.chooseReason;
    return UserText.validate(
      state.description,
      name: 'Description',
      maxLength: UserTextLimits.reportDescription,
      multiline: true,
    );
  }

  /// Shows the first problem with the form, if any. Returns true when it can be submitted.
  bool checkReady() {
    final error = validate();
    state = error == null
        ? state.copyWith(clearErrorMessage: true)
        : state.copyWith(errorMessage: error);
    return error == null;
  }

  /// Files the report. Waits for uploads still in flight, then attaches the ones that
  /// succeeded. Returns true when filed; [ReportState.result] holds the outcome.
  Future<bool> submit(ReportOrigin origin) async {
    if (state.isSubmitting || !checkReady()) return false;

    state = state.copyWith(isSubmitting: true, conflict: false, clearErrorMessage: true);
    await Future.wait(_uploads.values.toList());
    if (!mounted) return false;

    final description = UserText.clean(state.description, multiline: true);
    final evidenceIds = [
      for (final i in state.images)
        if (i.status == EvidenceUploadStatus.uploaded) i.evidenceId!,
    ];

    try {
      final result = await _repository.submitReport(
        _dateId,
        ReportRequest(
          origin: origin,
          reason: state.reasonCode!,
          description: description.isEmpty ? null : description,
          evidenceIds: evidenceIds,
        ),
      );
      if (!mounted) return true;
      state = state.copyWith(isSubmitting: false, result: result);
      return true;
    } on ConflictException {
      if (!mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        conflict: true,
        errorMessage: origin == ReportOrigin.cancel
            ? SafetyCopy.alreadyEndedOnCancel
            : SafetyCopy.alreadyReported,
      );
    } on ValidationException {
      // The backend refuses a bad evidence id with a 400 (CH-B8). Mark the images as failed,
      // so the person can remove them and still send the report.
      if (!mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: evidenceIds.isEmpty ? SafetyCopy.submitFailed : SafetyCopy.imagesNotAttached,
        images: evidenceIds.isEmpty
            ? null
            : [for (final i in state.images) i.copyWith(status: EvidenceUploadStatus.failed)],
      );
    } on NetworkException {
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false, errorMessage: SafetyCopy.networkError);
    } catch (e) {
      _logger.e('🚨 Report failed for date $_dateId');
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false, errorMessage: SafetyCopy.submitFailed);
    }
    return false;
  }
}

/// One report form per date, dropped when nothing shows it.
final reportProvider =
    StateNotifierProvider.autoDispose.family<ReportNotifier, ReportState, String>((ref, dateId) {
  return ReportNotifier(ref.watch(safetyRepositoryProvider), dateId);
});
