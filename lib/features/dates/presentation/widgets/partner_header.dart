import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// Partner header widget with photo and name
///
/// Per UI-1: Partner photo as a hero (square with large radius, like screenshot 2)
/// Falls back to an initial-letter avatar when partnerThumbnailUrl is null
/// Has a slot for badges (e.g., verification badges)
class PartnerHeader extends StatelessWidget {
  final String partnerName;
  final String? partnerThumbnailUrl;
  final List<Widget>? badges;
  final double? heroSize;
  final VoidCallback? onTap;

  const PartnerHeader({
    super.key,
    required this.partnerName,
    this.partnerThumbnailUrl,
    this.badges,
    this.heroSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = heroSize ?? 120.0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // Partner photo
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.primaryOrangeLight,
            ),
            clipBehavior: Clip.antiAlias,
            child: partnerThumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: partnerThumbnailUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    errorWidget: (context, url, error) =>
                        _buildInitialAvatar(partnerName, size),
                  )
                : _buildInitialAvatar(partnerName, size),
          ),

          const SizedBox(height: 12),

          // Partner name with badges
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                partnerName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (badges != null && badges!.isNotEmpty) ...[
                const SizedBox(width: 6),
                ...badges!,
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitialAvatar(String name, double size) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      color: AppColors.primaryOrangeLight,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}
