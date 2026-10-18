import 'package:flutter/material.dart';
import '../widgets/dev_tab_placeholder.dart';

/// Personas tab of the dev menu.
///
/// Placeholder: DT-F3 replaces this file with the real panel.
class PersonasTab extends StatelessWidget {
  const PersonasTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevTabPlaceholder(
      title: 'Personas',
      description: 'Sign in as a test user, create personas and reset dev data.',
      ticket: 'DT-F3',
    );
  }
}
