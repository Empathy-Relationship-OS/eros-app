import 'package:flutter/material.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/single_choice_editor.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// Gender identity selection screen
/// Matches screenshots:
/// - @screenshots/login/create-user/AAEC2A7B-6A73-467F-8689-04758736101A.png
/// - @screenshots/login/create-user/29A37231-9F7E-4CF8-88F5-F6C4A92CCF01.png
class GenderScreen extends ConsumerStatefulWidget {
  const GenderScreen({super.key});

  @override
  ConsumerState<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends ConsumerState<GenderScreen> {
  Gender? _selectedGender;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final draft = ref.read(profileCreationProvider);
    if (draft.gender != null) {
      setState(() {
        _selectedGender = draft.gender;
      });
    }
  }

  Future<void> _continue() async {
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender identity'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Update the draft
    await ref.read(profileCreationProvider.notifier).updateFields(
          // Note: updateFields needs to be extended to support gender
        );

    // For now, update the draft directly
    final currentDraft = ref.read(profileCreationProvider);
    final updatedDraft = currentDraft.copyWith(gender: _selectedGender);
    await ref.read(profileCreationProvider.notifier).updateDraft(updatedDraft);

    // Navigate to next screen
    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/interested-in');
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
                currentStep: ProfileCreationConstants.basicInfoStepGender,
                totalSteps: ProfileCreationConstants.basicInfoTotalSteps,
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'What\'s your gender?',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'This will be displayed on your profile',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),

              // Gender options
              ...Gender.values.map((gender) {
                final isSelected = _selectedGender == gender;
                return ChoiceOptionCard(
                  label: gender.displayName,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedGender = gender),
                );
              }),

              const Spacer(),

              // Continue button
              AppButton(label: 'Continue', onPressed: _selectedGender != null ? _continue : null),
            ],
          ),
        ),
      ),
    );
  }
}
