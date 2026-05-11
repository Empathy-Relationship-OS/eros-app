import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/matching/presentation/providers/match_provider.dart';
import 'package:eros_app/features/matching/domain/models/match_models.dart';

/// Main matching screen showing daily batch of matches
class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key});

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Fetch initial batch on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(matchBatchProvider.notifier).fetchDailyBatch();
    });

    // Start countdown timer for limit reset
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Trigger rebuild every second to update countdown
      if (mounted) {
        setState(() {});
      }
    });
  }

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
    final matchState = ref.watch(matchBatchProvider);
    final matchNotifier = ref.read(matchBatchProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Muse'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // DEBUG: Reset batch limit timer (only in debug mode)
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset batch limit (DEBUG)',
              onPressed: () async {
                final storageService = ref.read(matchStorageServiceProvider);
                await storageService.clearBatchLimitResetTime();
                // Reset state
                ref.invalidate(matchBatchProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Batch limit reset cleared!')),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authNotifier = ref.read(authStateProvider.notifier);
              await authNotifier.signOut();

              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(matchState, matchNotifier),
      ),
    );
  }

  Widget _buildBody(MatchBatchState state, MatchBatchNotifier notifier) {
    // Loading state
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    // Daily limit exceeded
    if (state.isLimitExceeded) {
      return _buildLimitExceededView(state, notifier);
    }

    // No matches available
    if (!state.hasProfiles && state.errorMessage != null) {
      return _buildNoMatchesView(state, notifier);
    }

    // Show matches
    if (state.hasProfiles) {
      return _buildMatchListView(state, notifier);
    }

    // Default: empty state
    return _buildEmptyStateView(notifier);
  }

  Widget _buildLimitExceededView(
    MatchBatchState state,
    MatchBatchNotifier notifier,
  ) {
    final timeUntilReset = notifier.getTimeUntilReset();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Clock icon
            Icon(
              Icons.access_time,
              size: 100,
              color: AppColors.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              'All Daily Potential Matches Viewed',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Message about refresh
            if (timeUntilReset != null && state.limitResetAt != null) ...[
              // Countdown card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Come back in:",
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formatDuration(timeUntilReset),
                      style:
                          Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoMatchesView(
    MatchBatchState state,
    MatchBatchNotifier notifier,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 24),
            Text(
              'No Matches Available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              state.errorMessage ?? 'Check back later for new matches',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                notifier.fetchDailyBatch();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateView(MatchBatchNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.favorite_outline,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Ready to Match?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Tap below to see your daily matches',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                notifier.fetchDailyBatch();
              },
              icon: const Icon(Icons.visibility),
              label: const Text('View Matches'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchListView(
    MatchBatchState state,
    MatchBatchNotifier notifier,
  ) {
    return Column(
      children: [
        // Batch info header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: AppColors.background
        ),

        // Horizontal scrollable match cards
        Expanded(
          child: PageView.builder(
            itemCount: state.profiles.length,
            itemBuilder: (context, index) {
              final profile = state.profiles[index];
              return _MatchCard(
                profile: profile,
                notifier: notifier,
                currentIndex: index,
                totalCount: state.profiles.length,
              );
            },
          ),
        ),
      ],
    );
  }

}

/// Match card widget displaying user profile in card format
/// Based on screenshots/match/87A5473E-37BE-403B-BBE2-76B03CD76AE6_1_105_c.jpeg
class _MatchCard extends ConsumerStatefulWidget {
  final UserMatchProfile profile;
  final MatchBatchNotifier notifier;
  final int currentIndex;
  final int totalCount;

  const _MatchCard({
    required this.profile,
    required this.notifier,
    required this.currentIndex,
    required this.totalCount,
  });

  @override
  ConsumerState<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends ConsumerState<_MatchCard> {
  bool _isProcessingAction = false;

  Future<void> _handleAction(bool liked) async {
    if (_isProcessingAction) return;

    setState(() {
      _isProcessingAction = true;
    });

    try {
      final mutualMatch = await widget.notifier.takeMatchAction(
        widget.profile.matchId,
        liked,
      );

      if (mutualMatch != null && mounted) {
        // Show mutual match dialog
        _showMutualMatchDialog(mutualMatch);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  void _showMutualMatchDialog(MutualMatchInfo mutualMatch) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite,
              color: AppColors.primary,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              "It's a Match!",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "You and ${widget.profile.name} liked each other!",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // TODO: Navigate to dates/chat when implemented
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPublicProfile() {
    // Navigate to public profile view
    Navigator.of(context).pushNamed(
      '/profile/public',
      arguments: widget.profile.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final badges = widget.profile.badges?.take(5).toList() ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Main card
          Expanded(
            child: GestureDetector(
              onTap: _navigateToPublicProfile,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Large profile photo
                      Expanded(
                        flex: 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            widget.profile.thumbnailUrl != null
                                ? Image.network(
                                    widget.profile.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: AppColors.cardBackground,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: AppColors.cardBackground,
                                        child: Center(
                                          child: Text(
                                            widget.profile.name[0].toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 80,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: AppColors.cardBackground,
                                    child: Center(
                                      child: Text(
                                        widget.profile.name[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 80,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                            // Gradient overlay at bottom for better text readability
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.7),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Profile info section
                      Container(
                        padding: const EdgeInsets.all(20),
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name with online indicator dot
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.profile.name,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Badges (matching traits)
                            if (badges.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: badges.map((badge) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          badge,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              // "Not for me" button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessingAction ? null : () => _handleAction(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardBackground,
                      foregroundColor: AppColors.textPrimary,
                      disabledBackgroundColor: AppColors.textSecondary.withValues(alpha: 0.3),
                      side: BorderSide(
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: _isProcessingAction
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : const Text(
                            'Not for me',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // "Go for a drink" button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessingAction ? null : () => _handleAction(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.textSecondary.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 2,
                    ),
                    child: _isProcessingAction
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Go for a date',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),

          // Page indicator dots
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.totalCount,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == widget.currentIndex ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == widget.currentIndex
                      ? AppColors.primary
                      : AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
