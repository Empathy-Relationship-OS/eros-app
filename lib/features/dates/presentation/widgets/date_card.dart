import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_status_pill.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_facts.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';

/// Card widget for displaying a date in list view
///
/// Per UI-3: Shows partner photo, name, facts (time/venue/activity), and status pill
/// Whole card taps through to detail screen
class DateCard extends StatelessWidget {
  final DateSummary date;
  final String currentUserId;
  final VoidCallback onTap;

  const DateCard({
    super.key,
    required this.date,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Partner header with optional chat bubble
              _buildPartnerHeader(),

              const SizedBox(height: 12),

              // Date facts (time, venue, activity)
              DateFacts(
                startTime: date.scheduledStart,
                venueName: date.venueName,
                activityName: date.activityName,
              ),

              const SizedBox(height: 12),

              // Status pill (state-only fallback since DateSummary lacks detail)
              _buildStatusPill(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerHeader() {
    return Row(
      children: [
        // Partner photo
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColors.primaryOrangeLight,
          ),
          clipBehavior: Clip.antiAlias,
          child: date.partnerThumbnailUrl != null
              ? CachedNetworkImage(
                  imageUrl: date.partnerThumbnailUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (context, url, error) =>
                      _buildInitialAvatar(date.partnerName),
                )
              : _buildInitialAvatar(date.partnerName),
        ),

        const SizedBox(width: 12),

        // Partner name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date.partnerName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _getStateBadgeText(),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Chat bubble icon (if messaging exists in app)
        // Per UI-3: Only show if app has messaging
        // TODO: Add chat bubble if messaging feature exists
      ],
    );
  }

  Widget _buildInitialAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      color: AppColors.primaryOrangeLight,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    // Per UI-3: Use state-only fallback text since DateSummary lacks
    // deposit status, per-round info, and rankings
    final (pillText, tone) = _getStatePill();

    return DateStatusPill(
      text: pillText,
      tone: tone,
    );
  }

  String _getStateBadgeText() {
    switch (date.state) {
      case DateState.awaitingAvailability:
        return 'Planning date';
      case DateState.awaitingDeposit:
        return 'Awaiting commitment';
      case DateState.awaitingVenueRanking:
        return 'Choosing venue';
      case DateState.venueAssigned:
      case DateState.venueConfirmationPending:
        return 'Booking in progress';
      case DateState.booked:
        return 'Booked';
      case DateState.awaitingPresenceConfirmation:
        return 'Confirm attendance';
      case DateState.ready:
        return 'Confirmed';
      case DateState.completed:
        return 'Completed';
      case DateState.cancelled:
        return 'Cancelled';
      case DateState.expired:
        return 'Expired';
    }
  }

  (String, String) _getStatePill() {
    // State-only pill text (action row for each acting state)
    // Per UI-3: The detail screen will refine this with actual status
    switch (date.state) {
      case DateState.awaitingAvailability:
        return ('Pick your times', 'action');

      case DateState.awaitingDeposit:
        return ('Commit with deposit', 'action');

      case DateState.awaitingVenueRanking:
        return ('Rank venues', 'action');

      case DateState.venueAssigned:
      case DateState.venueConfirmationPending:
        return ('Booking your spot', 'waiting');

      case DateState.booked:
        return ('Booked. Confirm 24h before', 'neutral');

      case DateState.awaitingPresenceConfirmation:
        return ('Confirm you\'re coming', 'action');

      case DateState.ready:
        return ('You\'re both confirmed', 'success');

      case DateState.completed:
        return ('Completed', 'neutral');

      case DateState.cancelled:
        return ('Cancelled', 'muted');

      case DateState.expired:
        return ('Expired', 'muted');
    }
  }
}
