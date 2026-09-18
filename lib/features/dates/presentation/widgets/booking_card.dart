import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_formats.dart';
import 'package:eros_app/features/dates/presentation/providers/presence_provider.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as calendar;

final datesRepositoryProvider = Provider<DatesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DatesRepository(apiClient);
});

/// UI-8: Booking card and presence confirmation widget
///
/// Embedded in DateDetailScreen CTA area for states:
/// - VENUE_ASSIGNED, VENUE_CONFIRMATION_PENDING: booking card with "confirming" message
/// - BOOKED: booking card with ref, directions, add to calendar
/// - AWAITING_PRESENCE_CONFIRMATION: booking card + presence status + confirm button
/// - READY: booking card + success pill
class BookingCard extends ConsumerStatefulWidget {
  final DateDetail dateDetail;
  final String currentUid;

  const BookingCard({
    super.key,
    required this.dateDetail,
    required this.currentUid,
  });

  @override
  ConsumerState<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<BookingCard> {
  bool _isConfirming = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.dateDetail.state;
    final isConfirming = state == DateState.venueAssigned ||
        state == DateState.venueConfirmationPending;
    final showPresence = state == DateState.awaitingPresenceConfirmation;
    final isReady = state == DateState.ready;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textTertiary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confirming message (VENUE_ASSIGNED, VENUE_CONFIRMATION_PENDING)
          if (isConfirming)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      DatesCopy.bookingConfirmingCaption,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Venue name
          Text(
            widget.dateDetail.venueName ?? 'Venue TBD',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Address
          if (widget.dateDetail.venueAddress != null)
            Text(
              widget.dateDetail.venueAddress!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 8),

          // Time range
          if (widget.dateDetail.scheduledStart != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormats.formatRange(widget.dateDetail.scheduledStart!),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Booking reference (hidden when confirming)
          if (!isConfirming && widget.dateDetail.bookingReference != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    DatesCopy.bookingRefLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.dateDetail.bookingReference!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Action buttons row
          if (!isConfirming)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openDirections,
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text(DatesCopy.bookingDirections),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryOrange,
                      side: const BorderSide(color: AppColors.primaryOrange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addToCalendar,
                    icon: const Icon(Icons.event, size: 18),
                    label: const Text(DatesCopy.bookingAddToCalendar),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryOrange,
                      side: const BorderSide(color: AppColors.primaryOrange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // Presence confirmation section (AWAITING_PRESENCE_CONFIRMATION)
          if (showPresence) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.textTertiary, height: 1),
            const SizedBox(height: 16),
            _buildPresenceSection(),
          ],

          // Ready success pill (READY)
          if (isReady) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          DatesCopy.presenceBothConfirmed,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                        if (widget.dateDetail.venueName != null &&
                            widget.dateDetail.scheduledStart != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            DatesCopy.bookingConfirmedCaption(
                              widget.dateDetail.venueName!,
                              DateFormats.formatRange(
                                  widget.dateDetail.scheduledStart!),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresenceSection() {
    final presenceAsync = ref.watch(presenceProvider(widget.dateDetail.dateId.toString()));

    return presenceAsync.when(
      data: (presenceStatus) {
        final youConfirmed = presenceStatus?.me(widget.currentUid).confirmed ?? false;
        final partnerConfirmed = presenceStatus?.partner(widget.currentUid).confirmed ?? false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status rows
            _buildPresenceRow(
              DatesCopy.presenceYouLabel,
              youConfirmed,
            ),
            const SizedBox(height: 8),
            _buildPresenceRow(
              widget.dateDetail.partnerName(widget.currentUid),
              partnerConfirmed,
            ),

            // Confirm button or waiting message
            const SizedBox(height: 16),
            if (!youConfirmed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isConfirming ? null : _handleConfirmPresence,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.disabled,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isConfirming
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          DatesCopy.presenceButtonText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              )
            else
              Text(
                DatesCopy.presenceConfirmedWaiting(
                  widget.dateDetail.partnerName(widget.currentUid),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPresenceRow(String label, bool confirmed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        Row(
          children: [
            Text(
              confirmed
                  ? DatesCopy.presenceConfirmedStatus
                  : DatesCopy.presenceNotYet,
              style: TextStyle(
                fontSize: 13,
                color: confirmed ? AppColors.success : AppColors.textSecondary,
              ),
            ),
            if (confirmed) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 16,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _handleConfirmPresence() async {
    setState(() => _isConfirming = true);

    try {
      final notifier = PresenceNotifier(
        ref.read(datesRepositoryProvider),
        widget.dateDetail.dateId.toString(),
      );
      final presenceStatus = await notifier.confirmPresence();

      if (!mounted) return;

      setState(() => _isConfirming = false);

      // Show success toast
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(DatesCopy.presenceConfirmedWaiting(
            widget.dateDetail.partnerName(widget.currentUid),
          )),
          backgroundColor: AppColors.success,
        ),
      );

      // If both confirmed, the parent will refetch and show READY state
      if (presenceStatus.me(widget.currentUid).confirmed &&
          presenceStatus.partner(widget.currentUid).confirmed) {
        // Trigger parent refetch
        // This is handled by the detail screen's refetch mechanism
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openDirections() async {
    final address = widget.dateDetail.venueAddress;
    if (address == null) return;

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

  Future<void> _addToCalendar() async {
    final scheduledStart = widget.dateDetail.scheduledStart;
    if (scheduledStart == null) return;

    final scheduledEnd = scheduledStart.add(const Duration(hours: 2));

    final event = calendar.Event(
      title: DatesCopy.bookingCalendarTitle(
        widget.dateDetail.partnerName(widget.currentUid),
        widget.dateDetail.venueName ?? 'Date',
      ),
      description: 'Date with ${widget.dateDetail.partnerName(widget.currentUid)}',
      location: widget.dateDetail.venueAddress,
      startDate: scheduledStart,
      endDate: scheduledEnd,
    );

    await calendar.Add2Calendar.addEvent2Cal(event);
  }
}
