import 'dart:async';
import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_formats.dart';

/// Countdown timer for date deadlines
///
/// Per UI-1: Shows "2d 3h left", "5h 12m left", "Under an hour"
/// Ticks once a minute, not every second
/// When passed, shows "Expired, refreshing" and triggers refetch callback
class DeadlineCountdown extends StatefulWidget {
  final DateTime? deadline;
  final VoidCallback? onExpired;

  const DeadlineCountdown({
    super.key,
    this.deadline,
    this.onExpired,
  });

  @override
  State<DeadlineCountdown> createState() => _DeadlineCountdownState();
}

class _DeadlineCountdownState extends State<DeadlineCountdown> {
  Timer? _timer;
  String _displayText = '';
  bool _hasExpired = false;

  @override
  void initState() {
    super.initState();
    // Compute initial display text directly without setState
    if (widget.deadline != null) {
      _displayText = DateFormats.formatTimeRemaining(widget.deadline!);
      final expired = widget.deadline!.isBefore(DateTime.now());
      if (expired) {
        _hasExpired = true;
        // Schedule expired callback after current frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onExpired?.call();
          }
        });
      }
    }
    _startTimer();
  }

  @override
  void didUpdateWidget(DeadlineCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) {
      _hasExpired = false;
      _updateDisplay();
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    // Tick every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateDisplay();
    });
  }

  void _restartTimer() {
    _timer?.cancel();
    _startTimer();
  }

  void _updateDisplay() {
    if (widget.deadline == null) {
      setState(() {
        _displayText = '';
      });
      return;
    }

    final text = DateFormats.formatTimeRemaining(widget.deadline!);
    final expired = widget.deadline!.isBefore(DateTime.now());

    setState(() {
      _displayText = text;
    });

    // Trigger onExpired callback after setState completes
    if (expired && !_hasExpired) {
      _hasExpired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onExpired?.call();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deadline == null || _displayText.isEmpty) {
      return const SizedBox.shrink();
    }

    final isExpired = _displayText == 'Expired';
    final isUrgent = widget.deadline != null &&
        widget.deadline!.difference(DateTime.now()).inHours < 24;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time,
          size: 16,
          color: isExpired
              ? AppColors.error
              : isUrgent
                  ? AppColors.warning
                  : AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          isExpired ? 'Expired, refreshing' : _displayText,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isExpired
                ? AppColors.error
                : isUrgent
                    ? AppColors.warning
                    : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
