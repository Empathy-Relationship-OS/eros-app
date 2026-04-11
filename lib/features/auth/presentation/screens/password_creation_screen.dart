import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_state_provider.dart';

/// Password Creation Screen
/// User creates a password for their account
class PasswordCreationScreen extends ConsumerStatefulWidget {
  final String email;
  final bool acceptsMarketing;

  const PasswordCreationScreen({
    super.key,
    required this.email,
    required this.acceptsMarketing,
  });

  @override
  ConsumerState<PasswordCreationScreen> createState() =>
      _PasswordCreationScreenState();
}

class _PasswordCreationScreenState
    extends ConsumerState<PasswordCreationScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  PasswordStrength _passwordStrength = PasswordStrength.none;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged(String value) {
    setState(() {
      _passwordStrength = Validators.getPasswordStrength(value);
    });
  }

  Color _getStrengthColor() {
    switch (_passwordStrength) {
      case PasswordStrength.none:
        return AppColors.textSecondary;
      case PasswordStrength.weak:
        return AppColors.error;
      case PasswordStrength.medium:
        return Colors.orange;
      case PasswordStrength.strong:
        return Colors.green;
    }
  }

  String _getStrengthText() {
    switch (_passwordStrength) {
      case PasswordStrength.none:
        return '';
      case PasswordStrength.weak:
        return 'Weak password';
      case PasswordStrength.medium:
        return 'Medium strength';
      case PasswordStrength.strong:
        return 'Strong password';
    }
  }

  double _getStrengthProgress() {
    switch (_passwordStrength) {
      case PasswordStrength.none:
        return 0.0;
      case PasswordStrength.weak:
        return 0.33;
      case PasswordStrength.medium:
        return 0.66;
      case PasswordStrength.strong:
        return 1.0;
    }
  }

  Future<void> _onContinue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final password = _passwordController.text;
      final authNotifier = ref.read(authStateProvider.notifier);

      // Create Firebase account with email and password
      final success = await authNotifier.signUpWithEmail(
        email: widget.email,
        password: password,
      );

      if (!mounted) return;

      if (success) {
        // Navigate to profile creation flow
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/profile-creation/name',
          );
        }
      } else {
        // Show error from auth state
        final errorMessage =
            ref.read(authStateProvider).errorMessage ?? 'Sign up failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Title
                Text(
                  'Create a password',
                  style: Theme.of(context).textTheme.displayMedium,
                ),

                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Use at least 8 characters',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                // Password Input Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  validator: Validators.validatePassword,
                  onChanged: _onPasswordChanged,
                ),

                const SizedBox(height: 16),

                // Password strength indicator
                if (_passwordController.text.isNotEmpty) ...[
                  LinearProgressIndicator(
                    value: _getStrengthProgress(),
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getStrengthColor(),
                    ),
                    minHeight: 4,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStrengthText(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getStrengthColor(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Password requirements
                Text(
                  'Password tips:',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _buildPasswordTip('Use 12+ characters for stronger security'),
                _buildPasswordTip('Mix uppercase and lowercase letters'),
                _buildPasswordTip('Include numbers and special characters'),

                const Spacer(),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _passwordController.text.length >= 8 && !_isLoading
                        ? _onContinue
                        : null,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.white,
                              ),
                            ),
                          )
                        : const Text('Continue'),
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

  Widget _buildPasswordTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
