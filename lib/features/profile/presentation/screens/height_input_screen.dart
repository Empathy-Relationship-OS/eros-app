import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/height_editor.dart';

/// Height input screen in profile creation flow
/// Matches screenshots:
/// - @screenshots/login/create-user/F6C549FC-FECF-4410-9B00-DDF6001329B2.png
/// - @screenshots/login/create-user/2B95D7A1-BF71-403E-8BFD-7B6733E633D7.png
class HeightInputScreen extends ConsumerStatefulWidget {
  const HeightInputScreen({super.key});

  @override
  ConsumerState<HeightInputScreen> createState() => _HeightInputScreenState();
}

class _HeightInputScreenState extends ConsumerState<HeightInputScreen> {
  late final int? _initialHeightCm;

  // Null until the user enters a valid height (the editor reports nothing for the initial value).
  int? _heightCm;

  @override
  void initState() {
    super.initState();
    _initialHeightCm = ref.read(profileCreationProvider).heightCm;
  }

  Future<void> _continue() async {
    final heightCm = _heightCm;
    if (heightCm == null) {
      return;
    }

    // Update the draft
    await ref.read(profileCreationProvider.notifier).updateFields(
          heightCm: heightCm,
        );

    // Navigate to next screen
    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/education');
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
              // Progress indicator (step 8 of 11 in basic info)
              ProfileProgressBar(
                currentStep: ProfileCreationConstants.basicInfoStepHeight,
                totalSteps: ProfileCreationConstants.basicInfoTotalSteps,
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'What\'s your height?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will be displayed on your profile',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32),

              HeightEditor(
                initialHeightCm: _initialHeightCm,
                onChanged: (heightCm) => setState(() => _heightCm = heightCm),
                onSubmitted: (_) => _continue(),
              ),

              const Spacer(),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _heightCm != null ? _continue : null,
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
