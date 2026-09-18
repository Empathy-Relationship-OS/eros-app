import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../../domain/models/app_settings.dart';
import '../services/notification_permission_service.dart';
import 'package:eros_app/core/constants/languages.dart';

/// Repository for managing app settings
class AppSettingsRepository {
  static const String _settingsKey = 'app_settings';

  final SharedPreferences _prefs;
  final NotificationPermissionService _permissionService;
  final Logger _logger = Logger();

  AppSettingsRepository(this._prefs, this._permissionService);

  /// Load settings from local storage
  Future<AppSettings> loadSettings() async {
    try {
      final settingsJson = _prefs.getString(_settingsKey);

      if (settingsJson == null) {
        _logger.d('📱 No saved settings found, using defaults');
        return AppSettings.defaultSettings();
      }

      final json = jsonDecode(settingsJson) as Map<String, dynamic>;
      final settings = AppSettings.fromJson(json);

      _logger.d('📱 Loaded settings: notifications=${settings.notificationsEnabled}, language=${settings.language.code}');

      return settings;
    } catch (e) {
      _logger.e('🚨 Error loading settings', error: e);
      return AppSettings.defaultSettings();
    }
  }

  /// Save settings to local storage
  Future<void> saveSettings(AppSettings settings) async {
    try {
      final json = settings.toJson();
      final settingsJson = jsonEncode(json);

      await _prefs.setString(_settingsKey, settingsJson);

      _logger.d('💾 Saved settings: notifications=${settings.notificationsEnabled}, language=${settings.language.code}');
    } catch (e) {
      _logger.e('🚨 Error saving settings', error: e);
      rethrow;
    }
  }

  /// Update notification setting
  /// This will also request/check permission if enabling
  Future<AppSettings> updateNotificationSetting({
    required AppSettings currentSettings,
    required bool enabled,
  }) async {
    try {
      if (enabled) {
        // Check current permission status
        final isGranted = await _permissionService.isNotificationPermissionGranted();

        if (!isGranted) {
          // Request permission
          final granted = await _permissionService.requestNotificationPermission();

          if (!granted) {
            _logger.d('❌ Notification permission not granted, keeping disabled');
            // Keep notifications disabled if permission denied
            return currentSettings.copyWith(notificationsEnabled: false);
          }
        }

        // Permission granted, enable notifications
        final updatedSettings = currentSettings.copyWith(notificationsEnabled: true);
        await saveSettings(updatedSettings);
        return updatedSettings;
      } else {
        // Disable notifications (no permission check needed)
        final updatedSettings = currentSettings.copyWith(notificationsEnabled: false);
        await saveSettings(updatedSettings);
        return updatedSettings;
      }
    } catch (e) {
      _logger.e('🚨 Error updating notification setting', error: e);
      rethrow;
    }
  }

  /// Update language setting
  Future<AppSettings> updateLanguage({
    required AppSettings currentSettings,
    required Language language,
  }) async {
    try {
      final updatedSettings = currentSettings.copyWith(language: language);
      await saveSettings(updatedSettings);
      _logger.d('🌍 Updated language to: ${language.code}');
      return updatedSettings;
    } catch (e) {
      _logger.e('🚨 Error updating language', error: e);
      rethrow;
    }
  }

  /// Open device settings (for when permission is permanently denied)
  Future<void> openDeviceSettings() async {
    await _permissionService.openAppSettingsPage();
  }
}
