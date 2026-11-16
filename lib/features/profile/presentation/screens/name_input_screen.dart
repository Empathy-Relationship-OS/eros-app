import 'package:flutter/material.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/utils/user_text.dart';
import 'package:eros_app/core/utils/validators.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';

/// First screen in profile creation flow - Name input
/// Matches screenshot: @screenshots/login/create-user/0818BA8E-C49E-4657-A7F0-87429222351A.png
class NameInputScreen extends ConsumerStatefulWidget {
  const NameInputScreen({super.key});

  @override
  ConsumerState<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends ConsumerState<NameInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
    _firstNameController.addListener(_validateForm);
    _lastNameController.addListener(_validateForm);
  }

  void _loadExistingData() {
    final draft = ref.read(profileCreationProvider);
    if (draft.firstName != null) {
      _firstNameController.text = draft.firstName!;
    }
    if (draft.lastName != null) {
      _lastNameController.text = draft.lastName!;
    }
  }

  void _validateForm() {
    // Checks the controllers, not the form: this listener runs before the fields see the new
    // text, so the form would validate the previous keystroke.
    setState(() {
      _isValid = Validators.validateName(_firstNameController.text) == null &&
          Validators.validateName(_lastNameController.text) == null;
    });
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Cleaned, never stripped: "O'Brien" and "José" are saved as typed (RFC-004 D-16).
    final firstName = UserText.clean(_firstNameController.text);
    final lastName = UserText.clean(_lastNameController.text);

    // Update the draft
    await ref.read(profileCreationProvider.notifier).updateFields(
          firstName: firstName,
          lastName: lastName,
        );

    // Navigate to next screen
    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/location');
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    // Show confirmation dialog before allowing back navigation
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel profile creation?'),
        content: const Text(
          'Going back will sign you out. You can continue creating your profile next time you sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue Creating'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true && mounted) {
      // Import auth provider at top of file
      final authNotifier = ref.read(authStateProvider.notifier);
      await authNotifier.signOut();

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/welcome',
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
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
                currentStep: ProfileCreationConstants.basicInfoStepName,
                totalSteps: ProfileCreationConstants.basicInfoTotalSteps,
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'What\'s your name?',
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

              // Form
              Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: [
                    // First name
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'First name',
                      ),
                      validator: Validators.validateName,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Last name
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Last name',
                      ),
                      validator: Validators.validateName,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (_isValid) {
                          _continue();
                        }
                      },
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Continue button
              AppButton(label: 'Continue', onPressed: _isValid ? _continue : null),
            ],
          ),
        ),
      ),
    );
  }
}
