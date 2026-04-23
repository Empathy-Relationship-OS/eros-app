import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/photos/caption_selection_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/photos/all_photos_screen.dart';

/// Screen for viewing selected photo and adding/editing caption
/// Based on: screenshots/users/create-profile/B3F7C09E-4E3D-4DD4-BBB8-42DE6AB0C2D7.png
class PhotoSelectionScreen extends ConsumerStatefulWidget {
  final File imageFile;
  final bool isFirstPhoto;
  final int? existingPhotoIndex; // If editing an existing photo
  final String? existingCaption; // Caption from existing photo

  const PhotoSelectionScreen({
    super.key,
    required this.imageFile,
    this.isFirstPhoto = false,
    this.existingPhotoIndex,
    this.existingCaption,
  });

  @override
  ConsumerState<PhotoSelectionScreen> createState() =>
      _PhotoSelectionScreenState();
}

class _PhotoSelectionScreenState extends ConsumerState<PhotoSelectionScreen> {
  String? _selectedCaption;

  @override
  void initState() {
    super.initState();
    // Initialize with existing caption if editing
    _selectedCaption = widget.existingCaption;
  }

  @override
  Widget build(BuildContext context) {
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Photo preview
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Caption display (if selected)
              if (_selectedCaption != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.label,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedCaption!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_selectedCaption != null) const SizedBox(height: 16),

              // Select/Change caption button
              OutlinedButton(
                onPressed: _navigateToCaption,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.primary, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  _selectedCaption == null ? 'Select caption' : 'Change caption',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Change photo button
              OutlinedButton(
                onPressed: _changePhoto,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.textSecondary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Change photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Continue button
              ElevatedButton(
                onPressed: _handleContinue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToCaption() async {
    final caption = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => CaptionSelectionScreen(
          currentCaption: _selectedCaption,
        ),
      ),
    );

    if (caption != null) {
      setState(() {
        _selectedCaption = caption;
      });
    }
  }

  Future<void> _changePhoto() async {
    final notifier = ref.read(photoUploadProvider.notifier);

    // Pick new image
    final newFile = await notifier.pickImageFromGallery();

    if (newFile == null) {
      return;
    }

    if (!mounted) return;

    // Replace current screen with new photo
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PhotoSelectionScreen(
          imageFile: newFile,
          isFirstPhoto: widget.isFirstPhoto,
          existingPhotoIndex: widget.existingPhotoIndex,
          existingCaption: _selectedCaption, // Preserve caption
        ),
      ),
    );
  }

  void _handleContinue() {
    final notifier = ref.read(photoUploadProvider.notifier);

    if (widget.existingPhotoIndex != null) {
      // Replace existing photo
      notifier.replacePhoto(widget.existingPhotoIndex!, widget.imageFile.path);
      notifier.updatePhotoCaption(widget.existingPhotoIndex!, _selectedCaption);
      Navigator.of(context).pop();
    } else {
      // Add new photo
      notifier.addPhoto(
        localPath: widget.imageFile.path,
        caption: _selectedCaption,
      );

      if (widget.isFirstPhoto) {
        // Navigate to all photos screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AllPhotosScreen(),
          ),
        );
      } else {
        // Return to all photos screen
        Navigator.of(context).pop();
      }
    }
  }
}
