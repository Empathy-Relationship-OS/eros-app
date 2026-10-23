import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/displayable_choice_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';

/// Date intentions preference screen
/// Matches screenshot: @screenshots/users/create-profile/7366439D-0743-4B0F-B261-7455DCA007F1.png
class DateIntentionsScreen extends ConsumerStatefulWidget {
  const DateIntentionsScreen({super.key});

  @override
  ConsumerState<DateIntentionsScreen> createState() => _DateIntentionsScreenState();
}

class _DateIntentionsScreenState extends ConsumerState<DateIntentionsScreen> {
  DateIntentions? _selected;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(profileCreationProvider);
    if (draft.dateIntentions != null) {
      setState(() {
        _selected = draft.dateIntentions!.field;
        _isVisible = draft.dateIntentions!.visible;
      });
    }
  }

  Future<void> _continue() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your dating intention')),
      );
      return;
    }

    final currentDraft = ref.read(profileCreationProvider);
    final updatedDraft = currentDraft.copyWith(
      dateIntentions: DisplayableField(field: _selected!, visible: _isVisible),
    );
    await ref.read(profileCreationProvider.notifier).updateDraft(updatedDraft);

    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/preferences/kids');
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
                currentStep: ProfileCreationConstants.preferencesStepDateIntentions,
                totalSteps: ProfileCreationConstants.preferencesTotalSteps,
                sectionLabel: 'Preferences',
              ),
              const SizedBox(height: 32),
              Text(
                'How do you want to date?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps us match you with the right people',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32),
              DisplayableChoiceEditor<DateIntentions>(
                values: DateIntentions.values,
                selected: _selected,
                visible: _isVisible,
                labelOf: (value) => value.displayName,
                onSelected: (value) => setState(() => _selected = value),
                onVisibleChanged: (value) => setState(() => _isVisible = value),
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
