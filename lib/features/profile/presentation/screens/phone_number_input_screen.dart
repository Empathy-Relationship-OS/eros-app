import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// Phone number input screen for profile creation
/// Will be sent to backend in future updates
class PhoneNumberInputScreen extends ConsumerStatefulWidget {
  const PhoneNumberInputScreen({super.key});

  @override
  ConsumerState<PhoneNumberInputScreen> createState() =>
      _PhoneNumberInputScreenState();
}

class _PhoneNumberInputScreenState
    extends ConsumerState<PhoneNumberInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isValid = false;
  bool _isPhoneFromFirebase = false;

  @override
  void initState() {
    super.initState();
    _loadPhoneData();
    _phoneController.addListener(_validateForm);
  }

  void _loadPhoneData() {
    final draft = ref.read(profileCreationProvider);

    // Try to get phone from Firebase Auth
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser?.phoneNumber != null) {
      _phoneController.text = firebaseUser!.phoneNumber!;
      _isPhoneFromFirebase = true;
      // Auto-save to draft if from Firebase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(profileCreationProvider.notifier).updateFields(
              phoneNumber: firebaseUser.phoneNumber!,
            );
      });
    } else if (draft.phoneNumber != null) {
      // Fallback to saved draft
      _phoneController.text = draft.phoneNumber!;
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

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove all non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    // Check if it's a valid length (10-15 digits is typical for international numbers)
    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  Future<void> _continue() async {
    if (!_isValid) return;

    final phoneNumber = _phoneController.text.trim();

    // Auto-populate email from Firebase in the background
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final email = firebaseUser?.email;

    // Update draft with both phone and email
    await ref.read(profileCreationProvider.notifier).updateFields(
          phoneNumber: phoneNumber,
          email: email, // Auto-populate from Firebase
        );

    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/terms');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
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
              _buildProgressBar(9, 11),
              const SizedBox(height: 32),
              Text(
                _isPhoneFromFirebase
                    ? 'Confirm your phone number'
                    : 'What\'s your phone number?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _isPhoneFromFirebase
                    ? 'We\'ve pulled this from your account'
                    : 'We\'ll use this to contact you about your dates',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+1 234 567 8900',
                    helperText: _isPhoneFromFirebase
                        ? 'You can edit this if needed'
                        : 'Include country code (e.g., +1 for US)',
                    helperStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: _validatePhoneNumber,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    // Allow digits, spaces, parentheses, hyphens, and plus sign
                    FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+\-\(\)]')),
                  ],
                  onFieldSubmitted: (_) {
                    if (_isValid) {
                      _continue();
                    }
                  },
                ),
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

  Widget _buildProgressBar(int currentStep, int totalSteps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step $currentStep of $totalSteps',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${((currentStep / totalSteps) * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: currentStep / totalSteps,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
