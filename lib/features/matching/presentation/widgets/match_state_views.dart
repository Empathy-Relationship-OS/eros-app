import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';

/// The icon at the top of each state below: deep coral on a tint circle.
class _StateIcon extends StatelessWidget {
  final IconData icon;

  const _StateIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: const BoxDecoration(
        color: AppColors.primaryTint,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 44, color: AppColors.primaryDeep),
    );
  }
}

/// Widget displayed when daily match limit is exceeded
class LimitExceededView extends StatelessWidget {
  final Duration? timeUntilReset;

  const LimitExceededView({
    super.key,
    this.timeUntilReset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _StateIcon(Icons.access_time),
            const SizedBox(height: 24),

            // Title
            Text(
              'All Daily Potential Matches Viewed',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Countdown card
            if (timeUntilReset != null) ...[
              _CountdownCard(timeUntilReset: timeUntilReset!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Countdown timer card showing time until reset
class _CountdownCard extends StatelessWidget {
  final Duration timeUntilReset;

  const _CountdownCard({required this.timeUntilReset});

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Come back in:",
                style: textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatDuration(timeUntilReset),
            style: textTheme.displaySmall?.copyWith(
              // Digits of one width, so the text doesn't shift as it counts down.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget displayed when no matches are available
class NoMatchesView extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback onRefresh;

  const NoMatchesView({
    super.key,
    this.errorMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _StateIcon(Icons.people_outline),
            const SizedBox(height: 24),
            Text(
              'No Matches Available',
              style: textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage ?? 'Check back later for new matches',
              style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget displayed in empty state (initial load)
class EmptyStateView extends StatelessWidget {
  final VoidCallback onViewMatches;

  const EmptyStateView({
    super.key,
    required this.onViewMatches,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _StateIcon(Icons.favorite_outline),
            const SizedBox(height: 24),
            Text(
              'Ready to Match?',
              style: textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tap below to see your daily matches',
              style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onViewMatches,
              icon: const Icon(Icons.visibility),
              label: const Text('View Matches'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget displayed when `GET /match/` has no one to show and the user has dealbreakers on
/// (RFC-007 §6.4). The only hint that dealbreakers are strict: never a count of people (D-16).
class DealbreakersEmptyView extends StatelessWidget {
  final VoidCallback onOpenMatchPreferences;
  final VoidCallback onRefresh;

  const DealbreakersEmptyView({
    super.key,
    required this.onOpenMatchPreferences,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _StateIcon(Icons.tune),
            const SizedBox(height: 24),
            Text(
              'You\'ve seen everyone who fits your dealbreakers for now',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onOpenMatchPreferences,
              icon: const Icon(Icons.tune),
              label: const Text('Match preferences'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
