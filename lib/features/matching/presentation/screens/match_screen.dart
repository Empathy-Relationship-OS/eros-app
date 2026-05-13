import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/matching/presentation/providers/match_provider.dart';
import 'package:eros_app/features/matching/presentation/widgets/match_state_views.dart';
import 'package:eros_app/features/matching/presentation/widgets/match_carousel.dart';

import '../widgets/match_carousel_v2.dart';

/// Main matching screen showing daily batch of matches
class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key});

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> {
  Timer? _countdownTimer;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.88, // Show 88% of card width to allow side cards to peek
      initialPage: 0,
    );

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
    _pageController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(matchBatchProvider);
    final matchNotifier = ref.read(matchBatchProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Muse'),
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
    return LimitExceededView(timeUntilReset: timeUntilReset);
  }

  Widget _buildNoMatchesView(
    MatchBatchState state,
    MatchBatchNotifier notifier,
  ) {
    return NoMatchesView(
      errorMessage: state.errorMessage,
      onRefresh: () => notifier.fetchDailyBatch(),
    );
  }

  Widget _buildEmptyStateView(MatchBatchNotifier notifier) {
    return EmptyStateView(
      onViewMatches: () => notifier.fetchDailyBatch(),
    );
  }

  Widget _buildMatchListView(
    MatchBatchState state,
    MatchBatchNotifier notifier,
  ) {
    return MatchCarouselV2(
      profiles: state.profiles,
      notifier: notifier,
      initialIndex: 0,
      onPageChanged: (index) {
        // Optional: Handle page changes if needed
      },
    );
  }
}
