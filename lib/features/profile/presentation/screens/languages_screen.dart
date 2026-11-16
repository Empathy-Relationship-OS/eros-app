import 'package:flutter/material.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/constants/languages.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/languages_editor.dart';

/// Languages spoken selection screen
/// Matches screenshot: @screenshots/login/create-user/3501077E-60FD-4AB1-BDE8-BBC133EA7E48.png
class LanguagesScreen extends ConsumerStatefulWidget {
  const LanguagesScreen({super.key});

  @override
  ConsumerState<LanguagesScreen> createState() => _LanguagesScreenState();
}

class _LanguagesScreenState extends ConsumerState<LanguagesScreen> {
  List<Language> _selectedLanguages = [];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final draft = ref.read(profileCreationProvider);
    if (draft.spokenLanguages != null) {
      setState(() {
        // A set first, as before: duplicates in an old draft are dropped, order is kept.
        _selectedLanguages = draft.spokenLanguages!.field.toSet().toList();
      });
    }
    // Set preferred language as default if no languages selected
    if (_selectedLanguages.isEmpty && draft.preferredLanguage != null) {
      setState(() {
        _selectedLanguages = [draft.preferredLanguage!];
      });
    }
  }

  Future<void> _continue() async {
    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one language'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Update the draft
    final currentDraft = ref.read(profileCreationProvider);
    final updatedDraft = currentDraft.copyWith(
      spokenLanguages: DisplayableField.visible(_selectedLanguages),
      // Set preferred language to first selected if not set
      preferredLanguage: currentDraft.preferredLanguage ?? _selectedLanguages.first,
    );
    await ref.read(profileCreationProvider.notifier).updateDraft(updatedDraft);

    // Navigate to next screen
    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/height');
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
              // Progress indicator
              ProfileProgressBar(
                currentStep: ProfileCreationConstants.basicInfoStepLanguages,
                totalSteps: ProfileCreationConstants.basicInfoTotalSteps,
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'What languages do you speak?',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Select all that apply',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),

              // Languages list
              LanguagesEditor(
                selected: _selectedLanguages,
                onChanged: (selected) => setState(() => _selectedLanguages = selected),
              ),

              const SizedBox(height: 16),

              // Selection count
              if (_selectedLanguages.isNotEmpty) ...[
                Text(
                  '${_selectedLanguages.length} ${_selectedLanguages.length == 1 ? 'language' : 'languages'} selected',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.primaryDeep,
                      ),
                ),
                const SizedBox(height: 16),
              ],

              // Continue button
              AppButton(
                label: 'Continue',
                onPressed: _selectedLanguages.isNotEmpty ? _continue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
