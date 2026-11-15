import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_list_provider.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_formats.dart';
import 'package:eros_app/features/dates/presentation/widgets/error_state_widget.dart';

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
      appBar: AppBar(
        title: const Text(DatesCopy.historyTitle),
        bottom: TabBar(
          controller: _tabController,
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
        onRetry: () {
          ref.read(pastDatesProvider.notifier).refresh();
        },
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
        onRetry: () {
          ref.read(cancelledDatesProvider.notifier).refresh();
        },
      ),
    );
  }

  Widget _buildDatesList({
    required DatesListState state,
    required String emptyMessage,
    required VoidCallback onRetry,
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
      return ErrorStateWidget(
        error: Exception(state.errorMessage ?? 'Unknown error'),
        onRetry: onRetry,
        onGoBack: () => Navigator.of(context).pop(),
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
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _buildAvatar(textTheme),
      title: Text(
        date.partnerName,
        style: textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            date.activityName,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          if (date.scheduledStart != null) ...[
            const SizedBox(height: 2),
            Text(
              DateFormats.formatDateTime(date.scheduledStart!),
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
      trailing: _buildStatePill(textTheme),
    );
  }

  Widget _buildAvatar(TextTheme textTheme) {
    final initial =
        date.partnerName.isNotEmpty ? date.partnerName[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primaryTint,
      child: Text(
        initial,
        style: textTheme.headlineSmall?.copyWith(color: AppColors.primaryDeep),
      ),
    );
  }

  Widget _buildStatePill(TextTheme textTheme) {
    final (pillText, tone) = _getStatePill();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        color: AppColors.surfaceMuted,
      ),
      child: Text(
        pillText,
        style: textTheme.labelMedium?.copyWith(color: _getToneColor(tone)),
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
        return ('No longer active', 'muted');
      default:
        return (date.state.name, 'neutral');
    }
  }

  Color _getToneColor(String tone) {
    switch (tone) {
      case 'neutral':
        return AppColors.textPrimary;
      case 'muted':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }
}
