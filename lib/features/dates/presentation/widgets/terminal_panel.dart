import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/time/server_clock_provider.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/safety/data/models/safety_models.dart';
import 'package:eros_app/features/safety/presentation/widgets/safety_copy.dart';

/// Terminal panel for completed, cancelled, and expired dates
///
/// Per UI-10: Shows different heading and body for each terminal state.
/// Per CH-F5: shows the held-deposit copy when [refundUnderReview], and a "Report" link for
/// 30 days after [finishedAt], by `ServerClock`.
class TerminalPanel extends ConsumerWidget {
  final DateState state;
  final VoidCallback? onBackToDates;

  /// When the date reached its terminal state (`DateDetail.updatedAt`).
  final DateTime? finishedAt;

  /// The viewer's deposit is held or under review. Replaces the body, and never says who
  /// reported whom, or why (D-10).
  final bool refundUnderReview;

  /// Opens the report sheet. The link shows only with [finishedAt], inside the report window.
  final VoidCallback? onReport;

  const TerminalPanel({
    super.key,
    required this.state,
    this.onBackToDates,
    this.finishedAt,
    this.refundUnderReview = false,
    this.onReport,
  });

  bool _canReport(DateTime now) {
    final finished = finishedAt;
    if (onReport == null || finished == null) return false;
    return now.isBefore(finished.add(SafetyLimits.reportWindow));
  }

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
  Widget build(BuildContext context, WidgetRef ref) {
    final content = _getContent();
    final body = refundUnderReview ? SafetyCopy.depositOnHold : content.body;
    final canReport = _canReport(ref.watch(serverClockProvider).now());

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

          if (body.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Body
            Text(
              body,
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

          if (canReport) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onReport,
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              child: const Text(SafetyCopy.report),
            ),
          ],

          // TODO(feedback): Add post-date feedback flow for completed state
          // This is out of MVP scope per UI-10 requirements
        ],
      ),
    );
  }
}
