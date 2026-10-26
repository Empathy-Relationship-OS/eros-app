import 'package:eros_app/core/constants/media_constants.dart';

/// Request body for `POST /users/me/photos/presigned-url`: obtaining a presigned S3 URL.
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

/// Response of the presign: the URL to PUT the photo to, and the object key to commit it with.
class PresignedUploadResponse {
  final String uploadUrl; // presigned S3 PUT URL (expires in N minutes)
  final String objectKey; // S3 object key: send it in the photo-set commit
  final int expiresInMinutes;

  /// Headers the S3 PUT must send exactly as given, because they are signed into
  /// [uploadUrl] (e.g. `x-amz-tagging`). Empty when the backend lists none.
  final Map<String, String> requiredHeaders;

  PresignedUploadResponse({
    required this.uploadUrl,
    required this.objectKey,
    required this.expiresInMinutes,
    this.requiredHeaders = const {},
  });

  factory PresignedUploadResponse.fromJson(Map<String, dynamic> json) {
    final headers = json['requiredHeaders'] as Map<String, dynamic>?;
    return PresignedUploadResponse(
      uploadUrl: json['uploadUrl'] as String,
      objectKey: json['objectKey'] as String,
      expiresInMinutes: json['expiresInMinutes'] as int,
      requiredHeaders: headers == null
          ? const {}
          : headers.map((key, value) => MapEntry(key, value as String)),
    );
  }
}

/// Draft model for photo during profile creation
/// Holds local file path and metadata before upload
class PhotoUploadDraft {
  final String localPath; // Local file path from image picker
  final int displayOrder;
  final bool isPrimary;

  /// Content type accepted when the photo was picked. Upload reuses it so it can't reach a
  /// different answer. Null for drafts saved before this field existed.
  final String? contentType;
  final String? objectKey; // S3 object key once staged (null until uploaded)
  final int? mediaId; // Backend media ID once committed (null until then)

  PhotoUploadDraft({
    required this.localPath,
    required this.displayOrder,
    this.isPrimary = false,
    this.contentType,
    this.objectKey,
    this.mediaId,
  });

  /// [contentType] if it is still an allowed upload type, normalised; otherwise null, so the
  /// caller detects the type from the file instead.
  String? get acceptedContentType {
    final stored = contentType?.toLowerCase();
    if (stored == null || !MediaConstants.isContentTypeAllowed(stored)) return null;
    return stored == 'image/jpg' ? 'image/jpeg' : stored;
  }

  /// Uploaded to S3 and waiting to be committed ([objectKey] set).
  bool get isUploaded => objectKey != null;

  /// This draft with its upload forgotten, so the next submit uploads it again.
  PhotoUploadDraft withoutUpload() => PhotoUploadDraft(
        localPath: localPath,
        displayOrder: displayOrder,
        isPrimary: isPrimary,
        contentType: contentType,
      );

  /// Committed to the profile ([mediaId] set).
  bool get isConfirmed => mediaId != null;

  /// Get file name from local path
  String get fileName {
    return localPath.split('/').last;
  }

  PhotoUploadDraft copyWith({
    String? localPath,
    int? displayOrder,
    bool? isPrimary,
    String? contentType,
    String? objectKey,
    int? mediaId,
  }) {
    return PhotoUploadDraft(
      localPath: localPath ?? this.localPath,
      displayOrder: displayOrder ?? this.displayOrder,
      isPrimary: isPrimary ?? this.isPrimary,
      contentType: contentType ?? this.contentType,
      objectKey: objectKey ?? this.objectKey,
      mediaId: mediaId ?? this.mediaId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'localPath': localPath,
      'displayOrder': displayOrder,
      'isPrimary': isPrimary,
      if (contentType != null) 'contentType': contentType,
      if (objectKey != null) 'objectKey': objectKey,
      if (mediaId != null) 'mediaId': mediaId,
    };
  }

  factory PhotoUploadDraft.fromJson(Map<String, dynamic> json) {
    return PhotoUploadDraft(
      localPath: json['localPath'] as String,
      displayOrder: json['displayOrder'] as int,
      isPrimary: json['isPrimary'] as bool? ?? false,
      contentType: json['contentType'] as String?,
      objectKey: json['objectKey'] as String?,
      mediaId: json['mediaId'] as int?,
    );
  }
}

/// One of the user's photos as the photo editor reads it from `GET /users/me/photos`
/// (RFC-004 §5).
class MyPhotoDTO {
  final int id;

  /// Time-limited signed URL. It changes on every fetch, so cache images by [id], not by URL
  /// (primer rule 12).
  final String mediaUrl;
  final String? thumbnailUrl;
  final int displayOrder;
  final bool isPrimary;

  /// True for the photo the user's verification was checked against (RFC-004 §4.4).
  final bool isVerificationPhoto;

  const MyPhotoDTO({
    required this.id,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.displayOrder,
    required this.isPrimary,
    this.isVerificationPhoto = false,
  });

  factory MyPhotoDTO.fromJson(Map<String, dynamic> json) => MyPhotoDTO(
        id: json['id'] as int,
        mediaUrl: json['mediaUrl'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        displayOrder: json['displayOrder'] as int,
        isPrimary: json['isPrimary'] as bool,
        isVerificationPhoto: json['isVerificationPhoto'] as bool? ?? false,
      );
}

/// The user's photo set, from `GET /users/me/photos`, `PUT /users/me/photos` or
/// `DELETE /users/me/photos/{id}`.
class MyPhotoCollection {
  /// In position order; position 1 is the main photo.
  final List<MyPhotoDTO> photos;

  /// Identifies this exact set. A commit sends it back and gets a 409 if the set has changed
  /// since (RFC-004 D-4).
  final String revision;

  /// True when the write that produced this set removed the verification photo and so reset
  /// the user's verification. Always false on reads.
  final bool verificationReset;

  const MyPhotoCollection({
    required this.photos,
    required this.revision,
    this.verificationReset = false,
  });

  factory MyPhotoCollection.fromJson(Map<String, dynamic> json) {
    final photos = (json['media'] as List)
        .map((item) => MyPhotoDTO.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return MyPhotoCollection(
      photos: photos,
      revision: json['revision'] as String,
      verificationReset: json['verificationReset'] as bool? ?? false,
    );
  }
}

/// One entry of a photo-set commit: an existing photo by [photoId] or a staged upload by
/// [objectKey], never both.
class PhotoSetEntry {
  final int? photoId;
  final String? objectKey;

  const PhotoSetEntry.saved(int this.photoId) : objectKey = null;
  const PhotoSetEntry.staged(String this.objectKey) : photoId = null;

  Map<String, dynamic> toJson() => photoId != null ? {'photoId': photoId} : {'objectKey': objectKey};

  @override
  bool operator ==(Object other) =>
      other is PhotoSetEntry && other.photoId == photoId && other.objectKey == objectKey;

  @override
  int get hashCode => Object.hash(photoId, objectKey);

  @override
  String toString() => photoId != null ? 'saved($photoId)' : 'staged($objectKey)';
}
