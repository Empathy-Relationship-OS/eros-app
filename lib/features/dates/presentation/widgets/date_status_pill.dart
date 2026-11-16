import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';

/// Status pill for date state display
///
/// Per UI-1: Full-width rounded block with trailing info icon
/// Tones: action (tint, the viewer's move), waiting, success (green), neutral, muted (outline)
/// Can be made clickable to navigate directly to action screens
class DateStatusPill extends StatelessWidget {
  final String text;
  final String tone; // 'action', 'waiting', 'success', 'neutral', 'muted'
  final String? explanationText;
  final VoidCallback? onInfoTap;
  final bool isClickable;

  const DateStatusPill({
    super.key,
    required this.text,
    required this.tone,
    this.explanationText,
    this.onInfoTap,
    this.isClickable = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getToneColors(tone);

    // UI-12: Accessibility - announce status to screen readers
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colors.borderColor, width: 1.5),
        color: colors.backgroundColor,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              semanticsLabel: isClickable
                  ? 'Tap to $text'
                  : 'Date status: $text',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colors.textColor),
            ),
          ),
          // Show chevron for clickable pills, info icon for explanation
          if (isClickable)
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colors.iconColor,
            )
          else if (explanationText != null || onInfoTap != null)
            Semantics(
              label: 'More information',
              button: true,
              child: InkWell(
                onTap: onInfoTap ?? () => _showExplanation(context),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(12), // 44x44 touch target
                  child: Icon(
                    Icons.info_outline,
                    size: 20,
                    color: colors.iconColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showExplanation(BuildContext context) {
    if (explanationText == null) return;

    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(text, style: textTheme.headlineSmall),
            const SizedBox(height: 12),

            // Explanation
            Text(
              explanationText!,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // Close button
            AppButton(
              label: 'Got it',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  _PillColors _getToneColors(String tone) {
    switch (tone) {
      // Your move: the tint block, with ink text.
      case 'action':
        return const _PillColors(
          backgroundColor: AppColors.primaryTint,
          borderColor: AppColors.primaryTint,
          textColor: AppColors.textPrimary,
          iconColor: AppColors.primaryDeep,
        );

      case 'waiting':
        return const _PillColors(
          backgroundColor: AppColors.surfaceMuted,
          borderColor: AppColors.surfaceMuted,
          textColor: AppColors.textSecondary,
          iconColor: AppColors.textSecondary,
        );

      case 'success':
        return _PillColors(
          backgroundColor: AppColors.success.withValues(alpha: 0.1),
          borderColor: Colors.transparent,
          textColor: AppColors.success,
          iconColor: AppColors.success,
        );

      case 'muted':
        return const _PillColors(
          backgroundColor: Colors.transparent,
          borderColor: AppColors.divider,
          textColor: AppColors.textSecondary,
          iconColor: AppColors.textSecondary,
        );

      case 'neutral':
      default:
        return const _PillColors(
          backgroundColor: AppColors.surfaceMuted,
          borderColor: AppColors.surfaceMuted,
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
