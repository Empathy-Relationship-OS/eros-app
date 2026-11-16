import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';

/// A nudge at the top of a tab: one line (and an optional second) on a tint block. Tapping it
/// opens something; the close button dismisses it.
class AppPromptCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final String dismissTooltip;

  const AppPromptCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    required this.onDismiss,
    required this.dismissTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.primaryTint,
      borderRadius: BorderRadius.circular(AppRadius.input),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(
            children: [
              ExcludeSemantics(child: Icon(icon, color: AppColors.primaryDeep)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: textTheme.titleSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                tooltip: dismissTooltip,
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
