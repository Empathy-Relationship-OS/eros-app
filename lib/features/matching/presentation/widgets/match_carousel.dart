import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/matching/domain/models/match_models.dart';
import 'package:eros_app/features/matching/presentation/providers/match_provider.dart';
import 'package:eros_app/features/matching/presentation/widgets/match_card_components.dart';

/// Carousel view for match cards with center-focused layout
class MatchCarousel extends StatefulWidget {
  final List<UserMatchProfile> profiles;
  final MatchBatchNotifier notifier;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;

  const MatchCarousel({
    super.key,
    required this.profiles,
    required this.notifier,
    required this.pageController,
    required this.onPageChanged,
  });

  @override
  State<MatchCarousel> createState() => _MatchCarouselState();
}

class _MatchCarouselState extends State<MatchCarousel> {
  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: widget.pageController,
      itemCount: widget.profiles.length,
      onPageChanged: widget.onPageChanged,
      itemBuilder: (context, index) {
        final profile = widget.profiles[index];
        return AnimatedBuilder(
          animation: widget.pageController,
          builder: (context, child) {
            // Calculate scale and opacity based on scroll position
            double scale = 1.0;
            double opacity = 1.0;

            if (widget.pageController.position.haveDimensions) {
              final page = widget.pageController.page ?? index.toDouble();
              final diff = (page - index).abs();

              // Scale: 1.0 for center, 0.85 for sides
              scale = (1 - (diff * 0.15)).clamp(0.85, 1.0);

              // Opacity: 1.0 for center, 0.7 for sides
              opacity = (1 - (diff * 0.3)).clamp(0.7, 1.0);
            }

            return Align(
              alignment: Alignment.center,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: child,
                ),
              ),
            );
          },
          child: _CarouselCard(
            profile: profile,
            notifier: widget.notifier,
            index: index,
          ),
        );
      },
    );
  }
}

/// Individual card in the carousel
class _CarouselCard extends ConsumerStatefulWidget {
  final UserMatchProfile profile;
  final MatchBatchNotifier notifier;
  final int index;

  const _CarouselCard({
    required this.profile,
    required this.notifier,
    required this.index,
  });

  @override
  ConsumerState<_CarouselCard> createState() => _CarouselCardState();
}

class _CarouselCardState extends ConsumerState<_CarouselCard> {
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
    Navigator.of(context).pushNamed(
      '/profile/public',
      arguments: widget.profile.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: MatchCard(
        profile: widget.profile,
        isProcessing: _isProcessingAction,
        onPass: () => _handleAction(false),
        onLike: () => _handleAction(true),
        onTapCard: _navigateToPublicProfile,
      ),
    );
  }
}

/// The visual match card component
class MatchCard extends StatelessWidget {
  final UserMatchProfile profile;
  final bool isProcessing;
  final VoidCallback onPass;
  final VoidCallback onLike;
  final VoidCallback onTapCard;

  const MatchCard({
    super.key,
    required this.profile,
    required this.isProcessing,
    required this.onPass,
    required this.onLike,
    required this.onTapCard,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Column(
        children: [
          // Main card
          Expanded(
            child: GestureDetector(
              onTap: onTapCard,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
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
                        child: ProfileImageSection(profile: profile),
                      ),

                      // Profile info section
                      ProfileInfoSection(profile: profile),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          MatchActionButtons(
            isProcessing: isProcessing,
            onPass: onPass,
            onLike: onLike,
          ),
        ],
      ),
    );
  }
}
