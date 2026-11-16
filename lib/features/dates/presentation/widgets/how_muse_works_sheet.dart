import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/widgets/app_button.dart';

/// "How Muse works": the steps from a match to a date, and what cancelling costs. Opened from the
/// Dates tab, whether or not there are dates on it.
class HowMuseWorksSheet extends StatelessWidget {
  final ScrollController? scrollController;

  const HowMuseWorksSheet({super.key, this.scrollController});

  static const String title = 'How Muse works';

  static const List<(String, String)> sections = [
    (
      'Pick the times you\'re both free',
      'Both of you pick times you\'re free over the next three weeks. We find the earliest one '
          'that works for you both. If nothing overlaps you each get one more go.',
    ),
    (
      'You both commit with a small token deposit',
      'A small token deposit from each of you keeps the date real. If either of you cancels '
          'after both have paid, the person cancelling loses their deposit and the other gets '
          'theirs back. Miss the deadline and everything is refunded.',
    ),
    (
      'Rank three venues, we book the spot',
      'We\'ve shortlisted venues near you both. Rank them and we\'ll book whichever you agree on '
          'most.',
    ),
    (
      'Confirm you\'re coming the day before',
      'The day before, we\'ll ask you both to confirm you\'re still coming. Final check before '
          'you meet.',
    ),
    (
      'Meet up and enjoy your date',
      'You\'re all set. Enjoy your date and get to know each other in person.',
    ),
    (
      'Cancellations',
      'Before both deposits are paid, anyone who paid gets a full refund. After both paid, the '
          'person cancelling loses their deposit and the other gets theirs back. Cancelling '
          'within 24 hours of the date is flagged as a late cancellation.',
    ),
  ];

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) =>
            HowMuseWorksSheet(scrollController: scrollController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.displaySmall),
          const SizedBox(height: 24),
          for (final (heading, body) in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(heading, style: textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          AppButton(
            label: 'Got it',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
