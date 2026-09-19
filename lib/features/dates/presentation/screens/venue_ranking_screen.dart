import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/venue_ranking_provider.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:eros_app/features/dates/presentation/widgets/deadline_countdown.dart';
import 'package:eros_app/features/dates/presentation/widgets/cancel_date_dialog.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// UI-7: Venue ranking screen
///
/// - ReorderableListView with rank badges (1, 2, 3...)
/// - Drag to reorder venues
/// - Single venue edge case: show confirm button
/// - Read-only mode when myRankings.isNotEmpty
/// - Submit and handle venue assignment response
class VenueRankingScreen extends ConsumerStatefulWidget {
  final String dateId;
  final DateTime? rankingDeadline;
  final bool readOnly;

  const VenueRankingScreen({
    super.key,
    required this.dateId,
    this.rankingDeadline,
    this.readOnly = false,
  });

  @override
  ConsumerState<VenueRankingScreen> createState() =>
      _VenueRankingScreenState();
}

class _VenueRankingScreenState extends ConsumerState<VenueRankingScreen> {
  List<VenueOption> _orderedVenues = [];
  bool _isSubmitting = false;
  bool _isLoadingCancelDialog = false;

  @override
  Widget build(BuildContext context) {
    final venueOptionsAsync = ref.watch(venueOptionsProvider(widget.dateId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          DatesCopy.venueRankingTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      backgroundColor: AppColors.background,
      body: venueOptionsAsync.when(
        data: (venueOptions) {
          // Initialize ordered venues on first build
          if (_orderedVenues.isEmpty) {
            if (venueOptions.myRankings.isNotEmpty) {
              // User already ranked - restore their order
              _orderedVenues = _restoreRankedOrder(
                venueOptions.options,
                venueOptions.myRankings,
              );
            } else {
              // New ranking - use default order
              _orderedVenues = List.from(venueOptions.options);
              _orderedVenues.sort((a, b) => a.optionOrder.compareTo(b.optionOrder));
            }
          }

          final isReadOnly = widget.readOnly || venueOptions.myRankings.isNotEmpty;
          final isSingleVenue = _orderedVenues.length == 1;

          return Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isReadOnly) ...[
                      Text(
                        isSingleVenue
                            ? DatesCopy.venueRankingSingleCaption
                            : DatesCopy.venueRankingSubtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (widget.rankingDeadline != null) ...[
                        const SizedBox(height: 12),
                        DeadlineCountdown(
                          deadline: widget.rankingDeadline!,
                          onExpired: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DatesCopy.venueRankingReadOnly('Partner'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Venue list
              Expanded(
                child: isSingleVenue
                    ? _buildSingleVenueCard(_orderedVenues.first)
                    : _buildReorderableList(isReadOnly),
              ),

              // Footer button
              if (!isReadOnly)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.disabled,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                isSingleVenue
                                    ? DatesCopy.venueRankingConfirmSingle
                                    : DatesCopy.venueRankingSendButton,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                // Cancel button (only show if not read-only)
                if (!isReadOnly)
                  Container(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: Center(
                      child: TextButton(
                        onPressed: _isSubmitting ? null : () => _showCancelDialog(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                        ),
                        child: const Text(
                          'Cancel this date',
                          style: TextStyle(
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                error is NotFoundException
                    ? 'Venues not available yet'
                    : 'Failed to load venues',
                style: const TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(venueOptionsProvider(widget.dateId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleVenueCard(VenueOption venue) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildVenueCard(venue, 1, isDraggable: false),
      ),
    );
  }

  Widget _buildReorderableList(bool isReadOnly) {
    if (isReadOnly) {
      // Non-draggable list for read-only mode
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _orderedVenues.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildVenueCard(
            _orderedVenues[index],
            index + 1,
            isDraggable: false,
          );
        },
      );
    }

    // Reorderable list for active ranking
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      onReorder: _handleReorder,
      itemCount: _orderedVenues.length,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final venue = _orderedVenues[index];
        return _buildVenueCard(
          venue,
          index + 1,
          key: ValueKey(venue.venueId),
          isDraggable: true,
        );
      },
    );
  }

  Widget _buildVenueCard(
    VenueOption venue,
    int rank, {
    Key? key,
    required bool isDraggable,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textTertiary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primaryOrange,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              rank.toString(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Venue info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  venue.address,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _openMaps(venue.address),
                  child: const Text(
                    'Open in Maps',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Drag handle
          if (isDraggable)
            const Icon(
              Icons.drag_handle,
              color: AppColors.textSecondary,
              size: 24,
            ),
        ],
      ),
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _orderedVenues.removeAt(oldIndex);
      _orderedVenues.insert(newIndex, item);
    });
  }

  void _showCancelDialog(BuildContext context) async {
    if (_isLoadingCancelDialog) return;

    setState(() {
      _isLoadingCancelDialog = true;
    });

    try {
      // Get date detail for cancel dialog
      final dateDetail = await ref.read(datesRepositoryProvider).getDateById(widget.dateId);
      if (dateDetail == null || !mounted) return;

      final currentUid = ref.read(authServiceProvider).currentUser?.uid ?? '';

      showDialog(
        context: context,
        builder: (context) => CancelDateDialog(
          dateId: widget.dateId,
          dateDetail: dateDetail,
          partnerName: dateDetail.partnerName(currentUid),
          currentUid: currentUid,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCancelDialog = false;
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);

    final rankings = _orderedVenues
        .asMap()
        .entries
        .map((entry) => VenueRankingSubmission(
              venueId: entry.value.venueId,
              rank: entry.key + 1, // Rank is 1-based
            ))
        .toList();

    final request = SubmitRankingsRequest(rankings);

    try {
      final response = await ref
          .read(venueRankingProvider(widget.dateId))
          .submitRankings(request);

      if (!mounted) return;

      if (response.venueAssigned && response.assignedVenueId != null) {
        // Venue assigned! Show result screen
        // Note: We need to find the venue name from our local list
        final assignedVenue = _orderedVenues.firstWhere(
          (v) => v.venueId == response.assignedVenueId,
          orElse: () => _orderedVenues.first,
        );
        _showVenueAssignedScreen(assignedVenue.name);
      } else {
        // Ranking sent, waiting for partner
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(DatesCopy.venueRankingSent('Partner')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Backend quirk 8: might reject if not enough venues
      if (e.message.contains('3')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(DatesCopy.venueStillSorting),
            backgroundColor: AppColors.error,
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } on ConflictException {
      // 409: partner might have ranked first, refetch
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showVenueAssignedScreen(String venueName) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _VenueAssignedResultScreen(venueName: venueName),
      ),
    );
  }

  List<VenueOption> _restoreRankedOrder(
    List<VenueOption> options,
    List<VenueRanking> rankings,
  ) {
    final rankMap = {for (var r in rankings) r.venueId: r.rank};
    final orderedOptions = List<VenueOption>.from(options);
    orderedOptions.sort((a, b) {
      final rankA = rankMap[a.venueId] ?? 999;
      final rankB = rankMap[b.venueId] ?? 999;
      return rankA.compareTo(rankB);
    });
    return orderedOptions;
  }

  Future<void> _openMaps(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final url = Uri.parse('https://maps.apple.com/?q=$encodedAddress');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps')),
      );
    }
  }
}

/// Result screen shown when venue is assigned
class _VenueAssignedResultScreen extends StatelessWidget {
  final String venueName;

  const _VenueAssignedResultScreen({required this.venueName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                DatesCopy.venueAssignedHeading(venueName),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Pop to detail screen
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    DatesCopy.venueAssignedButton,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
