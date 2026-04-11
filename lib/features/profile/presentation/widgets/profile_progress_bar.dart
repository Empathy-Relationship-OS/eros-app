import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// Reusable progress bar widget for profile creation flow
///
/// Displays a linear progress indicator with step count and percentage.
/// Can be customized with different section labels (e.g., "Step", "Preferences").
class ProfileProgressBar extends StatelessWidget {
  /// Current step number (1-indexed)
  final int currentStep;

  /// Total number of steps in this section
  final int totalSteps;

  /// Optional label for the section (e.g., "Preferences", "Step")
  /// Defaults to "Step" if not provided
  final String? sectionLabel;

  const ProfileProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.sectionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final label = sectionLabel ?? 'Step';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$label $currentStep of $totalSteps',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${((currentStep / totalSteps) * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: currentStep / totalSteps,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
