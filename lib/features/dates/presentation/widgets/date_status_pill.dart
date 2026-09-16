import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// Status pill for date state display
///
/// Per UI-1: Full-width rounded outline with trailing info icon
/// Tones: action (orange), waiting (grey), success (green), neutral, muted
class DateStatusPill extends StatelessWidget {
  final String text;
  final String tone; // 'action', 'waiting', 'success', 'neutral', 'muted'
  final String? explanationText;
  final VoidCallback? onInfoTap;

  const DateStatusPill({
    super.key,
    required this.text,
    required this.tone,
    this.explanationText,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getToneColors(tone);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderColor, width: 1.5),
        color: colors.backgroundColor,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textColor,
              ),
            ),
          ),
          if (explanationText != null || onInfoTap != null)
            GestureDetector(
              onTap: onInfoTap ?? () => _showExplanation(context),
              child: Icon(
                Icons.info_outline,
                size: 20,
                color: colors.iconColor,
              ),
            ),
        ],
      ),
    );
  }

  void _showExplanation(BuildContext context) {
    if (explanationText == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Explanation
            Text(
              explanationText!,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _PillColors _getToneColors(String tone) {
    switch (tone) {
      case 'action':
        return _PillColors(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          borderColor: AppColors.primary,
          textColor: AppColors.primary,
          iconColor: AppColors.primary,
        );

      case 'waiting':
        return _PillColors(
          backgroundColor: AppColors.textTertiary.withOpacity(0.1),
          borderColor: AppColors.textSecondary,
          textColor: AppColors.textSecondary,
          iconColor: AppColors.textSecondary,
        );

      case 'success':
        return _PillColors(
          backgroundColor: AppColors.success.withOpacity(0.1),
          borderColor: AppColors.success,
          textColor: AppColors.success,
          iconColor: AppColors.success,
        );

      case 'neutral':
        return _PillColors(
          backgroundColor: AppColors.background,
          borderColor: AppColors.border,
          textColor: AppColors.textPrimary,
          iconColor: AppColors.textSecondary,
        );

      case 'muted':
        return _PillColors(
          backgroundColor: AppColors.background,
          borderColor: AppColors.divider,
          textColor: AppColors.textTertiary,
          iconColor: AppColors.textTertiary,
        );

      default:
        // Default to neutral
        return _PillColors(
          backgroundColor: AppColors.background,
          borderColor: AppColors.border,
          textColor: AppColors.textPrimary,
          iconColor: AppColors.textSecondary,
        );
    }
  }
}

class _PillColors {
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color iconColor;

  const _PillColors({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.iconColor,
  });
}
