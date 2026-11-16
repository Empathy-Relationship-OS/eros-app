import 'package:flutter/material.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/single_choice_editor.dart';

/// Education level selection screen
/// Matches screenshot: @screenshots/login/create-user/278ED7CB-8AA4-4990-A13B-1D0F12431AC6.png
class EducationScreen extends ConsumerStatefulWidget {
  const EducationScreen({super.key});

  @override
  ConsumerState<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends ConsumerState<EducationScreen> {
  EducationLevel? _selectedEducation;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(profileCreationProvider);
    if (draft.educationLevel != null) {
      setState(() {
        _selectedEducation = draft.educationLevel;
      });
    }
  }

  Future<void> _continue() async {
    if (_selectedEducation == null) return;

    final currentDraft = ref.read(profileCreationProvider);
    final updatedDraft = currentDraft.copyWith(educationLevel: _selectedEducation);
    await ref.read(profileCreationProvider.notifier).updateDraft(updatedDraft);

    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/phone');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileProgressBar(
                currentStep: ProfileCreationConstants.basicInfoStepEducation,
                totalSteps: ProfileCreationConstants.basicInfoTotalSteps,
              ),
              const SizedBox(height: 32),
              Text(
                'What\'s your education level?',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 32),
              SingleChoiceEditor<EducationLevel>(
                values: EducationLevel.values,
                selected: _selectedEducation,
                labelOf: (level) => level.displayName,
                onSelected: (level) => setState(() => _selectedEducation = level),
              ),
              const Spacer(),
              AppButton(
                label: 'Continue',
                onPressed: _selectedEducation != null ? _continue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
