import 'package:flutter/material.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/constants/user_text_limits.dart';
import 'package:eros_app/core/utils/user_text.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/text_field_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';

/// Occupation and study screen
/// Matches screenshot: @screenshots/users/create-profile/A7C87B65-5F8F-4648-9E31-BD6C09779DEF.png
class OccupationScreen extends ConsumerStatefulWidget {
  const OccupationScreen({super.key});

  @override
  ConsumerState<OccupationScreen> createState() => _OccupationScreenState();
}

class _OccupationScreenState extends ConsumerState<OccupationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jobController = TextEditingController();
  final bool _canContinue = true; // Occupation is optional

  @override
  void initState() {
    super.initState();
    final draft = ref.read(profileCreationProvider);
    if (draft.occupation != null) {
      _jobController.text = draft.occupation!;
    }
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    // Cleaned, never stripped (RFC-004 D-16). Optional, so empty is saved as no occupation.
    final cleaned = UserText.clean(_jobController.text);
    final occupation = cleaned.isEmpty ? null : cleaned;

    final currentDraft = ref.read(profileCreationProvider);
    final updatedDraft = currentDraft.copyWith(
      occupation: occupation,
    );
    await ref.read(profileCreationProvider.notifier).updateDraft(updatedDraft);

    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/preferences/relationship-type');
    }
  }

  @override
  void dispose() {
    _jobController.dispose();
    super.dispose();
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
                currentStep: ProfileCreationConstants.preferencesStepOccupation,
                totalSteps: ProfileCreationConstants.preferencesTotalSteps,
                sectionLabel: 'Preferences',
              ),
              const SizedBox(height: 32),
              Text(
                'What do you do?',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Optional - skip if you prefer',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: TextFieldEditor(
                  controller: _jobController,
                  maxLength: UserTextLimits.occupation,
                  labelText: 'Job / Occupation',
                  hintText: 'e.g. Software Engineer',
                  validator: (value) => UserText.validate(
                    value,
                    name: 'Occupation',
                    maxLength: UserTextLimits.occupation,
                  ),
                ),
              ),
              const Spacer(),
              AppButton(label: 'Continue', onPressed: _canContinue ? _continue : null),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _continue(),
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
