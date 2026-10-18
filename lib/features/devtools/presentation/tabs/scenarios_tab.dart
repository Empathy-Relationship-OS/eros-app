import 'package:flutter/material.dart';
import '../widgets/dev_tab_placeholder.dart';

/// Scenarios tab of the dev menu.
///
/// Placeholder: DT-F5 replaces this file with the real panel.
class ScenariosTab extends StatelessWidget {
  const ScenariosTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevTabPlaceholder(
      title: 'Scenarios',
      description: 'Put the backend into a named state with one call.',
      ticket: 'DT-F5',
    );
  }
}
