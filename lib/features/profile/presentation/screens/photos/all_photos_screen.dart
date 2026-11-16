import 'dart:io';
import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/photos/photo_selection_screen.dart';
import 'package:eros_app/features/profile/presentation/widgets/photo_slot_tile.dart';
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar with padding
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: ProfileProgressBar(
                currentStep: constants.ProfileCreationConstants.profileStepPhotos,
                totalSteps: constants.ProfileCreationConstants.profileTotalSteps,
                sectionLabel: 'Profile',
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      'Add your photos',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),

                    const SizedBox(height: 8),

                    // Subtitle with count
                    Text(
                      '${photoState.photos.length}/${MediaConstants.maxPhotos} photos (min ${MediaConstants.minPhotos} required)',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),

                    const SizedBox(height: 8),

                    // Reorder hint
                    if (photoState.photos.length > 1)
                      Text(
                        'Long press and drag to reorder photos',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                      ),

                    const SizedBox(height: 32),

                    // Photo grid with drag-to-reorder
                    ReorderableGridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: MediaConstants.maxPhotos,
                      onReorder: (oldIndex, newIndex) {
                        // Only allow reordering of photos that exist
                        if (oldIndex < photoState.photos.length &&
                            newIndex < photoState.photos.length) {
                          ref.read(photoUploadProvider.notifier).reorderPhotos(
                                oldIndex,
                                newIndex,
                              );
                        }
                      },
                      dragWidgetBuilder: (index, child) {
                        // Add visual feedback during drag
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.ink.withValues(alpha: 0.3),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Opacity(
                            opacity: 0.8,
                            child: child,
                          ),
                        );
                      },
                      itemBuilder: (context, index) {
                        final hasPhoto = index < photoState.photos.length;

                        return _PhotoSlot(
                          key: ValueKey('photo_slot_$index'),
                          index: index,
                          hasPhoto: hasPhoto,
                          photoPath: hasPhoto ? photoState.photos[index].localPath : null,
                          isPrimary: index == 0,
                          onTap: () => _handlePhotoSlotTap(context, ref, index, hasPhoto),
                          onRemove: hasPhoto
                              ? () => _handleRemovePhoto(ref, index)
                              : null,
                          enableDrag: hasPhoto, // Only allow dragging if photo exists
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Info message
                    if (!photoState.hasMinimumPhotos)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColors.primaryDeep,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Add at least ${MediaConstants.minPhotos} photos to continue',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Continue button
                    AppButton(
                      label: 'Complete profile',
                      onPressed: photoState.canProceed ? () => _handleContinue(context) : null,
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
    final photoState = ref.read(photoUploadProvider);

    if (hasPhoto) {
      // View/edit existing photo - navigate to selection screen
      final existingPhoto = photoState.photos[index];
      final existingFile = File(existingPhoto.localPath);

      if (!context.mounted) return;

      // Navigate to photo selection screen for viewing/editing
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PhotoSelectionScreen(
            imageFile: existingFile,
            existingPhotoIndex: index,
          ),
        ),
      );
    } else {
      // Add new photo - pick from gallery
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
    // Navigate to profile preview screen
    // User will review their public profile and give consent
    Navigator.of(context).pushNamed('/profile/preview');
  }
}

/// Onboarding's photo slot: the local file in a [PhotoSlotTile].
class _PhotoSlot extends StatelessWidget {
  final int index;
  final bool hasPhoto;
  final String? photoPath;
  final bool isPrimary;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final bool enableDrag;

  const _PhotoSlot({
    super.key,
    required this.index,
    required this.hasPhoto,
    this.photoPath,
    required this.isPrimary,
    required this.onTap,
    this.onRemove,
    this.enableDrag = false,
  });

  @override
  Widget build(BuildContext context) {
    return PhotoSlotTile(
      index: index,
      image: hasPhoto && photoPath != null
          ? Image.file(
              File(photoPath!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          : null,
      isPrimary: isPrimary,
      onTap: onTap,
      onRemove: hasPhoto ? onRemove : null,
    );
  }
}
