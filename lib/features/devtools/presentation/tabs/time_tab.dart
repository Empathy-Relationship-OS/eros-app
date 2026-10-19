import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/time/server_clock_provider.dart';
import '../../data/devtools_api.dart';
import '../../data/models/devtools_models.dart';
import '../dev_menu_screen.dart' show formatOffset;
import '../time_travel.dart';

/// Time tab of the dev menu (DT-F4): moves the backend clock.
///
/// Shows the server and real time from `GET /dev/clock`, and moves the clock
/// forward with quick buttons, a custom amount or a date and time. The clock
/// only moves forward, apart from reset (RFC-003 D-4).
///
/// After every change it invalidates [timeSensitiveProviders] so open
/// screens refetch. `ServerClock` and the "time shifted" banner are updated
/// by the response headers, through the dev client's `ServerTimeInterceptor`.
class TimeTab extends ConsumerStatefulWidget {
  const TimeTab({super.key});

  /// Hours offered as one-tap buttons.
  static const List<int> quickHours = [1, 6, 24, 25, 48];

  @override
  ConsumerState<TimeTab> createState() => _TimeTabState();
}

class _TimeTabState extends ConsumerState<TimeTab> {
  final _days = TextEditingController();
  final _hours = TextEditingController();
  final _minutes = TextEditingController();

  ClockInfo? _clock;
  Object? _loadError;
  String? _customError;
  bool _busy = false;

  DevtoolsApi get _api => ref.read(devtoolsApiProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _days.dispose();
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final clock = await _api.getClock();
      if (mounted) {
        setState(() {
          _clock = clock;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  void _retryLoad() {
    setState(() => _loadError = null);
    _load();
  }

  /// Runs one clock change, then refreshes everything that depends on time.
  ///
  /// Every clock endpoint returns the new `ClockDTO`, so the readout is
  /// updated from that response rather than a second `GET /dev/clock`.
  Future<void> _change(Future<ClockInfo> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final clock = await action();
      if (!mounted) return;
      setState(() => _clock = clock);
      invalidateTimeSensitiveState(ref);
      _snack('Server time is now ${formatLocalTimeShort(clock.serverTime)}');
    } catch (e) {
      if (mounted) _snack(_message(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _advanceCustom() {
    final days = int.tryParse(_days.text.trim()) ?? 0;
    final hours = int.tryParse(_hours.text.trim()) ?? 0;
    final minutes = int.tryParse(_minutes.text.trim()) ?? 0;
    final total = Duration(days: days, hours: hours, minutes: minutes);
    if (total <= Duration.zero) {
      setState(() => _customError = 'Enter a positive amount of time.');
      return;
    }
    setState(() => _customError = null);
    _change(
      () => _api.advanceClock(days: days, hours: hours, minutes: minutes),
    );
  }

  Future<void> _jumpTo() async {
    final now = ref.read(serverClockProvider).now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      // Past days are disabled: the clock only moves forward (D-4).
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Jump to date',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      helpText: 'Jump to time',
    );
    if (time == null || !mounted) return;

    final target = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    // The time picker cannot disable past times, so check here. The backend
    // rejects them anyway.
    if (!target.isAfter(ref.read(serverClockProvider).now())) {
      _snack('Pick a time after the current server time.', error: true);
      return;
    }
    await _change(() => _api.advanceClockTo(target.toUtc()));
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset clock?'),
        content: const Text(
          'Puts the server clock back to real time for everyone using this '
          'backend. Data created while time was shifted keeps its future '
          'timestamps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _change(() => _api.resetClock());
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.error : null,
        ),
      );
  }

  String _message(Object e) => e is ApiException ? e.message : e.toString();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sectionStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final enabled = !_busy;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ClockReadout(clock: _clock, error: _loadError, onRetry: _retryLoad),
        const SizedBox(height: 24),
        Text('Advance', style: sectionStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final h in TimeTab.quickHours)
              OutlinedButton(
                onPressed: enabled
                    ? () => _change(() => _api.advanceClock(hours: h))
                    : null,
                child: Text('+${h}h'),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Custom', style: sectionStyle),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NumberField(controller: _days, label: 'Days', fieldKey: 'days'),
            const SizedBox(width: 8),
            _NumberField(controller: _hours, label: 'Hours', fieldKey: 'hours'),
            const SizedBox(width: 8),
            _NumberField(
              controller: _minutes,
              label: 'Minutes',
              fieldKey: 'minutes',
            ),
          ],
        ),
        if (_customError != null) ...[
          const SizedBox(height: 4),
          Text(
            _customError!,
            key: const Key('timeTabCustomError'),
            style: textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const Key('timeTabCustomAdvance'),
            onPressed: enabled ? _advanceCustom : null,
            child: const Text('Advance'),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: enabled ? _jumpTo : null,
              icon: const Icon(Icons.event),
              label: const Text('Jump to...'),
            ),
            OutlinedButton.icon(
              onPressed: enabled ? _confirmReset : null,
              icon: const Icon(Icons.restore),
              label: const Text('Reset clock'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Moves time for everyone using this backend.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }
}

/// Server time, real time and offset.
class _ClockReadout extends StatelessWidget {
  final ClockInfo? clock;
  final Object? error;
  final VoidCallback onRetry;

  const _ClockReadout({
    required this.clock,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    final value = textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500);
    final c = clock;

    if (c == null && error != null) {
      final e = error;
      return Row(
        children: [
          Expanded(
            child: Text(
              'Could not read the clock: '
              '${e is ApiException ? e.message : e.toString()}',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
    }
    if (c == null) return const LinearProgressIndicator();

    Widget row(String name, String text, String key) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: label),
          Text(text, key: Key(key), style: value),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(
          'Server time',
          formatLocalTimeWithZone(c.serverTime),
          'timeTabServerTime',
        ),
        row(
          'Real time',
          formatLocalTimeWithZone(c.realTime),
          'timeTabRealTime',
        ),
        row('Offset', formatOffset(c.offset), 'timeTabOffset'),
      ],
    );
  }
}

/// One digits-only field of the custom advance form. Empty counts as 0.
class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String fieldKey;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextField(
        key: Key('timeTabCustom_$fieldKey'),
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          hintText: '0',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
