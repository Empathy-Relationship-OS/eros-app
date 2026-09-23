import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/availability_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:eros_app/features/dates/presentation/widgets/cancel_date_dialog.dart';
import 'package:eros_app/features/dates/presentation/widgets/error_state_widget.dart';
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

  // Local state: Map<slotStart UTC, SlotAvailability?>
  // null = unmarked, AVAILABLE = Free, UNAVAILABLE = Busy
  final Map<DateTime, SlotAvailability?> _marks = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _windowStart = now.add(const Duration(hours: 48));
    _windowEnd = now.add(const Duration(days: 21));

    // Select first day in window (local date)
    _selectedDay = _windowStart.toLocal();
    _selectedDay = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
  }

  @override
  Widget build(BuildContext context) {
    final availabilityAsync = ref.watch(availabilityProvider(widget.dateId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => _handleClose(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              DatesCopy.availabilityTitle,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              DatesCopy.availabilitySubtitle(widget.round),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: AppColors.background,
      body: availabilityAsync.when(
        data: (availability) {
          // Load mySlots into _marks on first build
          if (_marks.isEmpty && availability.mySlots.isNotEmpty) {
            for (final slot in availability.mySlots) {
              _marks[slot.slotStart] = slot.availability;
            }
          }

          return Column(
            children: [
              // Partner legend
              if (availability.partnerSlots.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFFF5F5F5),
                  child: Row(
                    children: [
                      // Your availability
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'You',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      // Partner availability
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Partner', // Would come from dateDetail.partnerName
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildDayStrip() {
    final days = _generateDayChips();

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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

          return GestureDetector(
            onTap: () => setState(() => _selectedDay = day),
            child: Container(
              width: 56,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryOrange : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryOrange
                      : AppColors.textTertiary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('E').format(day).substring(0, 3),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    day.day.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      height: 1.0,
                    ),
                  ),
                  if (hasMark)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : AppColors.primaryOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotList(AvailabilityView availability) {
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
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
    );
  }

  Widget _buildSlotRow(DateTime slotStart, AvailabilityView availability) {
    final timeLabel = DateFormat('HH:mm').format(slotStart.toLocal());

    final myMark = _marks[slotStart];
    final partnerMark = availability.partnerSlots
        .where((s) => s.slotStart.isAtSameMomentAs(slotStart))
        .firstOrNull
        ?.availability;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => _cycleSlot(slotStart),
        onLongPress: () => _fillRestOfDay(slotStart, myMark),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: _getSlotBackgroundColor(myMark),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Time label
              Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _getSlotTextColor(myMark),
                ),
              ),

              const Spacer(),

              // My availability indicator
              _buildAvailabilityIndicator(myMark, isPartner: false),

              const SizedBox(width: 16),

              // Partner availability indicator (if exists)
              if (availability.partnerSlots.isNotEmpty)
                _buildAvailabilityIndicator(partnerMark, isPartner: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final freeCount = _marks.values.where((v) => v == SlotAvailability.available).length;
    final totalMarks = _marks.values.where((v) => v != null).length;
    final canSubmit = freeCount >= 3;

    return Container(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DatesCopy.availabilityCounter(freeCount, 3),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: canSubmit
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (totalMarks > 150)
                      Text(
                        DatesCopy.availabilityMarkedCount(totalMarks),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSubmit ? _handleSubmit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.disabled,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  DatesCopy.availabilitySendButton,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Cancel button
            Center(
              child: TextButton(
                onPressed: () => _showCancelDialog(context),
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

  Color _getSlotBackgroundColor(SlotAvailability? mark) {
    if (mark == SlotAvailability.available) {
      return const Color(0xFFE8F5E9); // Light green background
    } else if (mark == SlotAvailability.unavailable) {
      return const Color(0xFFFFEBEE); // Light red background
    } else {
      return Colors.white;
    }
  }

  Color _getSlotTextColor(SlotAvailability? mark) {
    return AppColors.textPrimary;
  }

  Widget _buildAvailabilityIndicator(SlotAvailability? mark, {required bool isPartner}) {
    if (mark == SlotAvailability.available) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isPartner ? AppColors.success : AppColors.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check,
          color: Colors.white,
          size: 18,
        ),
      );
    } else if (mark == SlotAvailability.unavailable) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isPartner ? AppColors.error : AppColors.error,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close,
          color: Colors.white,
          size: 18,
        ),
      );
    } else {
      // Unmarked - show empty circle for user, nothing for partner
      if (isPartner) {
        return const SizedBox(width: 32, height: 32);
      }
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.textTertiary.withValues(alpha: 0.3),
            width: 2,
          ),
          shape: BoxShape.circle,
        ),
      );
    }
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

  List<DateTime> _generateSlots() {
    final slots = <DateTime>[];
    final dayStart = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    ).toUtc();

    // Default: 15:00 (3pm) to 22:00 (10pm)
    // Earlier: 09:00 (9am) to 14:30
    // Absolute limits: 09:00 to 22:00 (9am to 10pm, last slot at 22:00)
    final int startHour = _showEarlierSlots ? 9 : 15;
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

  void _fillRestOfDay(DateTime slotStart, SlotAvailability? currentMark) {
    // Determine target mark: if currently unmarked, fill with Free; else toggle
    final targetMark = currentMark == null
        ? SlotAvailability.available
        : (currentMark == SlotAvailability.available
            ? SlotAvailability.unavailable
            : SlotAvailability.available);

    final daySlots = _generateSlots()
        .where((s) => !s.isBefore(slotStart))
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

  Future<void> _handleSubmit() async {
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
      final end = DateFormat('HH:mm').format(dateDetail.scheduledStart!.add(const Duration(hours: 2)).toLocal());
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
