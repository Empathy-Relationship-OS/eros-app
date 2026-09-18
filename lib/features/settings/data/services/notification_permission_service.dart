import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

/// Service for handling notification permissions
class NotificationPermissionService {
  final Logger _logger = Logger();

  /// Check if notification permission is granted
  Future<bool> isNotificationPermissionGranted() async {
    final status = await Permission.notification.status;
    _logger.d('📱 Notification permission status: $status');
    return status.isGranted;
  }

  /// Request notification permission
  /// Returns true if granted, false otherwise
  Future<bool> requestNotificationPermission() async {
    try {
      _logger.d('📱 Requesting notification permission');

      final status = await Permission.notification.request();

      _logger.d('📱 Notification permission result: $status');

      if (status.isGranted) {
        _logger.d('✅ Notification permission granted');
        return true;
      } else if (status.isDenied) {
        _logger.d('❌ Notification permission denied');
        return false;
      } else if (status.isPermanentlyDenied) {
        _logger.d('🚫 Notification permission permanently denied');
        return false;
      }

      return false;
    } catch (e) {
      _logger.e('🚨 Error requesting notification permission', error: e);
      return false;
    }
  }

  /// Open app settings to allow user to manually enable notifications
  Future<bool> openAppSettingsPage() async {
    try {
      _logger.d('📱 Opening app settings');
      return await openAppSettings();
    } catch (e) {
      _logger.e('🚨 Error opening app settings', error: e);
      return false;
    }
  }

  /// Check if we should show permission rationale
  /// (useful for showing explanation before requesting permission)
  Future<bool> shouldShowRequestRationale() async {
    final status = await Permission.notification.status;
    return status.isDenied && !status.isPermanentlyDenied;
  }
}
