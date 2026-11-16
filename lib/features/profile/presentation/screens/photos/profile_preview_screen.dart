import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/widgets/app_button.dart';
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
      appBar: AppBar(title: const Text('Preview your profile')),
      body: FutureBuilder<PublicProfileDTO>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (profileSnapshot.hasError) {
            final errorMessage = profileSnapshot.error.toString().contains('sign in')
                ? 'Please sign in to preview your profile'
                : 'Unable to load profile preview';

            return ProfileLoadError(
              message: errorMessage,
              detail: profileSnapshot.error.toString(),
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
  final List<PhotoUploadDraft>? localPhotos; // Photos picked during onboarding, not yet uploaded

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
    final List<ProfilePhoto> remainingPhotos;

    if (useLocal) {
      // Use local photos
      thumbnailPath = localPhotos!.first.localPath;
      remainingPhotos = localPhotos!.length > 1
          ? localPhotos!.sublist(1).map((p) => ProfilePhoto(
                path: p.localPath,
                isLocal: true,
              )).toList()
          : [];
    } else {
      // Use backend photos
      final backendPhotos = profile.profile.photos;
      thumbnailPath = backendPhotos.isNotEmpty ? backendPhotos.first : null;
      remainingPhotos = backendPhotos.length > 1
          ? backendPhotos.sublist(1).map((p) => ProfilePhoto(
                path: p,
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

        // 2. Name, bio, basics and details
        ProfileHeaderCard(profile: profile),

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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: AppColors.divider)),
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
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onConsentChanged(!consentChecked),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text.rich(
                        const TextSpan(
                          children: [
                            TextSpan(text: 'I agree that my profile, including '),
                            TextSpan(
                              text: 'sensitive details',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(
                              text: ', will be published on the app and used for matching.',
                            ),
                          ],
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Continue button
            AppButton(
              label: 'Continue',
              trailingIcon: Icons.arrow_forward,
              onPressed: consentChecked ? onContinue : null,
            ),
          ],
        ),
      ),
    );
  }
}
