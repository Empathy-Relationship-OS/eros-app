import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/photos/photo_selection_screen.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';
import 'package:eros_app/core/constants/profile_creation.dart' as constants;

/// First screen in photo upload flow
/// Prompts user to add their profile picture (first photo)
/// Based on: screenshots/users/create-profile/9D077F6E-F156-4B54-9297-37EC45AE7D10.png
class AddProfilePictureScreen extends ConsumerWidget {
  const AddProfilePictureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoState = ref.watch(photoUploadProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            ProfileProgressBar(
              currentStep: constants.ProfileCreationConstants.profileStepPhotos,
              totalSteps: constants.ProfileCreationConstants.profileTotalSteps,
              sectionLabel: 'Profile',
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),

                    // Camera icon
                    const Icon(
                      Icons.camera_alt,
                      size: 48,
                      color: AppColors.textPrimary,
                    ),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Add your profile picture',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),

                    const SizedBox(height: 32),

                    // Image placeholder
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Add photo icon
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    size: 100,
                                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: AppColors.textPrimary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: AppColors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Tips section
                    Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pick your best profile picture',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    GestureDetector(
                      onTap: () {
                        // TODO: Show tips dialog
                        _showTipsDialog(context);
                      },
                      child: Text(
                        'Tap here for more tips!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.underline,
                            ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Error message
                    if (photoState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.input),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  photoState.error!,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppColors.error,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Add photo button
                    AppButton(label: 'Add a photo', onPressed: () => _handleAddPhoto(context, ref)),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddPhoto(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(photoUploadProvider.notifier);

    // Pick image from gallery
    final file = await notifier.pickImageFromGallery();

    if (file == null) {
      // User cancelled or error occurred
      return;
    }

    if (!context.mounted) return;

    // Navigate to photo selection screen to preview the photo
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhotoSelectionScreen(
          imageFile: file,
          isFirstPhoto: true,
        ),
      ),
    );
  }

  void _showTipsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Photo Tips'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _TipItem(
                icon: Icons.face,
                text: 'Show your face clearly',
              ),
              SizedBox(height: 12),
              _TipItem(
                icon: Icons.sunny,
                text: 'Use good lighting',
              ),
              SizedBox(height: 12),
              _TipItem(
                icon: Icons.photo_camera,
                text: 'Choose recent photos',
              ),
              SizedBox(height: 12),
              _TipItem(
                icon: Icons.celebration,
                text: 'Be authentic and genuine',
              ),
              SizedBox(height: 12),
              _TipItem(
                icon: Icons.warning_amber,
                text: 'Avoid group photos for your profile picture',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primaryDeep,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
