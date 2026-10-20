/// Constants for media uploads (photos, videos, etc.)
///
/// These must match the backend's `MediaConstants`
/// (`eros-backend/users/src/main/kotlin/com/eros/users/models/UserMedia.kt`) exactly. The
/// backend is the source of truth (RFC-004 D-12). Change both together, and never hard-code a
/// type, size or count anywhere else.
class MediaConstants {
  MediaConstants._();

  /// Allowed content types for photo uploads
  static const List<String> allowedContentTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/heic',
    'image/heif',
    'image/webp',
  ];

  /// Minimum file size in bytes (100 KB)
  static const int minFileSizeBytes = 100 * 1024;

  /// Maximum file size in bytes (10 MB)
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  /// Minimum number of photos required
  static const int minPhotos = 3;

  /// Maximum number of photos allowed
  static const int maxPhotos = 6;

  /// Photo display order range
  static const int minDisplayOrder = 1;
  static const int maxDisplayOrder = 6;

  /// Get user-friendly file size string
  static String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Check if content type is allowed
  static bool isContentTypeAllowed(String contentType) {
    return allowedContentTypes.contains(contentType.toLowerCase());
  }

  /// Check if file size is within allowed range
  static bool isFileSizeValid(int bytes) {
    return bytes >= minFileSizeBytes && bytes <= maxFileSizeBytes;
  }

  /// User-facing message for a photo whose format isn't allowed.
  static const String unsupportedTypeMessage =
      'This photo format isn\'t supported. Please choose a JPEG, PNG, HEIC or WebP photo.';

  /// User-facing message for a photo outside the size limits.
  static String get invalidSizeMessage =>
      'Photo must be between ${formatBytes(minFileSizeBytes)} and ${formatBytes(maxFileSizeBytes)}';
}
