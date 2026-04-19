import 'package:eros_app/core/constants/media_constants.dart';

/// Media type enum (currently only photos supported)
enum MediaType {
  photo,
  video;

  String toBackend() {
    switch (this) {
      case MediaType.photo:
        return 'PHOTO';
      case MediaType.video:
        return 'VIDEO';
    }
  }

  static MediaType fromBackend(String value) {
    switch (value.toUpperCase()) {
      case 'PHOTO':
        return MediaType.photo;
      case 'VIDEO':
        return MediaType.video;
      default:
        throw ArgumentError('Unknown media type: $value');
    }
  }
}

/// Request body for step 1 of the upload flow: obtaining a presigned S3 URL.
///
/// The client supplies file metadata so the backend can:
/// 1. Validate content type and size before issuing a presigned URL.
/// 2. Embed a content-length condition on the presigned URL so S3 rejects
///    uploads that exceed [fileSizeBytes].
class PresignedUploadRequest {
  final String fileName;
  final String contentType; // e.g. "image/jpeg", "image/png", "image/heic"
  final int fileSizeBytes; // used for S3 content-length-range condition
  final int displayOrder; // 1-6 — where this photo should appear
  final bool isPrimary;

  PresignedUploadRequest({
    required this.fileName,
    required this.contentType,
    required this.fileSizeBytes,
    required this.displayOrder,
    this.isPrimary = false,
  }) {
    if (displayOrder < MediaConstants.minDisplayOrder ||
        displayOrder > MediaConstants.maxDisplayOrder) {
      throw ArgumentError(
        'Display order must be between ${MediaConstants.minDisplayOrder} and ${MediaConstants.maxDisplayOrder}',
      );
    }
    if (fileName.trim().isEmpty) {
      throw ArgumentError('File name is required');
    }
    if (!MediaConstants.isContentTypeAllowed(contentType)) {
      throw ArgumentError(
        'Content type must be one of: ${MediaConstants.allowedContentTypes}',
      );
    }
    if (!MediaConstants.isFileSizeValid(fileSizeBytes)) {
      throw ArgumentError(
        'File size must be between ${MediaConstants.formatBytes(MediaConstants.minFileSizeBytes)} and ${MediaConstants.formatBytes(MediaConstants.maxFileSizeBytes)}',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'contentType': contentType,
      'fileSizeBytes': fileSizeBytes,
      'displayOrder': displayOrder,
      'isPrimary': isPrimary,
    };
  }
}

/// Response for step 1: the presigned URL and the object key the client must
/// use when confirming the upload in step 2.
class PresignedUploadResponse {
  final String uploadUrl; // presigned S3 PUT URL (expires in N minutes)
  final String objectKey; // S3 object key — send this back in ConfirmUploadRequest
  final int expiresInMinutes;

  PresignedUploadResponse({
    required this.uploadUrl,
    required this.objectKey,
    required this.expiresInMinutes,
  });

  factory PresignedUploadResponse.fromJson(Map<String, dynamic> json) {
    return PresignedUploadResponse(
      uploadUrl: json['uploadUrl'] as String,
      objectKey: json['objectKey'] as String,
      expiresInMinutes: json['expiresInMinutes'] as int,
    );
  }
}

/// Request body for step 2: confirming a completed upload.
///
/// The backend will perform a HeadObject check on [objectKey] to verify the
/// file was actually uploaded to S3 before persisting the record.
class ConfirmUploadRequest {
  final String objectKey;
  final int displayOrder;
  final bool isPrimary;

  ConfirmUploadRequest({
    required this.objectKey,
    required this.displayOrder,
    this.isPrimary = false,
  }) {
    if (displayOrder < MediaConstants.minDisplayOrder ||
        displayOrder > MediaConstants.maxDisplayOrder) {
      throw ArgumentError(
        'Display order must be between ${MediaConstants.minDisplayOrder} and ${MediaConstants.maxDisplayOrder}',
      );
    }
    if (objectKey.trim().isEmpty) {
      throw ArgumentError('Object key is required');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'objectKey': objectKey,
      'displayOrder': displayOrder,
      'isPrimary': isPrimary,
    };
  }
}

/// DTO used for mediaItem, extracts details not needed for response
class UserMediaItemDTO {
  final int id;
  final String mediaUrl;
  final String? thumbnailUrl;
  final MediaType mediaType;
  final int displayOrder;
  final bool isPrimary;

  UserMediaItemDTO({
    required this.id,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.mediaType,
    required this.displayOrder,
    required this.isPrimary,
  });

  factory UserMediaItemDTO.fromJson(Map<String, dynamic> json) {
    return UserMediaItemDTO(
      id: json['id'] as int,
      mediaUrl: json['mediaUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      mediaType: MediaType.fromBackend(json['mediaType'] as String),
      displayOrder: json['displayOrder'] as int,
      isPrimary: json['isPrimary'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'mediaType': mediaType.toBackend(),
      'displayOrder': displayOrder,
      'isPrimary': isPrimary,
    };
  }
}

/// Draft model for photo during profile creation
/// Holds local file path and metadata before upload
class PhotoUploadDraft {
  final String localPath; // Local file path from image picker
  final int displayOrder;
  final bool isPrimary;
  final String? caption; // Optional caption for the photo
  final String? objectKey; // S3 object key after upload (null if not uploaded yet)
  final int? mediaId; // Backend media ID after confirmation (null if not confirmed)

  PhotoUploadDraft({
    required this.localPath,
    required this.displayOrder,
    this.isPrimary = false,
    this.caption,
    this.objectKey,
    this.mediaId,
  });

  /// Check if photo has been uploaded to S3
  bool get isUploaded => objectKey != null;

  /// Check if upload has been confirmed with backend
  bool get isConfirmed => mediaId != null;

  PhotoUploadDraft copyWith({
    String? localPath,
    int? displayOrder,
    bool? isPrimary,
    String? caption,
    String? objectKey,
    int? mediaId,
  }) {
    return PhotoUploadDraft(
      localPath: localPath ?? this.localPath,
      displayOrder: displayOrder ?? this.displayOrder,
      isPrimary: isPrimary ?? this.isPrimary,
      caption: caption ?? this.caption,
      objectKey: objectKey ?? this.objectKey,
      mediaId: mediaId ?? this.mediaId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'localPath': localPath,
      'displayOrder': displayOrder,
      'isPrimary': isPrimary,
      if (caption != null) 'caption': caption,
      if (objectKey != null) 'objectKey': objectKey,
      if (mediaId != null) 'mediaId': mediaId,
    };
  }

  factory PhotoUploadDraft.fromJson(Map<String, dynamic> json) {
    return PhotoUploadDraft(
      localPath: json['localPath'] as String,
      displayOrder: json['displayOrder'] as int,
      isPrimary: json['isPrimary'] as bool? ?? false,
      caption: json['caption'] as String?,
      objectKey: json['objectKey'] as String?,
      mediaId: json['mediaId'] as int?,
    );
  }
}
