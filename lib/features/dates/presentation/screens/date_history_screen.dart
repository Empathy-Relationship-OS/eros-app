import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_list_provider.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_formats.dart';

/// Date history screen with two segments: Past and Cancelled
///
/// Per UI-3: Replaces three-tab layout. Active dates are main tab,
/// history is behind a history icon in app bar.
class DateHistoryScreen extends ConsumerStatefulWidget {
  const DateHistoryScreen({super.key});

  @override
  ConsumerState<DateHistoryScreen> createState() => _DateHistoryScreenState();
}

class _DateHistoryScreenState extends ConsumerState<DateHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(DatesCopy.historyTitle),
        backgroundColor: AppColors.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.7),
          tabs: const [
            Tab(text: DatesCopy.historyTabPast),
            Tab(text: DatesCopy.historyTabCancelled),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPastTab(),
          _buildCancelledTab(),
        ],
      ),
    );
  }

  Widget _buildPastTab() {
    final pastState = ref.watch(pastDatesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(pastDatesProvider.notifier).refresh();
      },
      child: _buildDatesList(
        state: pastState,
        emptyMessage: DatesCopy.historyEmptyPast,
      ),
    );
  }

  Widget _buildCancelledTab() {
    final cancelledState = ref.watch(cancelledDatesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(cancelledDatesProvider.notifier).refresh();
      },
      child: _buildDatesList(
        state: cancelledState,
        emptyMessage: DatesCopy.historyEmptyCancelled,
      ),
    );
  }

  Widget _buildDatesList({
    required DatesListState state,
    required String emptyMessage,
  }) {
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
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load dates',
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
          Center(
            child: ElevatedButton(
              onPressed: () {
                // Retry based on which tab we're on
                if (_tabController.index == 0) {
                  ref.read(pastDatesProvider.notifier).refresh();
                } else {
                  ref.read(cancelledDatesProvider.notifier).refresh();
                }
              },
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    // Empty state
    if (state.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.history,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            emptyMessage,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // List of dates (compact rows)
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.dates.length,
      itemBuilder: (context, index) {
        final date = state.dates[index];
        return _HistoryDateRow(
          date: date,
          onTap: () {
            // Navigate to date detail
            Navigator.of(context).pushNamed(
              '/dates/detail',
              arguments: date.dateId.toString(),
            );
          },
        );
      },
    );
  }
}

/// Compact row for history list
class _HistoryDateRow extends StatelessWidget {
  final DateSummary date;
  final VoidCallback onTap;

  const _HistoryDateRow({
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _buildAvatar(),
      title: Text(
        date.partnerName,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            date.activityName,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          if (date.scheduledStart != null) ...[
            const SizedBox(height: 2),
            Text(
              DateFormats.formatDateTime(date.scheduledStart!),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
      trailing: _buildStatePill(),
    );
  }

  Widget _buildAvatar() {
    final initial =
        date.partnerName.isNotEmpty ? date.partnerName[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primaryOrangeLight,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
      ),
    );
  }

  Widget _buildStatePill() {
    final (pillText, tone) = _getStatePill();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getToneColor(tone), width: 1),
        color: _getToneColor(tone).withValues(alpha: 0.1),
      ),
      child: Text(
        pillText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _getToneColor(tone),
        ),
      ),
    );
  }

  (String, String) _getStatePill() {
    switch (date.state) {
      case DateState.completed:
        return ('Completed', 'neutral');
      case DateState.cancelled:
        return ('Cancelled', 'muted');
      case DateState.expired:
        return ('Expired', 'muted');
      default:
        return (date.state.name, 'neutral');
    }
  }

  Color _getToneColor(String tone) {
    switch (tone) {
      case 'neutral':
        return AppColors.textPrimary;
      case 'muted':
        return AppColors.textTertiary;
      default:
        return AppColors.textSecondary;
    }
  }
}
