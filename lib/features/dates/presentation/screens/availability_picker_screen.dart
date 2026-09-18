import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/availability_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:intl/intl.dart';

/// UI-5: Availability picker screen
///
/// Full-screen route for selecting available time slots.
/// - Horizontal day strip covering [now+48h, now+21d]
/// - Vertical slot list per selected day (30-min grid, 2-hour slots)
/// - Tap cycle: unmarked → Free → Busy → unmarked
/// - Partner overlay when available
/// - Requires 3+ Free slots to submit
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
  bool _showLaterSlots = false;

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: AppColors.cardBackground,
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DatesCopy.availabilityPartnerLegend(
                            'Partner', // Would come from dateDetail.partnerName
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
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
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Failed to load availability',
                style: TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(availabilityProvider(widget.dateId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayStrip() {
    final days = _generateDayChips();

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = _isSameDay(day, _selectedDay);
          final hasMark = _dayHasMarks(day);

          return GestureDetector(
            onTap: () => setState(() => _selectedDay = day),
            child: Container(
              width: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryOrange
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryOrange
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(day).substring(0, 1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day.day.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (hasMark) ...[
                    const SizedBox(height: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : AppColors.primaryOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
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
      itemCount: slots.length + 2, // +2 for Earlier/Later expanders
      itemBuilder: (context, index) {
        if (index == 0) {
          // Earlier expander
          return _buildExpander(
            label: 'Earlier',
            isExpanded: _showEarlierSlots,
            onTap: () => setState(() => _showEarlierSlots = !_showEarlierSlots),
          );
        }

        if (index == slots.length + 1) {
          // Later expander
          return _buildExpander(
            label: 'Later',
            isExpanded: _showLaterSlots,
            onTap: () => setState(() => _showLaterSlots = !_showLaterSlots),
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
                isExpanded ? Icons.expand_less : Icons.expand_more,
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
    final slotEnd = slotStart.add(const Duration(hours: 2));
    final timeLabel = '${DateFormat('HH:mm').format(slotStart.toLocal())} - ${DateFormat('HH:mm').format(slotEnd.toLocal())}';

    final myMark = _marks[slotStart];
    final partnerMark = availability.partnerSlots
        .where((s) => s.slotStart.isAtSameMomentAs(slotStart))
        .firstOrNull
        ?.availability;

    Color bgColor;
    Color textColor;
    IconData? icon;

    if (myMark == SlotAvailability.available) {
      bgColor = AppColors.primaryOrange;
      textColor = Colors.white;
      icon = Icons.check;
    } else if (myMark == SlotAvailability.unavailable) {
      bgColor = AppColors.textTertiary.withValues(alpha: 0.2);
      textColor = AppColors.textSecondary;
      icon = Icons.close;
    } else {
      bgColor = AppColors.cardBackground;
      textColor = AppColors.textPrimary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _cycleSlot(slotStart),
        onLongPress: () => _fillRestOfDay(slotStart, myMark),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: myMark != null
                  ? Colors.transparent
                  : AppColors.textTertiary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  timeLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              if (icon != null)
                Icon(icon, color: textColor, size: 20)
              else if (partnerMark == SlotAvailability.available)
                const Icon(Icons.favorite_border,
                    color: AppColors.textSecondary, size: 16)
              else if (partnerMark == SlotAvailability.unavailable)
                Container(
                  width: 16,
                  height: 2,
                  color: AppColors.textSecondary,
                ),
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
          ],
        ),
      ),
    );
  }

  // ==================== HELPERS ====================

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

    // Default: 08:00 to 22:00 (22:00 is last start, ends at 00:00 next day)
    final int startHour = _showEarlierSlots ? 0 : 8;
    final int endHour = _showLaterSlots ? 23 : 21; // 21 = 21:30 is last slot before 22:00

    for (int hour = startHour; hour <= endHour; hour++) {
      for (int minute in [0, 30]) {
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

      // After submit, refetch the date detail to see if state changed
      // For now, just pop - UI-4 detail screen will refetch on focus
      // TODO: Fetch detail here to detect time found vs no overlap vs expired
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
