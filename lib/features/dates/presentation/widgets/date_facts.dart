import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_formats.dart';

/// Date facts display widget
///
/// Per UI-1: Icon + text rows from screenshot 2
/// - Calendar row (time range)
/// - Pin row (venue name, address on second line)
/// - Glass row (activityName)
///
/// Each row accepts null and hides itself
/// Time and venue rows are tappable when a handler is passed (UI-8 uses this for maps)
class DateFacts extends StatelessWidget {
  final DateTime? startTime;
  final DateTime? endTime;
  final String? venueName;
  final String? venueAddress;
  final String? activityName;
  final VoidCallback? onTimeTap;
  final VoidCallback? onVenueTap;

  const DateFacts({
    super.key,
    this.startTime,
    this.endTime,
    this.venueName,
    this.venueAddress,
    this.activityName,
    this.onTimeTap,
    this.onVenueTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Calendar row (time range)
        if (startTime != null)
          _DateFactRow(
            icon: Icons.calendar_today_outlined,
            text: endTime != null
                ? DateFormats.formatDateTimeRange(startTime!, endTime!)
                : DateFormats.formatDateTime(startTime!),
            onTap: onTimeTap,
          ),

        // Venue row (name + address)
        if (venueName != null)
          _DateFactRow(
            icon: Icons.location_on_outlined,
            text: venueName!,
            subtitle: venueAddress,
            onTap: onVenueTap,
          ),

        // Activity row (drinks, dinner, etc.)
        if (activityName != null)
          _DateFactRow(
            icon: Icons.local_bar_outlined,
            text: activityName!,
          ),
      ],
    );
  }
}

class _DateFactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subtitle;
  final VoidCallback? onTap;

  const _DateFactRow({
    required this.icon,
    required this.text,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTappable = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Icon(
              icon,
              size: 20,
              color: AppColors.primary,
            ),

            const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isTappable
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      decoration: isTappable
                          ? TextDecoration.underline
                          : TextDecoration.none,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Chevron for tappable rows
            if (isTappable)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
