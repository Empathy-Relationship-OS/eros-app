import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// Every string the dealbreaker widgets show (RFC-007 §4.2, §6.3).
abstract final class DealbreakerCopy {
  static const title = 'Dealbreaker';
  static const help = 'Only show me people who fit. Fewer people will see you too.';

  /// The editor's subtitle while the filter is a preference.
  static const preference = 'We\'ll show you people who fit first';

  /// The editor's subtitle while the filter is a dealbreaker.
  static const dealbreaker = 'We\'ll only show you people who fit';
}

/// The "Dealbreaker" switch under every editor except Interested in, with its one line of help
/// (RFC-007 §6.3). Controlled: the editor owns [value].
class DealbreakerSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const DealbreakerSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: const Key('dealbreaker-switch'),
      value: value,
      onChanged: onChanged,
      title: const Text(
        DealbreakerCopy.title,
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
      ),
      subtitle: Text(DealbreakerCopy.help, style: TextStyle(color: Colors.grey[700])),
      activeTrackColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}

/// The line under an editor's heading saying what the filter does now: "We'll show you people
/// who fit first", or "We'll only show you people who fit" when [dealbreaker] is on.
class DealbreakerSubtitle extends StatelessWidget {
  final bool dealbreaker;

  const DealbreakerSubtitle({super.key, required this.dealbreaker});

  @override
  Widget build(BuildContext context) {
    return Text(
      dealbreaker ? DealbreakerCopy.dealbreaker : DealbreakerCopy.preference,
      key: const Key('dealbreaker-subtitle'),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
    );
  }
}

/// The bottom of every editor with a switch: a divider, then [DealbreakerSwitch], kept in view
/// under the editor's scrolling content.
class DealbreakerFooter extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const DealbreakerFooter({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: DealbreakerSwitch(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}
