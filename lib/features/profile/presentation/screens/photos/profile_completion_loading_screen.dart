import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/data/repositories/photo_repository.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_provider.dart';

/// Loading screen shown while uploading photos and completing profile setup
/// Based on Screenshot_Catalogue.md line 659-662
/// Handles batch photo upload with progress indication
class ProfileCompletionLoadingScreen extends ConsumerStatefulWidget {
  const ProfileCompletionLoadingScreen({super.key});

  @override
  ConsumerState<ProfileCompletionLoadingScreen> createState() =>
      _ProfileCompletionLoadingScreenState();
}

class _ProfileCompletionLoadingScreenState
    extends ConsumerState<ProfileCompletionLoadingScreen> {
  String _statusMessage = 'Uploading your photos...';
  double _uploadProgress = 0.0;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Start the upload process after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startProfileCompletion();
    });
  }

  Future<void> _startProfileCompletion() async {
    try {
      final photoState = ref.read(photoUploadProvider);
      final photoRepo = ref.read(photoRepositoryProvider);

      if (!photoState.hasMinimumPhotos) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Please add at least ${photoState.photos.length} photos before continuing.';
        });
        return;
      }

      // Step 1: Upload photos to S3
      setState(() {
        _statusMessage = 'Uploading your photos...';
        _uploadProgress = 0.0;
      });

      await photoRepo.batchUploadPhotos(
        photos: photoState.photos,
        onProgress: (current, total) {
          setState(() {
            _uploadProgress = current / total;
            _statusMessage = 'Uploading photo $current of $total...';
          });
        },
      );

      // Step 2: Finalizing profile
      setState(() {
        _statusMessage = 'Setting up your profile...';
        _uploadProgress = 1.0;
      });

      // Add a small delay to show the completion message
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _statusMessage = 'Getting your matches ready...';
      });

      await Future.delayed(const Duration(seconds: 1));

      // Navigate to welcome/onboarding screen
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/profile/welcome');
    } on BatchPhotoUploadException catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.getUserMessage();
      });
    } on PhotoRepositoryException catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              if (_hasError) ...[
                // Error state
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: AppColors.error,
                ),
                const SizedBox(height: 32),
                Text(
                  'Oops!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Something went wrong',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                // Loading state
                // Animated logo or icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          size: 60,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  },
                  onEnd: () {
                    // Loop the animation
                    if (mounted && !_hasError) {
                      setState(() {});
                    }
                  },
                ),

                const SizedBox(height: 48),

                // Status message
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Progress bar (if uploading photos)
                if (_uploadProgress > 0 && _uploadProgress < 1) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: AppColors.textSecondary.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${(_uploadProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ] else ...[
                  // Indeterminate progress
                  const SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Helpful message
                Text(
                  'This won\'t take long...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const Spacer(),

              // Retry button (only shown on error)
              if (_hasError) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _errorMessage = null;
                        _uploadProgress = 0.0;
                      });
                      _startProfileCompletion();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Try again',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Go back to photo screen to review/change photos
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Go back',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
