import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// Empty state shown by a dev menu tab until its panel is built.
class DevTabPlaceholder extends StatelessWidget {
  final String title;
  final String description;
  final String ticket;

  const DevTabPlaceholder({
    super.key,
    required this.title,
    required this.description,
    required this.ticket,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(title, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              description,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Coming in $ticket.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
