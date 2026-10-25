import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// One slot of a 2-column photo grid: the onboarding photo screen and the photo editor
/// (RFC-004 §6.3).
///
/// With [image] it shows the photo, with a badge saying [primaryLabel] when [isPrimary] and a
/// remove button when [onRemove] is set. Without it, it shows an "add" placeholder numbered
/// [index] + 1. [overlays] are drawn on top (they are `Stack` children, so position them).
class PhotoSlotTile extends StatelessWidget {
  final int index;

  /// The photo, filling the tile. Null for an empty slot.
  final Widget? image;
  final bool isPrimary;
  final String primaryLabel;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final List<Widget> overlays;

  /// The slot's fill, seen when it is empty or the photo is loading. Defaults to
  /// [AppColors.cardBackground], which suits onboarding's cream background.
  final Color? backgroundColor;

  const PhotoSlotTile({
    super.key,
    required this.index,
    required this.image,
    required this.isPrimary,
    required this.onTap,
    this.primaryLabel = 'Primary',
    this.onRemove,
    this.overlays = const [],
    this.backgroundColor,
  });

  bool get _hasPhoto => image != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: isPrimary
                  ? Border.all(color: AppColors.primary, width: 2)
                  : null,
            ),
            child: _hasPhoto
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: image,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isPrimary ? 'Profile\nPicture' : 'Add\nPhoto',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                            fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // Primary badge
          if (isPrimary && _hasPhoto)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  primaryLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // Remove button
          if (_hasPhoto && onRemove != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),

          // Photo number indicator
          if (!_hasPhoto)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),

          ...overlays,
        ],
      ),
    );
  }
}
