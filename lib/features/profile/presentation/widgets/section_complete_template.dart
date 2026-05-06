import 'package:flutter/material.dart';
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
      backgroundColor: Colors.white,
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
                      Icon(
                        headerIcon,
                        size: 100,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[600],
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
                            _buildProgressItem(item),
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
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(ProgressItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item.isComplete
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isComplete ? AppColors.primary : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            item.icon,
            color: item.isComplete ? AppColors.primary : Colors.grey[400],
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: item.isComplete ? AppColors.primary : Colors.black,
                  ),
                ),
                Text(
                  item.status,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (item.isComplete)
            const Icon(
              Icons.check,
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }
}
