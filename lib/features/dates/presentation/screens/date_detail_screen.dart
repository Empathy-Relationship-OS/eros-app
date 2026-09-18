import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/date_detail_provider.dart';
import 'package:eros_app/features/dates/presentation/widgets/partner_header.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_facts.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_status_pill.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_stepper.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:eros_app/features/dates/presentation/widgets/deadline_countdown.dart';
import 'package:eros_app/features/dates/presentation/widgets/token_amount.dart';

/// Date detail screen showing full date info, stepper, and CTA panel
///
/// Per UI-4: Partner header, facts, status pill, stepper, and state-based CTA
class DateDetailScreen extends ConsumerStatefulWidget {
  final String dateId;

  const DateDetailScreen({
    super.key,
    required this.dateId,
  });

  @override
  ConsumerState<DateDetailScreen> createState() => _DateDetailScreenState();
}

class _DateDetailScreenState extends ConsumerState<DateDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(dateDetailProvider(widget.dateId));
    final authService = ref.watch(authServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _buildBody(context, detailState, authService),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DateDetailState state,
    AuthService authService,
  ) {
    // Loading state
    if (state.isLoading && state.dateDetail == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Error state
    if (state.hasError && state.dateDetail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load date',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                state.errorMessage ?? 'Unknown error',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref.read(dateDetailProvider(widget.dateId).notifier).refresh();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Date detail loaded
    final dateDetail = state.dateDetail;
    if (dateDetail == null) {
      return const SizedBox.shrink();
    }

    final currentUid = authService.currentUser?.uid ?? '';

    return Stack(
      children: [
        // Main content
        CustomScrollView(
          slivers: [
            // Partner header
            SliverToBoxAdapter(
              child: _buildHeader(context, dateDetail, currentUid),
            ),

            // Date facts
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: DateFacts(
                  startTime: dateDetail.scheduledStart,
                  endTime: dateDetail.scheduledEnd,
                  venueName: dateDetail.venueName,
                  venueAddress: dateDetail.venueAddress,
                  activityName: dateDetail.activityName,
                ),
              ),
            ),

            // Status pill
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildStatusPill(dateDetail, currentUid),
              ),
            ),

            // Stepper
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: _buildStepper(dateDetail, currentUid),
              ),
            ),

            // Spacer for CTA panel
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),

        // CTA panel pinned to bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildCTAPanel(context, dateDetail, currentUid),
        ),

        // Back button overlay
        Positioned(
          top: 16,
          left: 16,
          child: CircleAvatar(
            backgroundColor: AppColors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),

        // Overflow menu overlay
        if (_shouldShowOverflowMenu(dateDetail))
          Positioned(
            top: 16,
            right: 16,
            child: CircleAvatar(
              backgroundColor: AppColors.white,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                onSelected: (value) {
                  if (value == 'cancel') {
                    _showCancelDialog(context, dateDetail, currentUid);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancel date'),
                  ),
                  // TODO: Add "Report a problem" if support route exists
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, DateDetail dateDetail, String currentUid) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: PartnerHeader(
        partnerName: dateDetail.partnerName(currentUid),
        partnerThumbnailUrl: dateDetail.partnerThumbnailUrl,
        // TODO: Add verification badges if available
      ),
    );
  }

  Widget _buildStatusPill(DateDetail dateDetail, String currentUid) {
    final (pillText, tone) = DatesCopy.statusPill(
      state: dateDetail.state,
      partnerName: dateDetail.partnerName(currentUid),
      tokenCost: TokenAmount.formatTokenAmount(dateDetail.tokenCost),
      youSubmitted: _hasUserSubmitted(dateDetail, currentUid),
      youPaid: _hasUserPaid(dateDetail, currentUid),
      youRanked: dateDetail.myRankings.isNotEmpty,
      youConfirmed: _hasUserConfirmed(dateDetail, currentUid),
    );

    return DateStatusPill(
      text: pillText,
      tone: tone,
      onInfoTap: () => _showStatusExplanation(context, dateDetail.state),
    );
  }

  Widget _buildStepper(DateDetail dateDetail, String currentUid) {
    return DateStepper(
      timeline: dateDetail.timeline,
      compact: false,
    );
  }

  Widget _buildCTAPanel(BuildContext context, DateDetail dateDetail, String currentUid) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _buildCTAContent(context, dateDetail, currentUid),
    );
  }

  Widget _buildCTAContent(BuildContext context, DateDetail dateDetail, String currentUid) {
    switch (dateDetail.state) {
      case DateState.awaitingAvailability:
        return _buildAvailabilityCTA(context, dateDetail);

      case DateState.awaitingDeposit:
        return _buildDepositCTA(context, dateDetail, currentUid);

      case DateState.awaitingVenueRanking:
        return _buildVenueRankingCTA(context, dateDetail);

      case DateState.venueAssigned:
      case DateState.venueConfirmationPending:
      case DateState.booked:
        // TODO: Implement booking card (UI-8)
        return const SizedBox.shrink();

      case DateState.awaitingPresenceConfirmation:
        return _buildPresenceConfirmationCTA(context, dateDetail, currentUid);

      case DateState.ready:
        return _buildReadyCTA(context, dateDetail);

      case DateState.completed:
      case DateState.cancelled:
      case DateState.expired:
        // TODO: Implement terminal panels (UI-10)
        return const SizedBox.shrink();
    }
  }

  Widget _buildAvailabilityCTA(BuildContext context, DateDetail dateDetail) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dateDetail.availabilityRound == 2) ...[
          Text(
            'No overlap last time. Round 2 of 2.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton(
          onPressed: () {
            // TODO: Navigate to availability picker (UI-5)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Availability picker coming soon'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: const Text('Pick your times'),
        ),
      ],
    );
  }

  Widget _buildDepositCTA(BuildContext context, DateDetail dateDetail, String currentUid) {
    final youPaid = _hasUserPaid(dateDetail, currentUid);

    if (youPaid) {
      // User has paid, show waiting message
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dateDetail.depositDeadline != null)
            DeadlineCountdown(
              deadline: dateDetail.depositDeadline!,
              onExpired: () {
                ref.read(dateDetailProvider(widget.dateId).notifier).refresh();
              },
            ),
          const SizedBox(height: 12),
          Text(
            'You\'ve committed. Waiting for ${dateDetail.partnerName}.',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // User has not paid, show deposit button
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dateDetail.depositDeadline != null) ...[
          DeadlineCountdown(
            deadline: dateDetail.depositDeadline!,
            onExpired: () {
              ref.read(dateDetailProvider(widget.dateId).notifier).refresh();
            },
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton(
          onPressed: () {
            // TODO: Open deposit sheet (UI-6)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Deposit sheet coming soon'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Text('Commit ${TokenAmount.formatTokenAmount(dateDetail.tokenCost)}'),
        ),
      ],
    );
  }

  Widget _buildVenueRankingCTA(BuildContext context, DateDetail dateDetail) {
    final hasRanked = dateDetail.myRankings.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dateDetail.rankingDeadline != null) ...[
          DeadlineCountdown(
            deadline: dateDetail.rankingDeadline!,
            onExpired: () {
              ref.read(dateDetailProvider(widget.dateId).notifier).refresh();
            },
          ),
          const SizedBox(height: 12),
        ],
        if (hasRanked) ...[
          Text(
            'Waiting for ${dateDetail.partnerName}\'s picks',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton(
          onPressed: () {
            // TODO: Navigate to venue ranking (UI-7)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Venue ranking coming soon'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Text(hasRanked ? 'View your ranking' : 'Rank venues'),
        ),
      ],
    );
  }

  Widget _buildPresenceConfirmationCTA(BuildContext context, DateDetail dateDetail, String currentUid) {
    final youConfirmed = _hasUserConfirmed(dateDetail, currentUid);

    if (youConfirmed) {
      return Text(
        'Waiting for ${dateDetail.partnerName} to confirm',
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textSecondary,
        ),
        textAlign: TextAlign.center,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confirm you\'ll be there',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            // TODO: Confirm presence (UI-8)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Presence confirmation coming soon'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: const Text('I\'m coming'),
        ),
      ],
    );
  }

  Widget _buildReadyCTA(BuildContext context, DateDetail dateDetail) {
    return Text(
      'You\'re both confirmed. See you there.',
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.textSecondary,
      ),
      textAlign: TextAlign.center,
    );
  }

  void _showStatusExplanation(BuildContext context, DateState state) {
    String explanation = '';

    switch (state) {
      case DateState.awaitingAvailability:
        explanation =
            'Both of you pick times you\'re free over the next three weeks. We find the earliest one that works for you both. If nothing overlaps you each get one more go.';
        break;
      case DateState.awaitingDeposit:
        explanation =
            'A small token deposit from each of you keeps the date real. If either of you cancels after both have paid, the person cancelling loses their deposit and the other gets theirs back. Miss the deadline and everything is refunded.';
        break;
      case DateState.awaitingVenueRanking:
        explanation =
            'We\'ve shortlisted venues near you both. Rank them and we\'ll book whichever you agree on most.';
        break;
      case DateState.venueAssigned:
      case DateState.venueConfirmationPending:
        explanation = 'Our team is confirming your table. Nothing to do yet.';
        break;
      case DateState.booked:
        explanation =
            'You\'re booked. The day before, we\'ll ask you both to confirm you\'re still coming.';
        break;
      case DateState.awaitingPresenceConfirmation:
        explanation = 'Final check. Once you\'ve both confirmed, you\'re all set.';
        break;
      case DateState.ready:
        explanation = 'All set. Enjoy it.';
        break;
      case DateState.completed:
      case DateState.cancelled:
      case DateState.expired:
        explanation = '';
        break;
    }

    if (explanation.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

            // Explanation text
            Text(
              explanation,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
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
    );
  }

  void _showCancelDialog(BuildContext context, DateDetail dateDetail, String currentUid) {
    // TODO: Implement cancel flow (UI-9)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cancel flow coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _shouldShowOverflowMenu(DateDetail dateDetail) {
    // Don't show if not cancellable
    if (!dateDetail.cancellable) {
      return false;
    }

    // Don't show if past scheduled end
    if (dateDetail.scheduledEnd != null &&
        dateDetail.scheduledEnd!.isBefore(DateTime.now())) {
      return false;
    }

    // Don't show for terminal states
    return !dateDetail.state.isTerminal;
  }

  // Helper methods to check participant status

  bool _hasUserSubmitted(DateDetail dateDetail, String currentUid) {
    // Check if user submitted availability
    // This would need to be checked via availability view
    // For now, return false (will be implemented in UI-5)
    return false;
  }

  bool _hasUserPaid(DateDetail dateDetail, String currentUid) {
    final participants = dateDetail.participants;
    if (participants.isEmpty) return false;

    try {
      final userParticipant = participants.firstWhere(
        (p) => p.userId == currentUid,
      );
      return userParticipant.depositStatus == ParticipantDepositStatus.paid;
    } catch (e) {
      // User not found in participants list
      return false;
    }
  }

  bool _hasUserConfirmed(DateDetail dateDetail, String currentUid) {
    // Check if user confirmed presence
    // This would need to be tracked in date detail or separate state
    // For now, return false (will be implemented in UI-8)
    return false;
  }
}
