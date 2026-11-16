import 'package:flutter/material.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/displayable_choice_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';

/// Sexual orientation preference screen
class SexualOrientationScreen extends ConsumerStatefulWidget {
  const SexualOrientationScreen({super.key});

  @override
  ConsumerState<SexualOrientationScreen> createState() =>
      _SexualOrientationScreenState();
}

class _SexualOrientationScreenState
    extends ConsumerState<SexualOrientationScreen> {
  SexualOrientation? _selected;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(profileCreationProvider);
    if (draft.sexualOrientation != null) {
      setState(() {
        _selected = draft.sexualOrientation!.field;
        _isVisible = draft.sexualOrientation!.visible;
      });
    }
  }

  Future<void> _continue() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your sexual orientation')),
      );
      return;
    }

    // If PREFER_NOT_TO_SAY is selected, always set visible to false
    final visibility = DisplayableChoiceEditor.effectiveVisible(
      _selected,
      _isVisible,
      SexualOrientation.preferNotToSay,
    );

    final currentDraft = ref.read(profileCreationProvider);
    final updatedDraft = currentDraft.copyWith(
      sexualOrientation: DisplayableField(field: _selected!, visible: visibility),
    );
    await ref.read(profileCreationProvider.notifier).updateDraft(updatedDraft);

    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/preferences/bio');
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
                currentStep: ProfileCreationConstants.preferencesStepSexualOrientation,
                totalSteps: ProfileCreationConstants.preferencesTotalSteps,
                sectionLabel: 'Preferences',
              ),
              const SizedBox(height: 32),
              Text(
                'Sexual orientation',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'What best describes you?',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),
              DisplayableChoiceEditor<SexualOrientation>(
                values: SexualOrientation.values,
                selected: _selected,
                visible: _isVisible,
                labelOf: (value) => value.displayName,
                onSelected: (value) => setState(() => _selected = value),
                onVisibleChanged: (value) => setState(() => _isVisible = value),
                preferNotToSay: SexualOrientation.preferNotToSay,
              ),
              AppButton(label: 'Continue', onPressed: _selected != null ? _continue : null),
            ],
          ),
        ),
      ),
    );
  }

}
