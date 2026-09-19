import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';

/// Terminal panel for completed, cancelled, and expired dates
///
/// Per UI-10: Shows different heading and body for each terminal state
class TerminalPanel extends StatelessWidget {
  final DateState state;
  final VoidCallback? onBackToDates;

  const TerminalPanel({
    super.key,
    required this.state,
    this.onBackToDates,
  });

  ({String heading, String body, bool showButton}) _getContent() {
    switch (state) {
      case DateState.completed:
        return (
          heading: 'You met!',
          body: 'Hope it went well.',
          showButton: true,
        );

      case DateState.cancelled:
        return (
          heading: 'This date was cancelled',
          body:
              'If you had a deposit in play, check your wallet for any refund.',
          showButton: false,
        );

      case DateState.expired:
        return (
          heading: 'This date ran out of time',
          body:
              'It can happen when times don\'t overlap, a deadline passes, or no venue was free. Any deposit has been refunded.',
          showButton: true,
        );

      default:
        return (
          heading: 'Date ended',
          body: '',
          showButton: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _getContent();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Heading
          Text(
            content.heading,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          if (content.body.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Body
            Text(
              content.body,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          // Back to dates button (for completed and expired)
          if (content.showButton && onBackToDates != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onBackToDates,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Back to dates',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          // TODO(feedback): Add post-date feedback flow for completed state
          // This is out of MVP scope per UI-10 requirements
        ],
      ),
    );
  }
}
