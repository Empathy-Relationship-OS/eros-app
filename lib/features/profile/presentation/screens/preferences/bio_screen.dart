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

/// Bio input screen
/// Optional field - users can skip
/// Max 300 characters as per CreateUserRequest validation
class BioScreen extends ConsumerStatefulWidget {
  const BioScreen({super.key});

  @override
  ConsumerState<BioScreen> createState() => _BioScreenState();
}

class _BioScreenState extends ConsumerState<BioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final bool _canContinue = true; // Bio is optional

  @override
  void initState() {
    super.initState();
    final draft = ref.read(profileCreationProvider);
    if (draft.bio != null) {
      _bioController.text = draft.bio!;
    }
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    // Cleaned, never stripped: line breaks are kept, quotes and `<3` too (RFC-004 D-16).
    final bio = UserText.clean(_bioController.text, multiline: true);

    final currentDraft = ref.read(profileCreationProvider);
    final updatedDraft = currentDraft.copyWith(
      bio: bio,
    );
    await ref.read(profileCreationProvider.notifier).updateDraft(updatedDraft);

    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/preferences/pronouns');
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
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
                currentStep: ProfileCreationConstants.preferencesStepBio,
                totalSteps: ProfileCreationConstants.preferencesTotalSteps,
                sectionLabel: 'Preferences',
              ),
              const SizedBox(height: 32),
              Text(
                'Tell us about yourself',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Optional - share a bit about who you are',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: TextFieldEditor(
                  controller: _bioController,
                  maxLength: UserTextLimits.bio,
                  maxLines: 5,
                  hintText: 'e.g. Coffee enthusiast, loves hiking...',
                  validator: (value) => UserText.validate(
                    value,
                    name: 'Bio',
                    maxLength: UserTextLimits.bio,
                    multiline: true,
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
