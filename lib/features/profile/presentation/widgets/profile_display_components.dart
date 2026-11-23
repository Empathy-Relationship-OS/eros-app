import 'dart:io';
import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/matching/presentation/widgets/match_card_components.dart';
import 'package:eros_app/features/profile/domain/models/public_profile.dart';

/// Reusable components for displaying public profiles
/// Extracted from profile_preview_screen.dart for use across the app

/// A photo on a profile, from a local file or the network, with the same placeholder while it
/// loads and when it can't be shown.
class _ProfileImage extends StatelessWidget {
  final String path;
  final bool isLocal;
  final double placeholderIconSize;

  const _ProfileImage({
    required this.path,
    required this.isLocal,
    required this.placeholderIconSize,
  });

  @override
  Widget build(BuildContext context) {
    Widget unavailable(BuildContext context, Object error, StackTrace? stackTrace) {
      return ColoredBox(
        color: AppColors.surfaceMuted,
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: placeholderIconSize,
            color: AppColors.textTertiary,
          ),
        ),
      );
    }

    if (isLocal) {
      return Image.file(File(path), fit: BoxFit.cover, errorBuilder: unavailable);
    }
    return Image.network(
      path,
      fit: BoxFit.cover,
      errorBuilder: unavailable,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const ColoredBox(
          color: AppColors.surfaceMuted,
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

/// Thumbnail photo widget (large at top)
class ThumbnailPhoto extends StatelessWidget {
  final String photoPath;
  final bool isLocal;

  /// Someone else's profile: a long-press offers "Report this photo" (CF-F4).
  final VoidCallback? onLongPress;

  const ThumbnailPhoto({
    super.key,
    required this.photoPath,
    required this.isLocal,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return _LongPressable(
      onLongPress: onLongPress,
      child: SizedBox(
        height: 500,
        width: double.infinity,
        child: _ProfileImage(path: photoPath, isLocal: isLocal, placeholderIconSize: 64),
      ),
    );
  }
}

/// A photo that offers its actions on a long-press, or just the photo without [onLongPress].
class _LongPressable extends StatelessWidget {
  final VoidCallback? onLongPress;
  final Widget child;

  const _LongPressable({required this.onLongPress, required this.child});

  @override
  Widget build(BuildContext context) {
    if (onLongPress == null) return child;
    return Semantics(
      onLongPressHint: 'Report this photo',
      child: GestureDetector(onLongPress: onLongPress, child: child),
    );
  }
}

/// A section of a profile: a flat white card with a hairline, like every other card in the app.
class ProfileCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ProfileCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

/// The card under the first photo: name and age, the bio, the row of basics and the details.
class ProfileHeaderCard extends StatelessWidget {
  final PublicProfileDTO profile;

  const ProfileHeaderCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final bio = profile.profile.bio;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ProfileCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NameAndAgeDisplay(name: profile.name, age: profile.age, fontSize: 30),
            const SizedBox(height: 12),
            if (bio != null && bio.isNotEmpty) ...[
              Text(bio, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 20),
            ],
            HorizontalInfoScroll(profile: profile),
            const SizedBox(height: 12),
            DetailedInfoSection(profile: profile),
          ],
        ),
      ),
    );
  }
}

/// Shown in place of a profile that couldn't be loaded, with the way back.
class ProfileLoadError extends StatelessWidget {
  final String message;
  final String? detail;

  const ProfileLoadError({super.key, required this.message, this.detail});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(message, style: textTheme.headlineSmall, textAlign: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: 'Go Back',
              kind: AppButtonKind.outline,
              expand: false,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
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
        border: Border(
          top: BorderSide(color: AppColors.divider),
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < chips.length; i++) ...{
              if (i > 0)
                Container(
                  width: 1,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: AppColors.border,
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
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500, height: 1.2),
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
    final textTheme = Theme.of(context).textTheme;

    return ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question as header
          Text(
            qa.question,
            style: textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          // Answer in larger, distinctive font
          Text(
            qa.answer,
            style: textTheme.headlineMedium?.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// A photo to show on a profile: a local file path or a network URL.
class ProfilePhoto {
  final String path;
  final bool isLocal;

  /// Someone else's profile: a long-press offers "Report this photo" (CF-F4).
  final VoidCallback? onLongPress;

  ProfilePhoto({
    required this.path,
    required this.isLocal,
    this.onLongPress,
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
  final List<ProfilePhoto> photos;
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
          onLongPress: photo.onLongPress,
        ));
        orderedWidgets.add(const SizedBox(height: 16));
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
        orderedWidgets.add(const SizedBox(height: 16));
        qaIndex++;
      }
    }

    // A titled card of chips, with an optional line under them
    void addChips(String title, List<String>? labels, {String? description}) {
      if (labels == null || labels.isEmpty) return;
      orderedWidgets.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: _ChipSection(title: title, labels: labels, description: description),
      ));
      orderedWidgets.add(const SizedBox(height: 16));
    }

    // 1. Hobbies/Interests section
    addChips('Interests', hobbies);

    // 2. QA1 (First Q&A)
    addQA();

    // 3. Image (Photo 2)
    addPhoto();

    // 4. QA2 (Second Q&A)
    addQA();

    // 5. Image (Photo 3)
    addPhoto();

    // 6. Personality/Traits section
    addChips('Personality', traits);

    // Brain attributes (if any)
    addChips('Thinking Style', brainAttribute, description: brainDescription);

    // Body attributes (if any)
    addChips('Physical Activity', bodyAttribute, description: bodyDescription);

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

/// A titled card of chips ("Interests", "Personality"), with an optional line under them.
class _ChipSection extends StatelessWidget {
  final String title;
  final List<String> labels;
  final String? description;

  const _ChipSection({required this.title, required this.labels, this.description});

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final label in labels) ProfileChip(label: label)],
          ),
          if (description != null && description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Stacked photo widget (for photos in vertical list)
class StackedPhoto extends StatelessWidget {
  final String photoPath;
  final bool isLocal;

  /// Someone else's profile: a long-press offers "Report this photo" (CF-F4).
  final VoidCallback? onLongPress;

  const StackedPhoto({
    super.key,
    required this.photoPath,
    required this.isLocal,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: _LongPressable(
        onLongPress: onLongPress,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: SizedBox(
            height: 400,
            width: double.infinity,
            child: _ProfileImage(path: photoPath, isLocal: isLocal, placeholderIconSize: 48),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.headlineSmall);
  }
}

class ProfileChip extends StatelessWidget {
  final String label;

  const ProfileChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontSize: 13, fontWeight: FontWeight.w500, height: 1.3),
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
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.3)),
          ),
        ],
      ),
    );
  }
}
