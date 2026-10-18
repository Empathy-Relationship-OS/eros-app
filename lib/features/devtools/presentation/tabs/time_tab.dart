import 'package:flutter/material.dart';
import '../widgets/dev_tab_placeholder.dart';

/// Time tab of the dev menu.
///
/// Placeholder: DT-F4 replaces this file with the real panel.
class TimeTab extends StatelessWidget {
  const TimeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevTabPlaceholder(
      title: 'Time',
      description: 'Move the backend clock forward or reset it.',
      ticket: 'DT-F4',
    );
  }
}
