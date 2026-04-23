import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/profile/domain/models/public_profile.dart';
import 'package:eros_app/features/profile/domain/models/photo_models.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_provider.dart';

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
    final List<_PhotoWithCaption> remainingPhotos;

    if (useLocal) {
      // Use local photos with captions
      thumbnailPath = localPhotos!.first.localPath;
      remainingPhotos = localPhotos!.length > 1
          ? localPhotos!.sublist(1).map((p) => _PhotoWithCaption(
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
          ? backendPhotos.sublist(1).map((p) => _PhotoWithCaption(
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
          _ThumbnailPhoto(
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
              _HorizontalInfoScroll(profile: profile),
              const SizedBox(height: 24),

              // 3. Work/Education/Location/Language rows
              _DetailedInfoSection(profile: profile),
            ],
          ),
        ),

        // 4. Ordered content: Hobbies -> QA1 -> Image -> QA2 -> Image -> Personality -> Image -> QA3 -> Image -> QAs
        _OrderedInterspersedContent(
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

/// Thumbnail photo widget (large at top)
class _ThumbnailPhoto extends StatelessWidget {
  final String photoPath;
  final bool isLocal;

  const _ThumbnailPhoto({
    required this.photoPath,
    required this.isLocal,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 500,
      width: double.infinity,
      child: isLocal
          ? Image.file(
              File(photoPath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.cardBackground,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            )
          : Image.network(
              photoPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.cardBackground,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: AppColors.cardBackground,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Horizontal scrollable info row for basic attributes
class _HorizontalInfoScroll extends StatelessWidget {
  final PublicProfileDTO profile;

  const _HorizontalInfoScroll({required this.profile});

  @override
  Widget build(BuildContext context) {
    final List<_InfoChipData> chips = [];

    // Gender (from basic info - we don't have this field, so skip for now)

    // Height (convert cm to feet and inches)
    final totalInches = (profile.height / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    chips.add(_InfoChipData(icon: Icons.height, label: '$feet\'$inches"'));

    // Sexual Orientation
    if (profile.profile.sexualOrientation != null &&
        profile.profile.sexualOrientation!.isNotEmpty) {
      chips.add(_InfoChipData(
        icon: Icons.favorite,
        label: profile.profile.sexualOrientation!,
      ));
    }

    // Star Sign
    if (profile.profile.starSign != null && profile.profile.starSign!.isNotEmpty) {
      chips.add(_InfoChipData(
        icon: Icons.stars,
        label: profile.profile.starSign!,
      ));
    }

    // Kids preference
    if (profile.profile.relationshipGoals.kidsPreference != null) {
      chips.add(_InfoChipData(
        icon: Icons.child_care,
        label: profile.profile.relationshipGoals.kidsPreference!,
      ));
    }

    // Drinking
    if (profile.profile.habits.alcoholConsumption != null) {
      chips.add(_InfoChipData(
        icon: Icons.local_bar,
        label: profile.profile.habits.alcoholConsumption!,
      ));
    }

    // Smoking
    if (profile.profile.habits.smokingStatus != null) {
      chips.add(_InfoChipData(
        icon: Icons.smoking_rooms,
        label: profile.profile.habits.smokingStatus!,
      ));
    }

    // Pronouns
    if (profile.profile.pronouns != null && profile.profile.pronouns!.isNotEmpty) {
      chips.add(_InfoChipData(
        icon: Icons.person,
        label: profile.profile.pronouns!,
      ));
    }

    return Container(
      height: 48,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(
            color: AppColors.divider,
            width: 1,
          ),
          bottom: BorderSide(
            color: AppColors.divider,
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < chips.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '|',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              _InfoChip(
                icon: chips[i].icon,
                label: chips[i].label,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChipData {
  final IconData icon;
  final String label;

  _InfoChipData({required this.icon, required this.label});
}

/// Individual info chip for horizontal scroll
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Detailed info section for work/education/location/languages
class _DetailedInfoSection extends StatelessWidget {
  final PublicProfileDTO profile;

  const _DetailedInfoSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Occupation
        if (profile.occupation != null && profile.occupation!.isNotEmpty)
          _InfoRow(
            icon: Icons.work,
            label: profile.occupation!,
          ),

        // Education
        _InfoRow(
          icon: Icons.school,
          label: profile.education,
        ),

        // Location
        _InfoRow(
          icon: Icons.location_on,
          label: profile.city,
        ),

        // Primary Language
        _InfoRow(
          icon: Icons.language,
          label: profile.language,
        ),

        // Spoken Languages
        if (profile.profile.spokenLanguages != null &&
            profile.profile.spokenLanguages!.isNotEmpty)
          _InfoRow(
            icon: Icons.translate,
            label: profile.profile.spokenLanguages!.join(', '),
          ),

        // Ethnicity
        if (profile.profile.ethnicity != null &&
            profile.profile.ethnicity!.isNotEmpty)
          _InfoRow(
            icon: Icons.public,
            label: profile.profile.ethnicity!.join(', '),
          ),

        // Religion
        if (profile.profile.religion != null && profile.profile.religion!.isNotEmpty)
          _InfoRow(
            icon: Icons.church,
            label: profile.profile.religion!,
          ),

        // Political View
        if (profile.profile.politicalView != null &&
            profile.profile.politicalView!.isNotEmpty)
          _InfoRow(
            icon: Icons.how_to_vote,
            label: profile.profile.politicalView!,
          ),
      ],
    );
  }
}

/// Q&A card widget with distinctive styling
class _QACard extends StatelessWidget {
  final PublicQAItemDTO qa;

  const _QACard({required this.qa});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          // Question as header
          Text(
            qa.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          // Answer in larger, distinctive font
          Text(
            qa.answer,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper class to hold photo path and caption
class _PhotoWithCaption {
  final String path;
  final String? caption;
  final bool isLocal;

  _PhotoWithCaption({
    required this.path,
    this.caption,
    required this.isLocal,
  });
}

/// Ordered interspersed content with specific placement
/// Order: Hobbies -> QA1 -> Image -> QA2 -> Image -> Personality -> Image -> QA3 -> Image -> QA4 -> Image -> Continue alternating
class _OrderedInterspersedContent extends StatelessWidget {
  final List<String> hobbies;
  final List<String> traits;
  final List<String>? brainAttribute;
  final String? brainDescription;
  final List<String>? bodyAttribute;
  final String? bodyDescription;
  final List<_PhotoWithCaption> photos;
  final List<PublicQAItemDTO> qas;

  const _OrderedInterspersedContent({
    required this.hobbies,
    required this.traits,
    this.brainAttribute,
    this.brainDescription,
    this.bodyAttribute,
    this.bodyDescription,
    required this.photos,
    required this.qas,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> orderedWidgets = [];
    int photoIndex = 0;
    int qaIndex = 0;

    // Helper to add photo
    void addPhoto() {
      if (photoIndex < photos.length) {
        final photo = photos[photoIndex];
        orderedWidgets.add(_StackedPhoto(
          photoPath: photo.path,
          isLocal: photo.isLocal,
          caption: photo.caption,
        ));
        orderedWidgets.add(const SizedBox(height: 24));
        photoIndex++;
      }
    }

    // Helper to add Q&A
    void addQA() {
      if (qaIndex < qas.length) {
        orderedWidgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _QACard(qa: qas[qaIndex]),
        ));
        orderedWidgets.add(const SizedBox(height: 24));
        qaIndex++;
      }
    }

    // 1. Hobbies/Interests section
    if (hobbies.isNotEmpty) {
      orderedWidgets.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
              _SectionHeader('Interests'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: hobbies.map((hobby) {
                  return _Chip(label: hobby);
                }).toList(),
              ),
            ],
          ),
        ),
      ));
      orderedWidgets.add(const SizedBox(height: 24));
    }

    // 2. QA1 (First Q&A)
    addQA();

    // 3. Image (Photo 2)
    addPhoto();

    // 4. QA2 (Second Q&A)
    addQA();

    // 5. Image (Photo 3)
    addPhoto();

    // 6. Personality/Traits section
    if (traits.isNotEmpty) {
      orderedWidgets.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
              _SectionHeader('Personality'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: traits.map((trait) {
                  return _Chip(label: trait);
                }).toList(),
              ),
            ],
          ),
        ),
      ));
      orderedWidgets.add(const SizedBox(height: 24));
    }

    // Brain attributes (if any)
    if (brainAttribute != null && brainAttribute!.isNotEmpty) {
      orderedWidgets.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
              _SectionHeader('Thinking Style'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: brainAttribute!.map((attr) {
                  return _Chip(label: attr);
                }).toList(),
              ),
              if (brainDescription != null && brainDescription!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  brainDescription!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ));
      orderedWidgets.add(const SizedBox(height: 24));
    }

    // Body attributes (if any)
    if (bodyAttribute != null && bodyAttribute!.isNotEmpty) {
      orderedWidgets.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
              _SectionHeader('Physical Activity'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: bodyAttribute!.map((attr) {
                  return _Chip(label: attr);
                }).toList(),
              ),
              if (bodyDescription != null && bodyDescription!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  bodyDescription!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ));
      orderedWidgets.add(const SizedBox(height: 24));
    }

    // 7. Image (Photo 4)
    addPhoto();

    // 8. QA3 (Third Q&A) - moved between Photo 4 and Photo 5
    addQA();

    // 9. Image (Photo 5)
    addPhoto();

    // 10. QA4 (Fourth Q&A)
    addQA();

    // 11. Image (Photo 6)
    addPhoto();

    // Continue alternating remaining photos and Q&As
    while (photoIndex < photos.length || qaIndex < qas.length) {
      addPhoto();
      addQA();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: orderedWidgets,
    );
  }
}

/// Stacked photo widget (for photos in vertical list)
class _StackedPhoto extends StatelessWidget {
  final String photoPath;
  final bool isLocal;
  final String? caption;

  const _StackedPhoto({
    required this.photoPath,
    required this.isLocal,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 400,
              width: double.infinity,
              child: isLocal
                  ? Image.file(
                      File(photoPath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.cardBackground,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    )
                  : Image.network(
                      photoPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.cardBackground,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: AppColors.cardBackground,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          if (caption != null && caption!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                caption!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
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
