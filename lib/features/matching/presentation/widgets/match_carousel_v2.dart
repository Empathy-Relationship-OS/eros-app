import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/matching/domain/models/match_models.dart';
import 'package:eros_app/features/matching/presentation/providers/match_provider.dart';
import 'package:eros_app/features/matching/presentation/widgets/match_card_components.dart';

/// Carousel view for match cards using Flutter's built-in CarouselView
///
/// This implementation leverages Material Design 3's CarouselView widget
/// which provides smooth scrolling, peek effects, and better performance
/// than manual PageView implementations.
class MatchCarouselV2 extends StatefulWidget {
  final List<UserMatchProfile> profiles;
  final MatchBatchNotifier notifier;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;

  const MatchCarouselV2({
    super.key,
    required this.profiles,
    required this.notifier,
    this.initialIndex = 0,
    this.onPageChanged,
  });

  @override
  State<MatchCarouselV2> createState() => _MatchCarouselV2State();
}

class _MatchCarouselV2State extends State<MatchCarouselV2> {
  late CarouselController _carouselController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _carouselController = CarouselController(
      initialItem: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    setState(() {
      _currentIndex = index;
    });
    widget.onPageChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return CarouselView(
      controller: _carouselController,
      itemExtent: screenWidth - 32, // 16px padding on each side
      shrinkExtent: screenWidth - 32, // Same as itemExtent - no shrinking effect
      elevation: 0, // Cards handle their own shadows
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 0),
      onTap: _handleTap,
      children: List.generate(
        widget.profiles.length,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _CarouselCardV2(
            profile: widget.profiles[index],
            notifier: widget.notifier,
            index: index,
            isActive: index == _currentIndex,
          ),
        ),
      ),
    );
  }
}

/// Individual card in the carousel with its own action buttons
class _CarouselCardV2 extends ConsumerStatefulWidget {
  final UserMatchProfile profile;
  final MatchBatchNotifier notifier;
  final int index;
  final bool isActive;

  const _CarouselCardV2({
    required this.profile,
    required this.notifier,
    required this.index,
    required this.isActive,
  });

  @override
  ConsumerState<_CarouselCardV2> createState() => _CarouselCardV2State();
}

class _CarouselCardV2State extends ConsumerState<_CarouselCardV2> {
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
    return GestureDetector(
      onTap: _navigateToPublicProfile,
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
                child: ProfileImageSection(profile: widget.profile),
              ),

              // Profile info section
              ProfileInfoSection(profile: widget.profile),

              // Action buttons inside the card
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: MatchActionButtons(
                  isProcessing: _isProcessingAction,
                  onPass: () => _handleAction(false),
                  onLike: () => _handleAction(true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

