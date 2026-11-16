import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/core/time/server_clock.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/availability_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_list_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/date_verification_provider.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:eros_app/features/dates/presentation/widgets/cancel_date_dialog.dart';
import 'package:eros_app/features/dates/presentation/widgets/error_state_widget.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_verification_wall.dart';
import 'package:eros_app/features/dates/presentation/screens/deposit_sheet.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:intl/intl.dart';

/// UI-5: Availability picker screen
///
/// Full-screen route for selecting available time slots.
/// - Horizontal day strip covering [now+48h, now+21d]
/// - Vertical slot list per selected day (30-min intervals)
/// - Tap cycle: unmarked → Available → Busy → unmarked
/// - Partner availability shown side-by-side with colored indicators
/// - Requires 3+ Available slots to submit
/// - Blocked slots can't be marked; tapping one shows the server's reason
/// - A day where every slot is ACTIVITY_CLOSED collapses to one line
class AvailabilityPickerScreen extends ConsumerStatefulWidget {
  final String dateId;
  final int round;

  const AvailabilityPickerScreen({
    super.key,
    required this.dateId,
    required this.round,
  });

  @override
  ConsumerState<AvailabilityPickerScreen> createState() =>
      _AvailabilityPickerScreenState();
}

class _AvailabilityPickerScreenState
    extends ConsumerState<AvailabilityPickerScreen> {
  late DateTime _selectedDay;
  late DateTime _windowStart;
  late DateTime _windowEnd;
  bool _showEarlierSlots = false;
  bool _isLoadingCancelDialog = false;
  bool _isSubmitting = false;

  // Local state: Map<slotStart UTC, SlotAvailability?>
  // null = unmarked, AVAILABLE = Free, UNAVAILABLE = Busy
  final Map<DateTime, SlotAvailability?> _marks = {};

  @override
  void initState() {
    super.initState();
    // Server time, so the slot horizon matches the backend's
    // [MIN_LEAD_HOURS, MAX_HORIZON_DAYS] window even if the device clock is off
    // or the dev clock has been advanced.
    final now = ServerClock.instance.now();
    _windowStart =
        now.add(const Duration(hours: DatesConstants.minLeadHours));
    _windowEnd = now.add(const Duration(days: DatesConstants.horizonDays));

    // Select first day in window (local date)
    _selectedDay = _windowStart.toLocal();
    _selectedDay = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
  }

  @override
  Widget build(BuildContext context) {
    final availabilityAsync = ref.watch(availabilityProvider(widget.dateId));
    // Opened while the wall is up (a deep link, a stale screen): the wall, not the grid.
    final walled = ref.watch(dateVerificationWallProvider(widget.dateId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => _handleClose(context),
        ),
        title: const Text(DatesCopy.availabilityTitle),
      ),
      body: walled ? _buildVerificationWall(context) : availabilityAsync.when(
        data: (availability) {
          // Load mySlots into _marks on first build (excluding blocked slots)
          if (_marks.isEmpty && availability.mySlots.isNotEmpty) {
            for (final slot in availability.mySlots) {
              _marks[slot.slotStart] = slot.availability;
            }
          }
          // Also covers a refresh: a mark on a newly blocked slot must not be counted or sent
          _marks.removeWhere((slot, _) => availability.blockedByStart.containsKey(slot));

          return Column(
            children: [
              // The kind of date and its length, then what to do
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DatesCopy.availabilityDateSummary(
                        availability.activityName,
                        availability.durationMinutes,
                      ),
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DatesCopy.availabilitySubtitle(widget.round),
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              // Partner legend: the order of the two marks on each row
              if (availability.partnerSlots.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppColors.surfaceMuted,
                  child: Row(
                    children: [
                      _buildLegendItem(context, 'You'),
                      const SizedBox(width: 20),
                      // Would come from dateDetail.partnerName
                      _buildLegendItem(context, 'Partner'),
                    ],
                  ),
                ),

              // Day strip
              _buildDayStrip(),

              // Slot list
              Expanded(
                child: _buildSlotList(availability),
              ),

              // Footer
              _buildFooter(context),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorStateWidget(
          error: error,
          onRetry: () => ref.refresh(availabilityProvider(widget.dateId)),
          onGoBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// In place of the grid while the viewer must verify. Cancel stays (RFC-008 D-6).
  Widget _buildVerificationWall(BuildContext context) {
    return SingleChildScrollView(
      child: DateVerificationWallBody(
        dateId: widget.dateId,
        onCancel: () => _showCancelDialog(context),
      ),
    );
  }

  /// One entry of the legend: a "free" mark and whose it is.
  Widget _buildLegendItem(BuildContext context, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: AppColors.white, size: 12),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }

  Widget _buildDayStrip() {
    final days = _generateDayChips();
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = _isSameDay(day, _selectedDay);
          final hasMark = _dayHasMarks(day);

          // The selected day is a coral fill, so its text is ink, never white
          return Semantics(
            selected: isSelected,
            child: Material(
              color: isSelected ? AppColors.primary : AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => setState(() => _selectedDay = day),
                child: SizedBox(
                  width: 56,
                  height: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('E').format(day).substring(0, 3),
                        style: textTheme.labelSmall?.copyWith(
                          color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        day.day.toString(),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                      if (hasMark)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.ink : AppColors.primaryDeep,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotList(AvailabilityView availability) {
    if (_isDayClosed(availability)) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            DatesCopy.availabilityDayClosed(availability.activityName),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final slots = _generateSlots();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: slots.length + 1, // +1 for Earlier expander
      itemBuilder: (context, index) {
        if (index == 0) {
          // Earlier expander
          return _buildExpander(
            label: 'Earlier',
            isExpanded: _showEarlierSlots,
            onTap: () => setState(() => _showEarlierSlots = !_showEarlierSlots),
          );
        }

        final slot = slots[index - 1];
        return _buildSlotRow(slot, availability);
      },
    );
  }

  Widget _buildExpander({
    required String label,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.input),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded ? Icons.expand_more : Icons.expand_less,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotRow(DateTime slotStart, AvailabilityView availability) {
    final timeLabel = DateFormat('HH:mm').format(slotStart.toLocal());

    final myMark = _marks[slotStart];
    final partnerMark = availability.partnerSlots
        .where((s) => s.slotStart.isAtSameMomentAs(slotStart))
        .firstOrNull
        ?.availability;

    // Check if this slot is blocked. ACTIVITY_CLOSED is lighter than other blocks: it's just
    // outside the venues' hours, while an unknown code is treated like ANOTHER_DATE.
    final blockedSlot = availability.blockedByStart[slotStart];
    final isBlocked = blockedSlot != null;
    final isClosed = blockedSlot?.code == BlockedSlotCode.activityClosed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        hint: blockedSlot?.reason,
        child: InkWell(
          onTap: isBlocked
              ? () => _showBlockedReason(blockedSlot)
              : () => _cycleSlot(slotStart),
          onLongPress: isBlocked
              ? () => _showBlockedReason(blockedSlot)
              : () => _fillRestOfDay(slotStart, myMark, availability),
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: isClosed
                  ? Colors.transparent
                  : _getSlotBackgroundColor(myMark, isBlocked: isBlocked),
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: isBlocked && !isClosed ? Border.all(color: AppColors.border) : null,
            ),
            child: Row(
              children: [
                // Time label
                Text(
                  timeLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: isClosed ? FontWeight.w400 : FontWeight.w600,
                        color: _getSlotTextColor(myMark, isBlocked: isBlocked),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),

                const Spacer(),

                // My availability indicator
                if (isClosed)
                  const SizedBox(width: 32, height: 32)
                else
                  _buildAvailabilityIndicator(myMark, isPartner: false, isBlocked: isBlocked),

                // Partner availability indicator (if exists)
                if (availability.partnerSlots.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  _buildAvailabilityIndicator(partnerMark, isPartner: true, isBlocked: false),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final freeCount = _marks.values.where((v) => v == SlotAvailability.available).length;
    final totalMarks = _marks.values.where((v) => v != null).length;
    final canSubmit = freeCount >= 3;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DatesCopy.availabilityCounter(freeCount, 3),
              style: textTheme.labelLarge?.copyWith(
                color: canSubmit ? AppColors.success : AppColors.textSecondary,
              ),
            ),
            if (totalMarks > 150)
              Text(DatesCopy.availabilityMarkedCount(totalMarks), style: textTheme.bodySmall),
            const SizedBox(height: 12),
            AppButton(
              label: DatesCopy.availabilitySendButton,
              loading: _isSubmitting,
              onPressed: canSubmit ? _handleSubmit : null,
            ),
            const SizedBox(height: 4),
            // Cancel button
            Center(
              child: TextButton(
                onPressed: () => _showCancelDialog(context),
                style: AppTheme.quietLink,
                child: const Text('Cancel this date'),
              ),
            ),
          ],
        ),
      ),
    );
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
          partnerName: dateDetail.partnerName,
          currentUid: currentUid,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load date details: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
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

  // ==================== HELPERS ====================

  Color _getSlotBackgroundColor(SlotAvailability? mark, {bool isBlocked = false}) {
    if (isBlocked) {
      return AppColors.surfaceMuted;
    } else if (mark == SlotAvailability.available) {
      return _tintOnCard(AppColors.success, 0.12);
    } else if (mark == SlotAvailability.unavailable) {
      return _tintOnCard(AppColors.error, 0.1);
    } else {
      return AppColors.cardBackground;
    }
  }

  /// A state colour washed over the card colour. A see-through tint would pick up the cream
  /// page behind the row and turn grey.
  Color _tintOnCard(Color color, double alpha) =>
      Color.alphaBlend(color.withValues(alpha: alpha), AppColors.cardBackground);

  Color _getSlotTextColor(SlotAvailability? mark, {bool isBlocked = false}) {
    if (isBlocked) {
      return AppColors.textTertiary; // Greyed out text for blocked slots
    }
    return AppColors.textPrimary;
  }

  Widget _buildAvailabilityIndicator(SlotAvailability? mark, {required bool isPartner, bool isBlocked = false}) {
    // A blocked slot on the viewer's side: a muted cross
    if (isBlocked && !isPartner) {
      return _buildMark(AppColors.border, Icons.close);
    }
    if (mark == SlotAvailability.available) {
      return _buildMark(AppColors.success, Icons.check);
    }
    if (mark == SlotAvailability.unavailable) {
      return _buildMark(AppColors.error, Icons.close);
    }
    // Unmarked - show empty circle for user, nothing for partner
    if (isPartner) {
      return const SizedBox(width: 32, height: 32);
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border, width: 2),
        shape: BoxShape.circle,
      ),
    );
  }

  /// A filled circle with a white icon: the mark at the end of a slot row.
  Widget _buildMark(Color color, IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: AppColors.white, size: 18),
    );
  }

  List<DateTime> _generateDayChips() {
    final days = <DateTime>[];
    var current = DateTime(
      _windowStart.toLocal().year,
      _windowStart.toLocal().month,
      _windowStart.toLocal().day,
    );
    final end = DateTime(
      _windowEnd.toLocal().year,
      _windowEnd.toLocal().month,
      _windowEnd.toLocal().day,
    );

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }

    return days;
  }

  List<DateTime> _generateSlots({bool includeEarlier = false}) {
    final slots = <DateTime>[];
    final dayStart = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    ).toUtc();

    // Default: 15:00 (3pm) to 22:00 (10pm)
    // Earlier: 09:00 (9am) to 14:30
    // Absolute limits: 09:00 to 22:00 (9am to 10pm, last slot at 22:00)
    final int startHour = includeEarlier || _showEarlierSlots ? 9 : 15;
    final int endHour = 22; // Always ends at 22:00 (10pm)

    for (int hour = startHour; hour <= endHour; hour++) {
      for (int minute in [0, 30]) {
        // Skip 22:30 - last slot should be 22:00
        if (hour == 22 && minute == 30) continue;

        final slot = dayStart.add(Duration(hours: hour, minutes: minute));

        // Skip if before windowStart or after windowEnd
        if (slot.isBefore(_windowStart) || slot.isAfter(_windowEnd)) {
          continue;
        }

        slots.add(slot);
      }
    }

    return slots;
  }

  /// Whether every slot of the selected day is ACTIVITY_CLOSED. Earlier slots count even when
  /// hidden, or a morning coffee would disappear behind the collapsed line.
  bool _isDayClosed(AvailabilityView availability) {
    final slots = _generateSlots(includeEarlier: true);
    return slots.isNotEmpty &&
        slots.every((slot) =>
            availability.blockedByStart[slot]?.code == BlockedSlotCode.activityClosed);
  }

  void _showBlockedReason(BlockedSlotDto blockedSlot) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(blockedSlot.reason)));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _dayHasMarks(DateTime day) {
    return _marks.keys.any((slot) {
      final local = slot.toLocal();
      return _isSameDay(local, day) && _marks[slot] != null;
    });
  }

  void _cycleSlot(DateTime slotStart) {
    setState(() {
      final current = _marks[slotStart];
      if (current == null) {
        _marks[slotStart] = SlotAvailability.available;
      } else if (current == SlotAvailability.available) {
        _marks[slotStart] = SlotAvailability.unavailable;
      } else {
        _marks[slotStart] = null;
      }
    });
  }

  void _fillRestOfDay(
    DateTime slotStart,
    SlotAvailability? currentMark,
    AvailabilityView availability,
  ) {
    // Determine target mark: if currently unmarked, fill with Free; else toggle
    final targetMark = currentMark == null
        ? SlotAvailability.available
        : (currentMark == SlotAvailability.available
            ? SlotAvailability.unavailable
            : SlotAvailability.available);

    final daySlots = _generateSlots()
        .where((s) => !s.isBefore(slotStart))
        .where((s) => !availability.blockedByStart.containsKey(s))
        .toList();

    setState(() {
      for (final slot in daySlots) {
        _marks[slot] = targetMark;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Filled ${daySlots.length} slots'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              for (final slot in daySlots) {
                _marks[slot] = currentMark;
              }
            });
          },
        ),
      ),
    );
  }

  void _handleClose(BuildContext context) {
    final hasChanges = _marks.isNotEmpty;
    if (hasChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(DatesCopy.availabilityDiscardConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close screen
              },
              child: const Text('Discard'),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Sends the marks once: a second tap while the first is in flight does nothing, so the
  /// screen can't be popped twice.
  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await _submit();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submit() async {
    final availabilityAsync = ref.read(availabilityProvider(widget.dateId));
    final availability = availabilityAsync.value;
    if (availability == null) return;

    // Build payload: current marks + NO_PREFERENCE for cleared slots
    final slots = <AvailabilitySlotSubmission>[];
    final existingSlots = Set<DateTime>.from(
        availability.mySlots.map((s) => s.slotStart));

    // Add all current marks
    for (final entry in _marks.entries) {
      if (entry.value != null) {
        slots.add(AvailabilitySlotSubmission(
          slotStart: entry.key,
          availability: entry.value!,
        ));
      }
    }

    // Add NO_PREFERENCE for slots that were marked but are now cleared
    for (final existing in existingSlots) {
      if (!_marks.containsKey(existing) || _marks[existing] == null) {
        slots.add(AvailabilitySlotSubmission(
          slotStart: existing,
          availability: SlotAvailability.noPreference,
        ));
      }
    }

    final request = SubmitAvailabilityRequest(slots);

    try {
      final notifier = AvailabilityNotifier(
        ref.read(datesRepositoryProvider),
        widget.dateId,
      );

      await notifier.submitAvailability(request);

      if (!mounted) return;

      // Refetch date detail to check what state we're in now
      final dateDetail = await ref.read(datesRepositoryProvider).getDateById(widget.dateId);

      if (!mounted) return;

      if (dateDetail == null) {
        // Date not found, just pop
        Navigator.of(context).pop();
        return;
      }

      // Handle different state transitions per UI-5 spec
      if (dateDetail.state == DateState.awaitingDeposit) {
        // Time found! Pop and open deposit sheet with celebratory header
        Navigator.of(context).pop();
        _showDepositSheet(context, dateDetail);
      } else if (dateDetail.availabilityRound > widget.round) {
        // Round incremented - no overlap
        _showNoOverlapDialog();
      } else if (dateDetail.state == DateState.expired) {
        // Date expired (e.g., after round 2 failure)
        Navigator.of(context).pop();
      } else {
        // Still AWAITING_AVAILABILITY - waiting on partner
        Navigator.of(context).pop();
      }
    } on VerificationRequiredFailure {
      if (!mounted) return;
      // The wall replaces the grid, no error toast (VF-F4).
      unawaited(ref.read(dateVerificationRaisedProvider(widget.dateId).notifier).raise());
    } on ValidationException catch (e) {
      if (!mounted) return;
      // Usually a slot blocked since this grid loaded (a race): refresh, and the build drops it
      ref.invalidate(availabilityProvider(widget.dateId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
        ),
      );
    } on ConflictException {
      if (!mounted) return;
      // The date moved on while the picker was open, usually because it expired (RFC-005 D-30).
      // The detail screen refetches when the picker closes, but the dates list doesn't.
      ref.read(activeDatesProvider.notifier).refresh();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showDepositSheet(BuildContext context, DateDetail dateDetail) {
    final currentUid = ref.read(authServiceProvider).currentUser?.uid ?? '';

    // Format agreed time range
    String agreedTimeRange = 'Time agreed';
    if (dateDetail.scheduledStart != null) {
      final formatter = DateFormat('EEE d MMM, HH:mm');
      final start = formatter.format(dateDetail.scheduledStart!.toLocal());
      final end = DateFormat('HH:mm').format(dateDetail.endTime!.toLocal());
      agreedTimeRange = '$start - $end';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DepositSheet(
        dateDetail: dateDetail,
        currentUid: currentUid,
        agreedTimeRange: agreedTimeRange,
      ),
    );
  }

  void _showNoOverlapDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(DatesCopy.availabilityNoOverlapTitle),
        content: const Text(DatesCopy.availabilityNoOverlapBody),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Clear marks and stay on screen
              setState(() {
                _marks.clear();
              });
            },
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
