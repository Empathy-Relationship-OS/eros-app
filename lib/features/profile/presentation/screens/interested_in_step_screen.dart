import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/features/match_preferences/domain/interested_in_suggestion.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/interested_in_screen.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';

/// The onboarding step after gender: who the user is interested in (RFC-007 §4.9).
///
/// The user doesn't exist on the server yet, so the choice goes into the draft, and the
/// submission flow saves it once the profile is created. The first time, the suggestion is
/// worked out on the device from the draft's gender and orientation. Orientation is asked later
/// in the flow, so normally nothing is pre-ticked.
class InterestedInStepScreen extends ConsumerWidget {
  const InterestedInStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.read(profileCreationProvider);
    final initial = draft.interestedIn ??
        suggestedInterestedIn(draft.gender, draft.sexualOrientation?.field);

    return InterestedInScreen(
      initialSelection: initial,
      header: const ProfileProgressBar(
        currentStep: ProfileCreationConstants.basicInfoStepInterestedIn,
        totalSteps: ProfileCreationConstants.basicInfoTotalSteps,
      ),
      onContinue: (genders) async {
        final draft = ref.read(profileCreationProvider).copyWith(interestedIn: genders);
        await ref.read(profileCreationProvider.notifier).updateDraft(draft);
        if (context.mounted) Navigator.pushNamed(context, '/profile-creation/dob');
      },
    );
  }
}
