import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/profile/presentation/widgets/section_complete_template.dart';

/// Screen shown after preferences section is complete
class PreferencesCompleteScreen extends ConsumerWidget {
  const PreferencesCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCompleteTemplate(
      headerIcon: Icons.favorite,
      title: 'Looking good!',
      description:
          'You\'ve shared your preferences.\nNext, let\'s add your interests and personality.',
      progressItems: const [
        ProgressItem(
          icon: Icons.check_circle,
          title: 'Basic Info',
          status: 'Complete',
          isComplete: true,
        ),
        ProgressItem(
          icon: Icons.check_circle,
          title: 'Preferences',
          status: 'Complete',
          isComplete: true,
        ),
        ProgressItem(
          icon: Icons.interests,
          title: 'Interests',
          status: 'Next (5-10 required)',
          isComplete: false,
        ),
        ProgressItem(
          icon: Icons.psychology,
          title: 'Personality',
          status: 'Coming up (3-10 traits)',
          isComplete: false,
        ),
        ProgressItem(
          icon: Icons.check_circle_outline,
          title: 'Submit Profile',
          status: 'Final step',
          isComplete: false,
        ),
      ],
      buttonText: 'Continue to Interests',
      onContinue: () {
        Navigator.pushNamed(context, '/profile-creation/interests');
      },
    );
  }
}
