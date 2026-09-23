import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_list_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_empty_state.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_card.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:eros_app/features/dates/presentation/widgets/error_state_widget.dart';
import 'package:eros_app/features/dates/presentation/screens/date_history_screen.dart';

/// Dates tab screen - Shows active dates or empty state
///
/// Per UI-2 & UI-3:
/// - Empty state: "What happens after you match?" explainer
/// - Active dates: List of date cards
/// - History icon in app bar (clock arrow) pushes to history screen
/// - "How Muse works" link below cards
class DatesScreen extends ConsumerWidget {
  const DatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDatesState = ref.watch(activeDatesProvider);
    final authService = ref.watch(authServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dates'),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          // History icon (clock arrow)
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DateHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(activeDatesProvider.notifier).refresh();
          },
          child: _buildBody(context, activeDatesState, authService, ref),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DatesListState state,
    AuthService authService,
    WidgetRef ref,
  ) {
    // Loading state
    if (state.isLoading && state.dates.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    // Error state
    if (state.hasError && state.dates.isEmpty) {
      return ErrorStateWidget(
        error: Exception(state.errorMessage ?? 'Unknown error'),
        onRetry: () {
          ref.read(activeDatesProvider.notifier).refresh();
        },
      );
    }

    // Empty state: Show "What happens after you match?"
    if (state.isEmpty) {
      return const DatesEmptyState();
    }

    // Active dates list
    return _buildActiveList(context, ref, state, authService);
  }

  Widget _buildActiveList(
    BuildContext context,
    WidgetRef ref,
    DatesListState state,
    AuthService authService,
  ) {
    final currentUid = authService.currentUser?.uid ?? '';

    return CustomScrollView(
      slivers: [
        // Date cards
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final date = state.dates[index];
              return DateCard(
                date: date,
                currentUserId: currentUid,
                onTap: () {
                  // Navigate to date detail
                  Navigator.of(context).pushNamed(
                    '/dates/detail',
                    arguments: date.dateId.toString(),
                  );
                },
                onActionTap: () {
                  // Navigate directly to action-specific screen
                  _handleActionNavigation(context, ref, date);
                },
              );
            },
            childCount: state.dates.length,
          ),
        ),

        // "How Muse works" link below cards
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  // Show "How Muse works" bottom sheet
                  _showHowItWorks(context);
                },
                icon: const Icon(Icons.info_outline, size: 18),
                label: Text(
                  DatesCopy.howMuseWorksButton,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 16),
        ),
      ],
    );
  }

  /// Navigate directly to action-specific screen based on date state
  ///
  /// Fetches full date detail to get context like availabilityRound,
  /// then navigates to the appropriate action screen
  Future<void> _handleActionNavigation(BuildContext context, WidgetRef ref, DateSummary date) async {
    // Show loading indicator while fetching
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fetch full date detail to get additional context
      final repository = ref.read(datesRepositoryProvider);
      final dateDetail = await repository.getDateById(date.dateId.toString());

      if (!context.mounted) return;

      // Dismiss loading
      Navigator.of(context).pop();

      if (dateDetail == null) {
        // Date not found, show error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Date not found')),
        );
        return;
      }

      // Navigate based on state
      switch (date.state) {
        case DateState.awaitingAvailability:
          // Navigate to availability picker with round
          Navigator.of(context).pushNamed(
            '/dates/availability',
            arguments: {
              'dateId': date.dateId.toString(),
              'round': dateDetail.availabilityRound,
            },
          );
          break;

        case DateState.awaitingDeposit:
        case DateState.awaitingVenueRanking:
        case DateState.awaitingPresenceConfirmation:
        default:
          // For other states, navigate to detail screen
          Navigator.of(context).pushNamed(
            '/dates/detail',
            arguments: date.dateId.toString(),
          );
      }
    } catch (e) {
      if (!context.mounted) return;

      // Dismiss loading
      Navigator.of(context).pop();

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load date: $e')),
      );
    }
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
