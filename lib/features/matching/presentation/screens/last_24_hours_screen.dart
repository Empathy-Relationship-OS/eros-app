import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/matching/domain/models/match_models.dart';
import 'package:eros_app/features/matching/presentation/providers/match_provider.dart';
import 'package:eros_app/features/matching/presentation/screens/public_profile_view_screen.dart';
import 'package:eros_app/features/matching/presentation/widgets/match_card_components.dart';

/// Screen displaying profiles user passed on in the last 24 hours
///
/// Allows users to reconsider their "pass" decisions within a 24-hour window.
/// Users can only take positive action (like) on these profiles.
class Last24HoursScreen extends ConsumerStatefulWidget {
  const Last24HoursScreen({super.key});

  @override
  ConsumerState<Last24HoursScreen> createState() => _Last24HoursScreenState();
}

class _Last24HoursScreenState extends ConsumerState<Last24HoursScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch last 24 hours on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(last24HoursProvider.notifier).fetchLast24HourPasses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(last24HoursProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Last 24 Hours'),
        centerTitle: true,
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(Last24HoursState state) {
    // Loading state
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    // Error state (with retry)
    if (state.hasError && !state.hasProfiles) {
      return _buildErrorView(state.errorMessage);
    }

    // Empty state
    if (!state.hasProfiles) {
      return _buildEmptyView();
    }

    // List of profiles
    return _buildProfileList(state.profiles);
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'No Recent Passes',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'You haven\'t passed on anyone in the last 24 hours',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String? errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to Load',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage ?? 'An error occurred',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(last24HoursProvider.notifier).fetchLast24HourPasses();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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

  Widget _buildProfileList(List<UserMatchProfile> profiles) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return _Last24HourCard(
          profile: profile,
          key: ValueKey(profile.matchId),
        );
      },
    );
  }
}

/// Individual card for last 24 hour pass
class _Last24HourCard extends ConsumerStatefulWidget {
  final UserMatchProfile profile;

  const _Last24HourCard({
    required this.profile,
    super.key,
  });

  @override
  ConsumerState<_Last24HourCard> createState() => _Last24HourCardState();
}

class _Last24HourCardState extends ConsumerState<_Last24HourCard> {
  bool _isProcessingAction = false;

  Future<void> _handleLike() async {
    if (_isProcessingAction) return;

    setState(() {
      _isProcessingAction = true;
    });

    try {
      final mutualMatch = await ref
          .read(last24HoursProvider.notifier)
          .takeMatchAction(widget.profile.matchId);

      if (mutualMatch != null && mounted) {
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
      builder: (context) => MutualMatchDialog(
        partnerName: widget.profile.name,
        onContinue: () {
          Navigator.of(context).pop();
          // TODO: Navigate to dates/chat when implemented
        },
      ),
    );
  }

  void _navigateToPublicProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PublicProfileViewScreen(
          userId: widget.profile.userId,
          matchId: widget.profile.matchId,
          isFromLast24Hours: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile image - tappable to open full profile
            GestureDetector(
              onTap: _navigateToPublicProfile,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ProfileImageSection(profile: widget.profile),
              ),
            ),

            // Profile info - also tappable
            GestureDetector(
              onTap: _navigateToPublicProfile,
              child: ProfileInfoSection(profile: widget.profile),
            ),

            // Action button - only "Go for a date" (like) is allowed
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SingleActionButton(
                isProcessing: _isProcessingAction,
                onPressed: _handleLike,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
