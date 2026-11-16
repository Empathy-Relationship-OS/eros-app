import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:eros_app/features/dates/presentation/widgets/how_muse_works_sheet.dart';

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
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heading
                  Text(
                    DatesCopy.emptyStateHeading,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),

                  const SizedBox(height: 24),

                  // Five-row explainer stepper (neutral, no statuses)
                  _buildExplainerStepper(context),

                  const SizedBox(height: 24),

                  // "How Muse works" button
                  AppButton(
                    label: DatesCopy.emptyStateButtonText,
                    trailingIcon: Icons.arrow_forward,
                    onPressed: onHowItWorks ?? () => HowMuseWorksSheet.show(context),
                  ),
                ],
              ),
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
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: const Center(
        child: Icon(
          Icons.favorite_outline,
          size: 80,
          color: AppColors.primaryDeep,
        ),
      ),
    );
  }

  Widget _buildExplainerStepper(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < DatesCopy.emptyStateSteps.length; i++)
          _buildExplainerStep(
            context,
            step: i + 1,
            text: DatesCopy.emptyStateSteps[i],
            isLast: i == DatesCopy.emptyStateSteps.length - 1,
          ),
      ],
    );
  }

  Widget _buildExplainerStep(
    BuildContext context, {
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
                    color: AppColors.divider,
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
                style: Theme.of(context).textTheme.bodyMedium,
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
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryTint,
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
      color: AppColors.primaryDeep,
    );
  }
}
