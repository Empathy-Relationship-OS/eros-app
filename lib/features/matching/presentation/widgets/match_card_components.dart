import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/matching/domain/models/match_models.dart';

/// Reusable name and age display with bullet separator
/// Used consistently across match cards and profile views
class NameAndAgeDisplay extends StatelessWidget {
  final String name;
  final int age;
  final double fontSize;
  final FontWeight fontWeight;

  const NameAndAgeDisplay({
    super.key,
    required this.name,
    required this.age,
    this.fontSize = 28,
    this.fontWeight = FontWeight.w800,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: name),
          const TextSpan(
            text: ' • ',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.normal,
            ),
          ),
          TextSpan(text: '$age'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
    );
  }
}

/// Profile image section with gradient overlay
class ProfileImageSection extends StatelessWidget {
  final UserMatchProfile profile;

  const ProfileImageSection({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Profile photo or initial
        _buildProfileImage(context),

        // Shade at the bottom of a photo, so the card's edge reads against a pale picture
        if (profile.thumbnailUrl != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.ink.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileImage(BuildContext context) {
    if (profile.thumbnailUrl != null) {
      return Image.network(
        profile.thumbnailUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const ColoredBox(
            color: AppColors.surfaceMuted,
            child: Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildInitialFallback(context);
        },
      );
    }
    return _buildInitialFallback(context);
  }

  Widget _buildInitialFallback(BuildContext context) {
    return ColoredBox(
      color: AppColors.primaryTint,
      child: Center(
        child: Text(
          profile.name[0].toUpperCase(),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 80,
                color: AppColors.primaryDeep,
              ),
        ),
      ),
    );
  }
}

/// Profile info section with name and badges
class ProfileInfoSection extends StatelessWidget {
  final UserMatchProfile profile;

  const ProfileInfoSection({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final badges = profile.badges?.take(5).toList() ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: AppColors.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NameAndAgeDisplay(
            name: profile.name,
            age: profile.age,
          ),

          const SizedBox(height: 12),

          // Badges (matching traits)
          if (badges.isNotEmpty) MatchBadgeList(badges: badges),
        ],
      ),
    );
  }
}

/// List of match badges (shared traits)
class MatchBadgeList extends StatelessWidget {
  final List<String> badges;

  const MatchBadgeList({
    super.key,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges.map((badge) {
        return MatchBadge(label: badge);
      }).toList(),
    );
  }
}

/// Individual match badge chip
class MatchBadge extends StatelessWidget {
  final String label;

  const MatchBadge({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: 16,
            color: AppColors.primaryDeep,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
          ),
        ],
      ),
    );
  }
}

/// Action buttons for like/pass
class MatchActionButtons extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onPass;
  final VoidCallback onLike;

  const MatchActionButtons({
    super.key,
    required this.isProcessing,
    required this.onPass,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'Not for me',
            kind: AppButtonKind.secondary,
            loading: isProcessing,
            onPressed: onPass,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppButton(
            label: 'Go for a date',
            loading: isProcessing,
            onPressed: onLike,
          ),
        ),
      ],
    );
  }
}

/// Page indicator dots for carousel
class PageIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalCount;

  const PageIndicator({
    super.key,
    required this.currentIndex,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalCount,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == currentIndex ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == currentIndex ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );
  }
}

/// Single action button for "Go for a date"
/// Used in last 24 hours screen where only like action is available
class SingleActionButton extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onPressed;

  const SingleActionButton({
    super.key,
    required this.isProcessing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Go for a date',
      loading: isProcessing,
      onPressed: onPressed,
    );
  }
}

/// Mutual match dialog
///
/// Per UI-11: Shows match celebration and date planning CTA
class MutualMatchDialog extends StatelessWidget {
  final String partnerName;
  final int? dateId; // Optional: if null, just dismiss; if present, navigate to date
  final VoidCallback onContinue;

  const MutualMatchDialog({
    super.key,
    required this.partnerName,
    this.dateId,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite,
              color: AppColors.primary,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "It's a Match!",
            textAlign: TextAlign.center,
            style: textTheme.displayMedium,
          ),
          const SizedBox(height: 12),
          Text(
            "You and $partnerName liked each other!",
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          // Date planning message (UI-11)
          if (dateId != null) ...[
            const SizedBox(height: 8),
            Text(
              "Your date with $partnerName is ready to plan",
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 28),
          AppButton(
            label: dateId != null ? 'Plan the date' : 'Continue',
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}
