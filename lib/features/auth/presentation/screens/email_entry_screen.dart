import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import 'password_creation_screen.dart';
import 'password_sign_in_screen.dart';

/// Email Entry Screen
/// User enters email address to create account or sign in
/// Reference: screenshots/login/create-user/4AB7216B-DFC9-4716-9999-72A12357B8BB.png
class EmailEntryScreen extends ConsumerStatefulWidget {
  const EmailEntryScreen({super.key});

  @override
  ConsumerState<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends ConsumerState<EmailEntryScreen> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onCreateAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();

    if (mounted) {
      // Navigate to password creation screen for new account
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PasswordCreationScreen(
            email: email,
          ),
        ),
      );
    }
  }

  void _onSignIn() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();

    // Navigate to sign-in screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PasswordSignInScreen(email: email),
      ),
    );
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Title
                Text(
                  'My email is',
                  style: Theme.of(context).textTheme.displayMedium,
                ),

                const SizedBox(height: 32),

                // Email Input Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    hintText: 'Email address',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  validator: Validators.validateEmail,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),

                const Spacer(),

                // Create Account Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _emailController.text.isNotEmpty
                        ? _onCreateAccount
                        : null,
                    child: const Text('Create Account'),
                  ),
                ),

                const SizedBox(height: 12),

                // Sign In Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _emailController.text.isNotEmpty
                        ? _onSignIn
                        : null,
                    child: const Text('Sign In'),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
