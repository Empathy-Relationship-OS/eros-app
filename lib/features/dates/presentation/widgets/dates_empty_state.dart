import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';

/// Empty state for dates tab showing "What happens after you match?"
///
/// Per UI-2: Illustration area on top, heading, five-row explainer stepper,
/// and "How Muse works" button
class DatesEmptyState extends StatelessWidget {
  final VoidCallback? onHowItWorks;

  const DatesEmptyState({
    super.key,
    this.onHowItWorks,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // Illustration area
          _buildIllustration(),

          const SizedBox(height: 32),

          // Main card with explainer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Heading
                Text(
                  DatesCopy.emptyStateHeading,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 24),

                // Five-row explainer stepper (neutral, no statuses)
                _buildExplainerStepper(),

                const SizedBox(height: 24),

                // "How Muse works" button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onHowItWorks ?? () => _showHowItWorks(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DatesCopy.emptyStateButtonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    // Per UI-2: Use app's existing brand illustration assets if any;
    // otherwise a flat brand-colour panel. Do not copy Breeze's artwork.
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.primaryOrangeLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(
          Icons.favorite_outline,
          size: 80,
          color: AppColors.white,
        ),
      ),
    );
  }

  Widget _buildExplainerStepper() {
    return Column(
      children: [
        for (var i = 0; i < DatesCopy.emptyStateSteps.length; i++)
          _buildExplainerStep(
            step: i + 1,
            text: DatesCopy.emptyStateSteps[i],
            isLast: i == DatesCopy.emptyStateSteps.length - 1,
          ),
      ],
    );
  }

  Widget _buildExplainerStep({
    required int step,
    required String text,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left rail: icon + connector
          Column(
            children: [
              _buildStepIcon(step),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIcon(int step) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.background,
        border: Border.all(
          color: AppColors.textTertiary,
          width: 1,
        ),
      ),
      child: Center(
        child: _getStepIcon(step),
      ),
    );
  }

  Widget _getStepIcon(int step) {
    IconData iconData;
    switch (step) {
      case 1:
        iconData = Icons.calendar_today_outlined; // Pick times
        break;
      case 2:
        iconData = Icons.account_balance_wallet_outlined; // Commit deposit
        break;
      case 3:
        iconData = Icons.location_on_outlined; // Rank venues
        break;
      case 4:
        iconData = Icons.check_circle_outline; // Confirm presence
        break;
      case 5:
        iconData = Icons.favorite_outline; // Meet up
        break;
      default:
        iconData = Icons.circle_outlined;
    }

    return Icon(
      iconData,
      size: 18,
      color: AppColors.textTertiary,
    );
  }

  void _showHowItWorks(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'How Muse works',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Explainer paragraphs
              _buildExplainerParagraph(
                title: 'Pick the times you\'re both free',
                body:
                    'Both of you pick times you\'re free over the next three weeks. We find the earliest one that works for you both. If nothing overlaps you each get one more go.',
              ),

              _buildExplainerParagraph(
                title: 'You both commit with a small token deposit',
                body:
                    'A small token deposit from each of you keeps the date real. If either of you cancels after both have paid, the person cancelling loses their deposit and the other gets theirs back. Miss the deadline and everything is refunded.',
              ),

              _buildExplainerParagraph(
                title: 'Rank three venues, we book the spot',
                body:
                    'We\'ve shortlisted venues near you both. Rank them and we\'ll book whichever you agree on most.',
              ),

              _buildExplainerParagraph(
                title: 'Confirm you\'re coming the day before',
                body:
                    'The day before, we\'ll ask you both to confirm you\'re still coming. Final check before you meet.',
              ),

              _buildExplainerParagraph(
                title: 'Meet up and enjoy your date',
                body:
                    'You\'re all set. Enjoy your date and get to know each other in person.',
              ),

              _buildExplainerParagraph(
                title: 'Cancellations',
                body:
                    'Before both deposits are paid, anyone who paid gets a full refund. After both paid, the person cancelling loses their deposit and the other gets theirs back. Cancelling within 24 hours of the date is flagged as a late cancellation.',
              ),

              const SizedBox(height: 24),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplainerParagraph({
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
