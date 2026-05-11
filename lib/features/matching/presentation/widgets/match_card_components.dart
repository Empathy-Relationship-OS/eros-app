import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/matching/domain/models/match_models.dart';

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
        _buildProfileImage(),

        // Gradient overlay at bottom for better text readability
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
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage() {
    if (profile.thumbnailUrl != null) {
      return Image.network(
        profile.thumbnailUrl!,
        fit: BoxFit.cover,
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
        errorBuilder: (context, error, stackTrace) {
          return _buildInitialFallback();
        },
      );
    }
    return _buildInitialFallback();
  }

  Widget _buildInitialFallback() {
    return Container(
      color: AppColors.cardBackground,
      child: Center(
        child: Text(
          profile.name[0].toUpperCase(),
          style: const TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
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
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name with online indicator dot
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ],
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
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
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
        // "Not for me" button
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: isProcessing ? null : onPass,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardBackground,
                foregroundColor: AppColors.textPrimary,
                disabledBackgroundColor:
                    AppColors.textSecondary.withValues(alpha: 0.3),
                side: BorderSide(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : const Text(
                      'Not for me',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // "Go for a date" button
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: isProcessing ? null : onLike,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.textSecondary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 2,
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Go for a date',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
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
            color: index == currentIndex
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// Mutual match dialog
class MutualMatchDialog extends StatelessWidget {
  final String partnerName;
  final VoidCallback onContinue;

  const MutualMatchDialog({
    super.key,
    required this.partnerName,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.favorite,
            color: AppColors.primary,
            size: 80,
          ),
          const SizedBox(height: 24),
          const Text(
            "It's a Match!",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "You and $partnerName liked each other!",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
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
          ),
        ],
      ),
    );
  }
}
