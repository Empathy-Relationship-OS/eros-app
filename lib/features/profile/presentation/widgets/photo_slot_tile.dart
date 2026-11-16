import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_radius.dart';
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
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(
                color: isPrimary ? AppColors.primaryDeep : AppColors.border,
                width: isPrimary ? 2 : 1,
              ),
            ),
            child: _hasPhoto
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.input - 2),
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
                          size: 40,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isPrimary ? 'Profile\nPicture' : 'Add\nPhoto',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w400,
                                height: 1.3,
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
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  primaryLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textOnPrimary,
                        fontWeight: FontWeight.w700,
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
                    color: AppColors.ink.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.white,
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
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: Theme.of(context).textTheme.labelMedium,
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
