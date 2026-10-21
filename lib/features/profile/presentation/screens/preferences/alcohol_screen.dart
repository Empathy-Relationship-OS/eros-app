import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/displayable_choice_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';

/// Alcohol consumption preference screen
/// Matches screenshot: @screenshots/users/create-profile/9E6D741C-F92F-4828-B1CF-675E6ED8EACF.png
class AlcoholScreen extends ConsumerStatefulWidget {
  const AlcoholScreen({super.key});

  @override
  ConsumerState<AlcoholScreen> createState() => _AlcoholScreenState();
}

class _AlcoholScreenState extends ConsumerState<AlcoholScreen> {
  AlcoholConsumption? _selected;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(profileCreationProvider);
    if (draft.alcoholConsumption != null) {
      setState(() {
        _selected = draft.alcoholConsumption!.field;
        _isVisible = draft.alcoholConsumption!.visible;
      });
    }
  }

  Future<void> _continue() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your preference')),
      );
      return;
    }

    // If PREFER_NOT_TO_SAY is selected, always set visible to false
    final visibility = DisplayableChoiceEditor.effectiveVisible(
      _selected,
      _isVisible,
      AlcoholConsumption.preferNotToSay,
    );

    final currentDraft = ref.read(profileCreationProvider);
    final updatedDraft = currentDraft.copyWith(
      alcoholConsumption: DisplayableField(field: _selected, visible: visibility),
    );
    await ref.read(profileCreationProvider.notifier).updateDraft(updatedDraft);

    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/preferences/smoking');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                currentStep: ProfileCreationConstants.preferencesStepAlcohol,
                totalSteps: ProfileCreationConstants.preferencesTotalSteps,
                sectionLabel: 'Preferences',
              ),
              const SizedBox(height: 32),
              Text(
                'How often do you drink?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 32),
              DisplayableChoiceEditor<AlcoholConsumption>(
                values: AlcoholConsumption.values,
                selected: _selected,
                visible: _isVisible,
                labelOf: (value) => value.displayName,
                onSelected: (value) => setState(() => _selected = value),
                onVisibleChanged: (value) => setState(() => _isVisible = value),
                preferNotToSay: AlcoholConsumption.preferNotToSay,
              ),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selected != null ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
