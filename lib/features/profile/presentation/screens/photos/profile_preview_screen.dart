import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/profile/domain/models/public_profile.dart';
import 'package:eros_app/features/profile/domain/models/photo_models.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_display_components.dart';

/// Screen to preview what the user's profile will look like to others
/// Based on screenshots/users/public-profile/*.PNG
/// Line 664-675 in Screenshot_Catalogue.md
class ProfilePreviewScreen extends ConsumerStatefulWidget {
  const ProfilePreviewScreen({super.key});

  @override
  ConsumerState<ProfilePreviewScreen> createState() => _ProfilePreviewScreenState();
}

class _ProfilePreviewScreenState extends ConsumerState<ProfilePreviewScreen> {
  bool _consentChecked = false;
  late final Future<PublicProfileDTO> _profileFuture;

  @override
  void initState() {
    super.initState();
    // Fetch profile once during initialization
    final authService = ref.read(authServiceProvider);
    try {
      final userId = authService.getUserId();
      _profileFuture = ref.read(profileRepositoryProvider).getPublicProfile(userId);
    } catch (e) {
      _profileFuture = Future.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get local photos that haven't been uploaded yet
    final localPhotoState = ref.watch(photoUploadProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Preview your profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FutureBuilder<PublicProfileDTO>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (profileSnapshot.hasError) {
            final errorMessage = profileSnapshot.error.toString().contains('sign in')
                ? 'Please sign in to preview your profile'
                : 'Unable to load profile preview';

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profileSnapshot.error.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!profileSnapshot.hasData) {
            return const Center(
              child: Text('No profile data available'),
            );
          }

          final profile = profileSnapshot.data!;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: _ProfilePreviewContent(
                    profile: profile,
                    localPhotos: localPhotoState.photos.isNotEmpty
                        ? localPhotoState.photos
                        : null,
                  ),
                ),
              ),
              _ConsentBottomBar(
                consentChecked: _consentChecked,
                onConsentChanged: (value) {
                  setState(() {
                    _consentChecked = value;
                  });
                },
                onContinue: _handleContinue,
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleContinue() {
    // Navigate to loading/completion screen
    // This will handle photo upload + profile creation if needed
    Navigator.of(context).pushNamed('/profile/complete-loading');
  }
}

/// Content widget showing the profile preview
class _ProfilePreviewContent extends StatelessWidget {
  final PublicProfileDTO profile;
  final List<PhotoUploadDraft>? localPhotos; // Local photos with captions

  const _ProfilePreviewContent({
    required this.profile,
    this.localPhotos,
  });

  @override
  Widget build(BuildContext context) {
    final qas = profile.profile.qas;

    // Determine which photos to use
    final bool useLocal = localPhotos != null && localPhotos!.isNotEmpty;
    final String? thumbnailPath;
    final List<PhotoWithCaption> remainingPhotos;

    if (useLocal) {
      // Use local photos with captions
      thumbnailPath = localPhotos!.first.localPath;
      remainingPhotos = localPhotos!.length > 1
          ? localPhotos!.sublist(1).map((p) => PhotoWithCaption(
                path: p.localPath,
                caption: p.caption,
                isLocal: true,
              )).toList()
          : [];
    } else {
      // Use backend photos (no captions available yet)
      final backendPhotos = profile.profile.photos;
      thumbnailPath = backendPhotos.isNotEmpty ? backendPhotos.first : null;
      remainingPhotos = backendPhotos.length > 1
          ? backendPhotos.sublist(1).map((p) => PhotoWithCaption(
                path: p,
                caption: null,
                isLocal: false,
              )).toList()
          : [];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Thumbnail photo (large)
        if (thumbnailPath != null)
          ThumbnailPhoto(
            photoPath: thumbnailPath,
            isLocal: useLocal,
          ),

        Container(
          margin: const EdgeInsets.all(16.0),
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name and Age
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    profile.name,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${profile.age}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bio (if available)
              if (profile.profile.bio != null && profile.profile.bio!.isNotEmpty) ...[
                Text(
                  profile.profile.bio!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 2. Horizontal scrollable info row (basic attributes)
              HorizontalInfoScroll(profile: profile),
              const SizedBox(height: 24),

              // 3. Work/Education/Location/Language rows
              DetailedInfoSection(profile: profile),
            ],
          ),
        ),

        // 4. Ordered content: Hobbies -> QA1 -> Image -> QA2 -> Image -> Personality -> Image -> QA3 -> Image -> QAs
        OrderedInterspersedContent(
          hobbies: profile.profile.hobbies,
          traits: profile.profile.traits,
          brainAttribute: profile.profile.brainAttribute,
          brainDescription: profile.profile.brainDescription,
          bodyAttribute: profile.profile.bodyAttribute,
          bodyDescription: profile.profile.bodyDescription,
          photos: remainingPhotos,
          qas: qas,
        ),
      ],
    );
  }
}

/// Consent checkbox and continue button at bottom
class _ConsentBottomBar extends StatelessWidget {
  final bool consentChecked;
  final ValueChanged<bool> onConsentChanged;
  final VoidCallback onContinue;

  const _ConsentBottomBar({
    required this.consentChecked,
    required this.onConsentChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.textSecondary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Consent checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: consentChecked,
                  onChanged: (value) => onConsentChanged(value ?? false),
                  activeColor: AppColors.primary,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onConsentChanged(!consentChecked),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(
                              text: 'I agree that my profile, including ',
                            ),
                            TextSpan(
                              text: 'sensitive details',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(
                              text: ', will be published on the app and used for matching.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: consentChecked ? onContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.textSecondary.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
