import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/photos/photo_selection_screen.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';
import 'package:eros_app/core/constants/profile_creation.dart' as constants;
import 'package:eros_app/core/constants/media_constants.dart';

/// Screen showing all photos in a grid (3-6 photos required)
/// Based on:
/// - screenshots/users/create-profile/31A175B9-8404-48F4-B608-8C751E1D03EF.png
/// - screenshots/users/create-profile/14FD30F8-F075-4743-ACE8-32CEF8978C75.png
class AllPhotosScreen extends ConsumerWidget {
  const AllPhotosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoState = ref.watch(photoUploadProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Add your photos',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle with count
                    Text(
                      '${photoState.photos.length}/${MediaConstants.maxPhotos} photos (min ${MediaConstants.minPhotos} required)',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Photo grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: MediaConstants.maxPhotos,
                      itemBuilder: (context, index) {
                        final hasPhoto = index < photoState.photos.length;

                        return _PhotoSlot(
                          index: index,
                          hasPhoto: hasPhoto,
                          photoPath: hasPhoto ? photoState.photos[index].localPath : null,
                          isPrimary: index == 0,
                          onTap: () => _handlePhotoSlotTap(context, ref, index, hasPhoto),
                          onRemove: hasPhoto
                              ? () => _handleRemovePhoto(ref, index)
                              : null,
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Info message
                    if (!photoState.hasMinimumPhotos)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Add at least ${MediaConstants.minPhotos} photos to continue',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: photoState.canProceed
                            ? () => _handleContinue(context)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.textSecondary.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text(
                          'Complete profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

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

  Future<void> _handlePhotoSlotTap(
    BuildContext context,
    WidgetRef ref,
    int index,
    bool hasPhoto,
  ) async {
    final notifier = ref.read(photoUploadProvider.notifier);

    if (hasPhoto) {
      // Edit existing photo - pick new image
      final newFile = await notifier.pickImageFromGallery();

      if (newFile == null) return;

      if (!context.mounted) return;

      // Navigate to photo selection screen for editing
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PhotoSelectionScreen(
            imageFile: newFile,
            existingPhotoIndex: index,
          ),
        ),
      );
    } else {
      // Add new photo
      final file = await notifier.pickImageFromGallery();

      if (file == null) return;

      if (!context.mounted) return;

      // Navigate to photo selection screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PhotoSelectionScreen(
            imageFile: file,
            isFirstPhoto: false,
          ),
        ),
      );
    }
  }

  void _handleRemovePhoto(WidgetRef ref, int index) {
    final notifier = ref.read(photoUploadProvider.notifier);
    notifier.removePhoto(index);
  }

  void _handleContinue(BuildContext context) {
    // Navigate to next screen in profile creation flow
    // TODO: Navigate to profile preview/submission screen
    Navigator.of(context).pushNamed('/profile/preview');
  }
}

class _PhotoSlot extends StatelessWidget {
  final int index;
  final bool hasPhoto;
  final String? photoPath;
  final bool isPrimary;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _PhotoSlot({
    required this.index,
    required this.hasPhoto,
    this.photoPath,
    required this.isPrimary,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: isPrimary
                  ? Border.all(color: AppColors.primary, width: 2)
                  : null,
            ),
            child: hasPhoto && photoPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(photoPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isPrimary ? 'Profile\nPicture' : 'Add\nPhoto',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withOpacity(0.7),
                            fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // Primary badge
          if (isPrimary && hasPhoto)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Primary',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // Remove button
          if (hasPhoto && onRemove != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),

          // Photo number indicator
          if (!hasPhoto)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
