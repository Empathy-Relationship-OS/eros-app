import 'dart:io';
import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/photos/all_photos_screen.dart';

/// Screen for previewing a selected photo before adding it (or changing it)
/// Based on: screenshots/users/create-profile/B3F7C09E-4E3D-4DD4-BBB8-42DE6AB0C2D7.png
class PhotoSelectionScreen extends ConsumerStatefulWidget {
  final File imageFile;
  final bool isFirstPhoto;
  final int? existingPhotoIndex; // If editing an existing photo

  const PhotoSelectionScreen({
    super.key,
    required this.imageFile,
    this.isFirstPhoto = false,
    this.existingPhotoIndex,
  });

  @override
  ConsumerState<PhotoSelectionScreen> createState() =>
      _PhotoSelectionScreenState();
}

class _PhotoSelectionScreenState extends ConsumerState<PhotoSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Change photo button
              AppButton(
                label: 'Change photo',
                kind: AppButtonKind.outline,
                onPressed: _changePhoto,
              ),

              const SizedBox(height: 12),

              // Continue button
              AppButton(label: 'Continue', onPressed: _handleContinue),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
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
        ),
      ),
    );
  }

  void _handleContinue() {
    final notifier = ref.read(photoUploadProvider.notifier);

    if (widget.existingPhotoIndex != null) {
      // Replace existing photo
      notifier.replacePhoto(widget.existingPhotoIndex!, widget.imageFile.path);
      Navigator.of(context).pop();
    } else {
      // Add new photo
      notifier.addPhoto(localPath: widget.imageFile.path);

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
