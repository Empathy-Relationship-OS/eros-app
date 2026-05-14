import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/domain/models/public_profile.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_display_components.dart';
import 'package:eros_app/features/matching/presentation/providers/match_provider.dart';
import 'package:eros_app/features/matching/domain/models/match_models.dart';
import 'package:eros_app/features/matching/presentation/widgets/match_card_components.dart';

/// Screen to view a match's public profile with floating action buttons
class PublicProfileViewScreen extends ConsumerStatefulWidget {
  final String userId;
  final int matchId;

  /// If true, only show "Go for a date" button (used for Last 24 Hours)
  /// If false, show both "Not for me" and "Go for a date" buttons
  final bool isFromLast24Hours;

  const PublicProfileViewScreen({
    super.key,
    required this.userId,
    required this.matchId,
    this.isFromLast24Hours = false,
  });

  @override
  ConsumerState<PublicProfileViewScreen> createState() =>
      _PublicProfileViewScreenState();
}

class _PublicProfileViewScreenState
    extends ConsumerState<PublicProfileViewScreen> {
  late final Future<PublicProfileDTO> _profileFuture;
  bool _isProcessingAction = false;
  final bool _showActionButtons = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Fetch profile once during initialization
    _profileFuture =
        ref.read(profileRepositoryProvider).getPublicProfile(widget.userId);

    // Add scroll listener to show/hide action buttons
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Keep buttons visible at all times for now
    // Could implement auto-hide on scroll up if needed
  }

  Future<void> _handleAction(bool liked) async {
    if (_isProcessingAction) return;

    setState(() {
      _isProcessingAction = true;
    });

    try {
      final MutualMatchInfo? mutualMatch;

      if (widget.isFromLast24Hours) {
        // Use Last24HoursNotifier for profiles from Last 24 Hours screen
        // Note: Last 24 Hours only supports "like" action, not "pass"
        final last24Notifier = ref.read(last24HoursProvider.notifier);
        mutualMatch = await last24Notifier.takeMatchAction(widget.matchId);
      } else {
        // Use MatchBatchNotifier for regular match profiles
        final matchNotifier = ref.read(matchBatchProvider.notifier);
        mutualMatch = await matchNotifier.takeMatchAction(
          widget.matchId,
          liked,
        );
      }

      if (mutualMatch != null && mounted) {
        // Show mutual match dialog
        _showMutualMatchDialog(mutualMatch);
      } else if (mounted) {
        // Go back to matches screen after action
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  void _showMutualMatchDialog(MutualMatchInfo mutualMatch) async {
    final profile = await _profileFuture;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MutualMatchDialog(
        partnerName: profile.name,
        onContinue: () {
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).pop(); // Go back to matches
          // TODO: Navigate to dates/chat when implemented
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<PublicProfileDTO>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text('No profile data available'),
            );
          }

          final profile = snapshot.data!;

          return Stack(
            children: [
              // Scrollable profile content
              SingleChildScrollView(
                controller: _scrollController,
                child: _ProfileContent(profile: profile),
              ),

              // Floating action buttons at bottom
              if (_showActionButtons)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.background.withValues(alpha: 0.0),
                          AppColors.background.withValues(alpha: 0.95),
                          AppColors.background,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: widget.isFromLast24Hours
                          ? SingleActionButton(
                              isProcessing: _isProcessingAction,
                              onPressed: () => _handleAction(true),
                            )
                          : MatchActionButtons(
                              isProcessing: _isProcessingAction,
                              onPass: () => _handleAction(false),
                              onLike: () => _handleAction(true),
                            ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Profile content widget (same structure as preview)
class _ProfileContent extends StatelessWidget {
  final PublicProfileDTO profile;

  const _ProfileContent({required this.profile});

  @override
  Widget build(BuildContext context) {
    final qas = profile.profile.qas;
    final backendPhotos = profile.profile.photos;

    // Use backend photos (no local photos in this context)
    final String? thumbnailPath =
    backendPhotos.isNotEmpty ? backendPhotos.first : null;
    final List<PhotoWithCaption> remainingPhotos = backendPhotos.length > 1
        ? backendPhotos
        .sublist(1)
        .map((p) => PhotoWithCaption(
      path: p,
      caption: null,
      isLocal: false,
    ))
        .toList()
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Thumbnail photo (large)
        if (thumbnailPath != null)
          ThumbnailPhoto(
            photoPath: thumbnailPath,
            isLocal: false,
          ),

        Container(
          margin: const EdgeInsets.all(16.0),
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name and Age
              NameAndAgeDisplay(
                name: profile.name,
                age: profile.age,
                fontSize: 32,
              ),
              const SizedBox(height: 16),

              // Bio (if available)
              if (profile.profile.bio != null &&
                  profile.profile.bio!.isNotEmpty) ...[
                Text(
                  profile.profile.bio!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 2. Horizontal scrollable info row
              HorizontalInfoScroll(profile: profile),
              const SizedBox(height: 24),

              // 3. Detailed info section
              DetailedInfoSection(profile: profile),
            ],
          ),
        ),

        // 4. Ordered interspersed content
        OrderedInterspersedContent(
          hobbies: profile.profile.hobbies,
          traits: profile.profile.traits,
          brainAttribute: profile.profile.brainAttribute,
          brainDescription: profile.profile.brainDescription,
          bodyAttribute: profile.profile.bodyAttribute,
          bodyDescription: profile.profile.bodyDescription,
          photos: remainingPhotos,
          qas: qas,
        ),

        // Add padding at bottom for floating buttons
        const SizedBox(height: 120),
      ],
    );
  }
}

/// Mutual match dialog
class _MutualMatchDialog extends StatelessWidget {
  final String partnerName;
  final VoidCallback onContinue;

  const _MutualMatchDialog({
    required this.partnerName,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'It\'s a Match!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              'You and $partnerName liked each other!',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
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
}
