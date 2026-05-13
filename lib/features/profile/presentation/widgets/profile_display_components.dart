import 'dart:io';
import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/domain/models/public_profile.dart';

/// Reusable components for displaying public profiles
/// Extracted from profile_preview_screen.dart for use across the app

/// Thumbnail photo widget (large at top)
class ThumbnailPhoto extends StatelessWidget {
  final String photoPath;
  final bool isLocal;

  const ThumbnailPhoto({
    super.key,
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
class HorizontalInfoScroll extends StatelessWidget {
  final PublicProfileDTO profile;

  const HorizontalInfoScroll({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final List<_InfoChipData> chips = [];

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
            for (int i = 0; i < chips.length; i++) ...{
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
              InfoChip(
                icon: chips[i].icon,
                label: chips[i].label,
              ),
            },
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
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const InfoChip({
    super.key,
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
class DetailedInfoSection extends StatelessWidget {
  final PublicProfileDTO profile;

  const DetailedInfoSection({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Occupation
        if (profile.occupation != null && profile.occupation!.isNotEmpty)
          InfoRow(
            icon: Icons.work,
            label: profile.occupation!,
          ),

        // Education
        InfoRow(
          icon: Icons.school,
          label: profile.education,
        ),

        // Location
        InfoRow(
          icon: Icons.location_on,
          label: profile.city,
        ),

        // Primary Language
        InfoRow(
          icon: Icons.language,
          label: profile.language,
        ),

        // Spoken Languages
        if (profile.profile.spokenLanguages != null &&
            profile.profile.spokenLanguages!.isNotEmpty)
          InfoRow(
            icon: Icons.translate,
            label: profile.profile.spokenLanguages!.join(', '),
          ),

        // Ethnicity
        if (profile.profile.ethnicity != null &&
            profile.profile.ethnicity!.isNotEmpty)
          InfoRow(
            icon: Icons.public,
            label: profile.profile.ethnicity!.join(', '),
          ),

        // Religion
        if (profile.profile.religion != null && profile.profile.religion!.isNotEmpty)
          InfoRow(
            icon: Icons.church,
            label: profile.profile.religion!,
          ),

        // Political View
        if (profile.profile.politicalView != null &&
            profile.profile.politicalView!.isNotEmpty)
          InfoRow(
            icon: Icons.how_to_vote,
            label: profile.profile.politicalView!,
          ),
      ],
    );
  }
}

/// Q&A card widget with distinctive styling
class QACard extends StatelessWidget {
  final PublicQAItemDTO qa;

  const QACard({super.key, required this.qa});

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
class PhotoWithCaption {
  final String path;
  final String? caption;
  final bool isLocal;

  PhotoWithCaption({
    required this.path,
    this.caption,
    required this.isLocal,
  });
}

/// Ordered interspersed content with specific placement
class OrderedInterspersedContent extends StatelessWidget {
  final List<String> hobbies;
  final List<String> traits;
  final List<String>? brainAttribute;
  final String? brainDescription;
  final List<String>? bodyAttribute;
  final String? bodyDescription;
  final List<PhotoWithCaption> photos;
  final List<PublicQAItemDTO> qas;

  const OrderedInterspersedContent({
    super.key,
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
        orderedWidgets.add(StackedPhoto(
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
          child: QACard(qa: qas[qaIndex]),
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
              const SectionHeader('Interests'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: hobbies.map((hobby) {
                  return ProfileChip(label: hobby);
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
              const SectionHeader('Personality'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: traits.map((trait) {
                  return ProfileChip(label: trait);
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
              const SectionHeader('Thinking Style'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: brainAttribute!.map((attr) {
                  return ProfileChip(label: attr);
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
              const SectionHeader('Physical Activity'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: bodyAttribute!.map((attr) {
                  return ProfileChip(label: attr);
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

    // 8. QA3 (Third Q&A)
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
class StackedPhoto extends StatelessWidget {
  final String photoPath;
  final bool isLocal;
  final String? caption;

  const StackedPhoto({
    super.key,
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
          if (caption != null && caption!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                caption!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ClipRRect(
            borderRadius: caption != null && caption!.isNotEmpty
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  )
                : BorderRadius.circular(12),
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
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader(this.title, {super.key});

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

class ProfileChip extends StatelessWidget {
  final String label;

  const ProfileChip({super.key, required this.label});

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

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const InfoRow({
    super.key,
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
