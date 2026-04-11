import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/utils/validators.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// Email confirmation screen - auto-populated from Firebase Auth
/// Matches screenshot: @screenshots/login/create-user/4AB7216B-DFC9-4716-9999-72A12357B8BB.png
class EmailScreen extends ConsumerStatefulWidget {
  const EmailScreen({super.key});

  @override
  ConsumerState<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends ConsumerState<EmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isValid = false;
  bool _marketingConsent = false;
  bool _isEmailFromFirebase = false;

  @override
  void initState() {
    super.initState();
    _loadEmailData();
    _emailController.addListener(_validateForm);
  }

  void _loadEmailData() {
    final draft = ref.read(profileCreationProvider);

    // First try to get email from Firebase Auth
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser?.email != null) {
      _emailController.text = firebaseUser!.email!;
      _isEmailFromFirebase = true;
      // Auto-save to draft if from Firebase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(profileCreationProvider.notifier).updateFields(
          email: firebaseUser.email!,
        );
      });
    } else if (draft.email != null) {
      // Fallback to saved draft
      _emailController.text = draft.email!;
    }

    // Trigger initial validation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateForm();
    });
  }

  void _validateForm() {
    setState(() {
      _isValid = _formKey.currentState?.validate() ?? false;
    });
  }

  Future<void> _continue() async {
    if (!_isValid) return;

    final email = _emailController.text.trim();

    // Update draft
    await ref.read(profileCreationProvider.notifier).updateFields(
      email: email,
    );

    // TODO: Store marketing consent separately (could be added to profile draft)

    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/terms');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
                currentStep: ProfileCreationConstants.basicInfoStepEmail,
                totalSteps: ProfileCreationConstants.basicInfoTotalSteps,
              ),
              const SizedBox(height: 32),
              Text(
                _isEmailFromFirebase ? 'Confirm your email' : 'What\'s your email?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _isEmailFromFirebase
                    ? 'We\'ve pulled this from your account'
                    : 'We\'ll use this to contact you',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    helperText: _isEmailFromFirebase ? 'You can edit this if needed' : null,
                    helperStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: Validators.validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(height: 24),
              CheckboxListTile(
                value: _marketingConsent,
                onChanged: (value) => setState(() => _marketingConsent = value ?? false),
                title: const Text(
                  'I consent to receive marketing emails from Muse',
                  style: TextStyle(fontSize: 14),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isValid ? _continue : null,
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
