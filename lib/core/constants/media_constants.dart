/// Constants for media uploads (photos, videos, etc.)
class MediaConstants {
  MediaConstants._();

  /// Allowed content types for photo uploads
  static const List<String> allowedContentTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/heic',
    'image/heif',
  ];

  /// Minimum file size in bytes (10 KB)
  static const int minFileSizeBytes = 10 * 1024;

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
}
