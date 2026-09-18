import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/constants/languages.dart';
import '../providers/app_settings_provider.dart';

/// App Settings Screen - Allows users to configure app-level settings
/// - Toggle notifications on/off (with permission handling)
/// - Change app language
class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);

    // Listen for permission dialog and errors
    ref.listen<AsyncValue<AppSettingsState>>(appSettingsProvider, (previous, next) {
      next.whenData((state) {
        // Show permission denied dialog if needed
        if (state.showPermissionDeniedDialog) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPermissionDeniedDialog();
          });
        }

        // Show error snackbar if needed
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
            ),
          );
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load settings',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ref.read(appSettingsProvider.notifier).refresh();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (state) => _buildSettingsContent(state),
      ),
    );
  }

  Widget _buildSettingsContent(AppSettingsState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Notifications Section
        _SettingsSection(
          title: 'Notifications',
          children: [
            _NotificationToggleTile(
              isEnabled: state.settings.notificationsEnabled,
              isProcessing: state.isProcessing,
              onChanged: (value) {
                ref.read(appSettingsProvider.notifier).toggleNotifications(value);
              },
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Language Section
        _SettingsSection(
          title: 'Language',
          children: [
            _LanguageSelectorTile(
              currentLanguage: state.settings.language,
              isProcessing: state.isProcessing,
              onLanguageSelected: (language) {
                ref.read(appSettingsProvider.notifier).updateLanguage(language);
              },
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Info text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Changes to language will take effect immediately. Notification settings require system permissions.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Permission Required'),
        content: const Text(
          'To receive notifications, you need to enable permissions in your device settings. Would you like to open settings now?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(appSettingsProvider.notifier).dismissPermissionDialog();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(appSettingsProvider.notifier).dismissPermissionDialog();
              ref.read(appSettingsProvider.notifier).openDeviceSettings();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryOrange),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

/// Settings section widget
class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

/// Notification toggle tile
class _NotificationToggleTile extends StatelessWidget {
  final bool isEnabled;
  final bool isProcessing;
  final ValueChanged<bool> onChanged;

  const _NotificationToggleTile({
    required this.isEnabled,
    required this.isProcessing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Icon
          Icon(
            isEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
            size: 24,
            color: AppColors.textPrimary,
          ),

          const SizedBox(width: 16),

          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Push Notifications',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEnabled
                      ? 'Get notified about matches and dates'
                      : 'Turn on to receive notifications',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),

          // Toggle switch or loading indicator
          if (isProcessing)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: isEnabled,
              onChanged: onChanged,
              activeTrackColor: AppColors.primaryOrange,
            ),
        ],
      ),
    );
  }
}

/// Language selector tile - reuses the existing language selection popup
class _LanguageSelectorTile extends StatelessWidget {
  final Language currentLanguage;
  final bool isProcessing;
  final ValueChanged<Language> onLanguageSelected;

  const _LanguageSelectorTile({
    required this.currentLanguage,
    required this.isProcessing,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isProcessing
          ? null
          : () {
              _showLanguageSelector(context);
            },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            // Icon
            const Icon(
              Icons.language,
              size: 24,
              color: AppColors.textPrimary,
            ),

            const SizedBox(width: 16),

            // Title and current language
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Language',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  if (isProcessing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Row(
                      children: [
                        Text(
                          currentLanguage.flag,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentLanguage.nativeName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right,
              size: 24,
              color: isProcessing ? AppColors.divider : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LanguageSelectionPopupWithCallback(
        onLanguageSelected: onLanguageSelected,
      ),
    );
  }
}

/// Wrapper for language selection popup to handle selection callback
class _LanguageSelectionPopupWithCallback extends ConsumerWidget {
  final ValueChanged<Language> onLanguageSelected;

  const _LanguageSelectionPopupWithCallback({
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Select Language',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),

            const SizedBox(height: 16),

            // Language list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: Languages.all.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final language = Languages.all[index];
                  final currentLanguageCode = settingsAsync.when(
                    data: (state) => state.settings.language.code,
                    loading: () => 'en',
                    error: (error, stackTrace) => 'en',
                  );
                  final isSelected = language.code == currentLanguageCode;

                  return ListTile(
                    leading: Text(
                      language.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      language.nativeName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    subtitle: Text(
                      language.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.primaryOrange,
                          )
                        : null,
                    onTap: () {
                      // Update selected language
                      onLanguageSelected(language);
                      // Close popup
                      Navigator.pop(context);
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
