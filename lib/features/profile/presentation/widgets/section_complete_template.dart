import 'package:flutter/material.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// Progress item data model
class ProgressItem {
  final IconData icon;
  final String title;
  final String status;
  final bool isComplete;

  const ProgressItem({
    required this.icon,
    required this.title,
    required this.status,
    required this.isComplete,
  });
}

/// Reusable template for section completion screens
/// Used by basic_info_complete_screen and preferences_complete_screen
class SectionCompleteTemplate extends StatelessWidget {
  final IconData headerIcon;
  final String title;
  final String description;
  final List<ProgressItem> progressItems;
  final String buttonText;
  final VoidCallback onContinue;

  const SectionCompleteTemplate({
    super.key,
    required this.headerIcon,
    required this.title,
    required this.description,
    required this.progressItems,
    required this.buttonText,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryTint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(headerIcon, size: 56, color: AppColors.primaryDeep),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.displayMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      // Progress items
                      ...progressItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Column(
                          children: [
                            if (index > 0) const SizedBox(height: 16),
                            _buildProgressItem(context, item),
                          ],
                        );
                      }),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: AppButton(label: buttonText, onPressed: onContinue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(BuildContext context, ProgressItem item) {
    final textTheme = Theme.of(context).textTheme;

    // Done is a tint block; still to do is a quiet outlined one
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item.isComplete ? AppColors.primaryTint : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(
          color: item.isComplete ? AppColors.primaryTint : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            item.icon,
            color: item.isComplete ? AppColors.primaryDeep : AppColors.textTertiary,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: textTheme.titleMedium),
                Text(
                  item.status,
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (item.isComplete)
            const Icon(Icons.check_circle, color: AppColors.primaryDeep),
        ],
      ),
    );
  }
}
