import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/app_settings.dart';
import '../../data/repositories/app_settings_repository.dart';
import '../../data/services/notification_permission_service.dart';
import 'package:eros_app/core/constants/languages.dart';

/// Provider for NotificationPermissionService
final notificationPermissionServiceProvider = Provider<NotificationPermissionService>((ref) {
  return NotificationPermissionService();
});

/// App settings state that includes both data and UI state
class AppSettingsState {
  final AppSettings settings;
  final bool isProcessing; // For showing loading on specific actions
  final String? errorMessage;
  final bool showPermissionDeniedDialog;

  const AppSettingsState({
    required this.settings,
    this.isProcessing = false,
    this.errorMessage,
    this.showPermissionDeniedDialog = false,
  });

  AppSettingsState copyWith({
    AppSettings? settings,
    bool? isProcessing,
    String? errorMessage,
    bool? showPermissionDeniedDialog,
    bool clearError = false,
  }) {
    return AppSettingsState(
      settings: settings ?? this.settings,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      showPermissionDeniedDialog: showPermissionDeniedDialog ?? this.showPermissionDeniedDialog,
    );
  }
}

/// App settings async notifier that properly handles initialization
class AppSettingsNotifier extends AsyncNotifier<AppSettingsState> {
  AppSettingsRepository? _repository;

  @override
  Future<AppSettingsState> build() async {
    // Initialize SharedPreferences and repository
    final prefs = await SharedPreferences.getInstance();
    final permissionService = ref.watch(notificationPermissionServiceProvider);
    _repository = AppSettingsRepository(prefs, permissionService);

    // Load settings
    final settings = await _repository!.loadSettings();

    return AppSettingsState(
      settings: settings,
      isProcessing: false,
    );
  }

  /// Toggle notifications on/off
  Future<void> toggleNotifications(bool enabled) async {
    final currentState = state.valueOrNull;
    if (currentState == null || _repository == null) return;

    try {
      // Update state to show processing
      state = AsyncValue.data(currentState.copyWith(
        isProcessing: true,
        clearError: true,
      ));

      final updatedSettings = await _repository!.updateNotificationSetting(
        currentSettings: currentState.settings,
        enabled: enabled,
      );

      // Check if permission was denied
      if (enabled && !updatedSettings.notificationsEnabled) {
        // Permission was denied
        state = AsyncValue.data(currentState.copyWith(
          settings: updatedSettings,
          isProcessing: false,
          showPermissionDeniedDialog: true,
        ));
      } else {
        state = AsyncValue.data(currentState.copyWith(
          settings: updatedSettings,
          isProcessing: false,
        ));
      }
    } catch (e) {
      state = AsyncValue.data(currentState.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to update notification settings',
      ));
    }
  }

  /// Update language
  Future<void> updateLanguage(Language language) async {
    final currentState = state.valueOrNull;
    if (currentState == null || _repository == null) return;

    try {
      // Update state to show processing
      state = AsyncValue.data(currentState.copyWith(
        isProcessing: true,
        clearError: true,
      ));

      final updatedSettings = await _repository!.updateLanguage(
        currentSettings: currentState.settings,
        language: language,
      );

      state = AsyncValue.data(currentState.copyWith(
        settings: updatedSettings,
        isProcessing: false,
      ));
    } catch (e) {
      state = AsyncValue.data(currentState.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to update language',
      ));
    }
  }

  /// Open device settings (for permission)
  Future<void> openDeviceSettings() async {
    if (_repository == null) return;
    await _repository!.openDeviceSettings();
  }

  /// Dismiss permission denied dialog
  void dismissPermissionDialog() {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(
      showPermissionDeniedDialog: false,
    ));
  }

  /// Refresh settings
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

/// Provider for app settings state
final appSettingsProvider = AsyncNotifierProvider<AppSettingsNotifier, AppSettingsState>(() {
  return AppSettingsNotifier();
});
