import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/section_complete_template.dart';

/// Screen shown after basic info is complete
/// Shows progress and next steps (preferences, interests, Q&A, photos)
class BasicInfoCompleteScreen extends ConsumerWidget {
  const BasicInfoCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(profileCreationProvider);

    return SectionCompleteTemplate(
      headerIcon: Icons.check_circle,
      title: 'Great start, ${draft.firstName}!',
      description:
          'You\'ve completed the basic information.\nNext, we\'ll help you create your full profile.',
      progressItems: const [
        ProgressItem(
          icon: Icons.check_circle,
          title: 'Basic Info',
          status: 'Complete',
          isComplete: true,
        ),
        ProgressItem(
          icon: Icons.favorite_border,
          title: 'Preferences',
          status: 'Next',
          isComplete: false,
        ),
        ProgressItem(
          icon: Icons.interests,
          title: 'Interests & Personality',
          status: 'Coming up',
          isComplete: false,
        ),
        ProgressItem(
          icon: Icons.question_answer,
          title: 'Q&A',
          status: 'Coming up',
          isComplete: false,
        ),
        ProgressItem(
          icon: Icons.photo_camera,
          title: 'Photos',
          status: 'Final step',
          isComplete: false,
        ),
      ],
      buttonText: 'Continue to Preferences',
      onContinue: () {
        Navigator.pushNamed(context, '/profile-creation/preferences/date-intentions');
      },
    );
  }
}
