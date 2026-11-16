import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/constants/media_constants.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_provider.dart';

/// Loading screen shown while uploading photos and completing profile setup
/// Based on Screenshot_Catalogue.md line 659-662
/// Uploads the photos, then saves them all at once, with progress (PhotoUploadNotifier.submitPhotos)
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
    final notifier = ref.read(photoUploadProvider.notifier);
    if (!ref.read(photoUploadProvider).hasMinimumPhotos) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Please add at least ${MediaConstants.minPhotos} photos before continuing.';
      });
      return;
    }

    // Step 1: upload every photo, then save them all at once (RFC-004 D-8). A retry uploads only
    // the photos that failed.
    setState(() {
      _statusMessage = 'Uploading your photos...';
      _uploadProgress = 0.0;
    });
    final saved = await notifier.submitPhotos(
      onProgress: (uploaded, total) {
        if (!mounted) return;
        setState(() {
          _uploadProgress = uploaded / total;
          _statusMessage = 'Uploading photo ${uploaded < total ? uploaded + 1 : total} of $total...';
        });
      },
    );
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _hasError = true;
        _errorMessage = ref.read(photoUploadProvider).error ?? 'Something went wrong. Please try again.';
      });
      return;
    }

    // Step 2: finalising the profile
    setState(() {
      _statusMessage = 'Setting up your profile...';
      _uploadProgress = 1.0;
    });

    // Add a small delay to show the completion message
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Getting your matches ready...';
    });

    await Future.delayed(const Duration(seconds: 1));

    // Navigate to welcome/onboarding screen
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/profile/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Something went wrong',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                          color: AppColors.primaryTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          size: 60,
                          color: AppColors.primaryDeep,
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
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Progress bar (if uploading photos)
                if (_uploadProgress > 0 && _uploadProgress < 1) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: AppColors.textSecondary.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${(_uploadProgress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primaryDeep,
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],

              const Spacer(),

              // Retry button (only shown on error)
              if (_hasError) ...[
                AppButton(
                  label: 'Try again',
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _errorMessage = null;
                      _uploadProgress = 0.0;
                    });
                    _startProfileCompletion();
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Go back to photo screen to review/change photos
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Go back',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
