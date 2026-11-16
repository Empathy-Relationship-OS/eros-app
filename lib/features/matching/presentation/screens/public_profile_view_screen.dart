import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
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

  /// If true, hide action buttons entirely (used when viewing already matched dates)
  final bool hideActionButtons;

  /// If true, the user is previewing their own profile (RFC-004 PE-F5): every action is hidden
  /// and a "This is how others see you" banner is shown instead.
  final bool previewMode;

  const PublicProfileViewScreen({
    super.key,
    required this.userId,
    required this.matchId,
    this.isFromLast24Hours = false,
    this.hideActionButtons = false,
    this.previewMode = false,
  });

  /// The user's own profile as others see it, from the profile editor. There is no match, so
  /// [matchId] is unused.
  const PublicProfileViewScreen.preview({super.key, required this.userId})
      : matchId = 0,
        isFromLast24Hours = false,
        hideActionButtons = true,
        previewMode = true;

  @override
  ConsumerState<PublicProfileViewScreen> createState() =>
      _PublicProfileViewScreenState();
}

class _PublicProfileViewScreenState
    extends ConsumerState<PublicProfileViewScreen> {
  late final Future<PublicProfileDTO> _profileFuture;
  bool _isProcessingAction = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Fetch profile once during initialization. It is never cached, so a preview opened after
    // an edit shows the saved change.
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
      builder: (context) => MutualMatchDialog(
        partnerName: profile.name,
        dateId: mutualMatch.dateId,
        onContinue: () {
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).pop(); // Go back to matches
          // UI-11: Navigate to date detail if dateId present
          if (mutualMatch.dateId != null) {
            Navigator.of(context).pushNamed(
              '/dates/detail',
              arguments: mutualMatch.dateId.toString(),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      // No bar over the photo: just the back button on its own dark disc, which reads over a
      // photo and over the page alike.
      appBar: AppBar(
        forceMaterialTransparency: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.ink.withValues(alpha: 0.55),
              foregroundColor: AppColors.white,
            ),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: FutureBuilder<PublicProfileDTO>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ProfileLoadError(
              message: 'Unable to load profile',
              detail: snapshot.error.toString(),
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

              if (widget.previewMode)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(top: false, child: _PreviewBanner()),
                ),

              // Floating action buttons at bottom
              if (!widget.hideActionButtons && !widget.previewMode)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    // The fade happens above the buttons, so they sit on the page colour and
                    // the profile doesn't show through between them
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.3, 1],
                        colors: [
                          AppColors.background.withValues(alpha: 0.0),
                          AppColors.background,
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

/// Says the user is looking at their own profile as others see it.
class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const Key('preview-banner'),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility_outlined, color: AppColors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'This is how others see you',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.white),
            ),
          ],
        ),
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
    final List<ProfilePhoto> remainingPhotos = backendPhotos.length > 1
        ? backendPhotos
        .sublist(1)
        .map((p) => ProfilePhoto(
      path: p,
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
          )
        else
          // Nothing to sit under the back button, so the content starts below it. The top
          // padding already counts the app bar, as the body runs behind it.
          SizedBox(height: MediaQuery.paddingOf(context).top),

        // 2. Name, bio, basics and details
        ProfileHeaderCard(profile: profile),

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
