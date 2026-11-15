import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';

/// Vertical timeline stepper for date progression
///
/// Shows 6 fixed steps in order: DATE_TYPE, AVAILABILITY, DEPOSIT, VENUE, CONFIRMATION, DATE
/// Each step has a status: COMPLETE, CURRENT, PENDING, or SKIPPED
///
/// Per UI-1: Left rail of circular icon chips connected by a thin line.
/// Status styling:
/// - COMPLETE: filled brand colour with tick overlay
/// - CURRENT: outlined brand colour with subtle pulse or bolder label
/// - PENDING: muted
/// - SKIPPED: muted and struck through label
class DateStepper extends StatelessWidget {
  final List<TimelineStepDto> timeline; // Always 6 steps, fixed order
  final bool compact; // If true, show horizontal icons-only variant

  const DateStepper({
    super.key,
    required this.timeline,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactStepper();
    } else {
      return _buildFullStepper(context);
    }
  }

  /// Full vertical stepper for detail screen
  Widget _buildFullStepper(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < timeline.length; i++)
          _buildStepRow(context, timeline[i], isLast: i == timeline.length - 1),
      ],
    );
  }

  /// Compact horizontal stepper for list cards
  Widget _buildCompactStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < timeline.length; i++) ...[
          _buildStepIcon(timeline[i], size: 24),
          if (i < timeline.length - 1)
            Container(
              width: 16,
              height: 1,
              color: _getRailColor(timeline[i].status),
            ),
        ],
      ],
    );
  }

  /// Build a single step row (full variant)
  Widget _buildStepRow(BuildContext context, TimelineStepDto step, {required bool isLast}) {
    final textTheme = Theme.of(context).textTheme;
    final isCurrent = step.status == StepStatus.current;
    final isStrikethrough = step.status == StepStatus.skipped;

    // UI-12: Accessibility - semantic label for screen readers
    final stepIndex = timeline.indexOf(step) + 1;
    final semanticLabel = 'step $stepIndex of ${timeline.length}, ${step.label}, ${_statusToSemanticString(step.status)}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left rail: icon + connector
          Column(
            children: [
              _buildStepIcon(step, size: 40),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: _getRailColor(step.status),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 12),

          // Label and detail. A step with another below it is tall enough for the rail to show.
          Expanded(
            child: Container(
              constraints: BoxConstraints(minHeight: isLast ? 0 : 60),
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step label
                  Text(
                    step.label,
                    semanticsLabel: semanticLabel,
                    style: (isCurrent ? textTheme.titleMedium : textTheme.bodyMedium)?.copyWith(
                      color: isStrikethrough ? AppColors.textTertiary : AppColors.textPrimary,
                      decoration:
                          isStrikethrough ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                  ),

                  // Deposit detail (if applicable)
                  if (step.step == TimelineStep.deposit &&
                      (step.you != null || step.partner != null))
                    _buildDepositDetail(context, step),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build deposit status detail row
  Widget _buildDepositDetail(BuildContext context, TimelineStepDto step) {
    final style = Theme.of(context).textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step.you != null)
            Text(
              'You: ${_depositStatusText(step.you!)}',
              style: style,
            ),
          if (step.partner != null)
            Text(
              'Partner: ${_depositStatusText(step.partner!)}',
              style: style,
            ),
        ],
      ),
    );
  }

  String _depositStatusText(ParticipantDepositStatus status) {
    switch (status) {
      case ParticipantDepositStatus.paid:
        return 'paid';
      case ParticipantDepositStatus.pending:
        return 'pending';
      case ParticipantDepositStatus.notApplicable:
        return 'n/a';
    }
  }

  /// Build step icon
  Widget _buildStepIcon(TimelineStepDto step, {required double size}) {
    final color = _getStepColor(step.status);
    final icon = _getStepIcon(step.step);
    final isComplete = step.status == StepStatus.complete;
    final isCurrent = step.status == StepStatus.current;

    // Done is filled, the current step is a tint circle with a deep coral ring, the rest are
    // quiet outlines.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isComplete
            ? color
            : isCurrent
                ? AppColors.primaryTint
                : Colors.transparent,
        border: Border.all(
          color: isComplete || isCurrent ? color : AppColors.border,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Icon(
        isComplete ? Icons.check : icon,
        size: size * 0.55,
        color: isComplete ? AppColors.white : color,
      ),
    );
  }

  /// Get color for step status
  Color _getStepColor(StepStatus status) {
    switch (status) {
      case StepStatus.complete:
      case StepStatus.current:
        return AppColors.primaryDeep;
      case StepStatus.pending:
      case StepStatus.skipped:
        return AppColors.textTertiary;
    }
  }

  /// The line below a step: coral once the step is done.
  Color _getRailColor(StepStatus status) =>
      status == StepStatus.complete ? AppColors.primaryOrangeLight : AppColors.divider;

  /// UI-12: Convert status to screen reader-friendly string
  String _statusToSemanticString(StepStatus status) {
    switch (status) {
      case StepStatus.complete:
        return 'complete';
      case StepStatus.current:
        return 'current';
      case StepStatus.pending:
        return 'pending';
      case StepStatus.skipped:
        return 'skipped';
    }
  }

  /// Get icon for timeline step
  IconData _getStepIcon(TimelineStep step) {
    switch (step) {
      case TimelineStep.dateType:
        return Icons.local_bar_outlined; // Glass
      case TimelineStep.availability:
        return Icons.calendar_today_outlined; // Calendar
      case TimelineStep.deposit:
        return Icons.account_balance_wallet_outlined; // Card/coin
      case TimelineStep.venue:
        return Icons.location_on_outlined; // Map pin
      case TimelineStep.confirmation:
        return Icons.check_circle_outline; // Tick
      case TimelineStep.date:
        return Icons.favorite_outline; // Heart
    }
  }
}
