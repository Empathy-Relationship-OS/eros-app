import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_state_provider.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import '../../../profile/domain/models/public_profile.dart';

/// Password Sign In Screen
/// User enters password to sign in to existing account
class PasswordSignInScreen extends ConsumerStatefulWidget {
  final String email;

  const PasswordSignInScreen({super.key, required this.email});

  @override
  ConsumerState<PasswordSignInScreen> createState() =>
      _PasswordSignInScreenState();
}

class _PasswordSignInScreenState extends ConsumerState<PasswordSignInScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final password = _passwordController.text;
      final authNotifier = ref.read(authStateProvider.notifier);

      // Sign in with Firebase
      final success = await authNotifier.signInWithEmail(
        email: widget.email,
        password: password,
      );

      if (!mounted) return;

      if (success) {
        // Fetch user profile from backend to check completion status
        await _checkProfileAndNavigate();
      } else {
        // Show error from auth state
        final errorMessage =
            ref.read(authStateProvider).errorMessage ?? 'Sign in failed';
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

  /// Check user profile status and navigate accordingly
  /// Uses two-step process:
  /// 1. Check if user exists in backend (GET /users/exists)
  /// 2. If exists, check profile completeness (GET /users/id/{id}/public)
  Future<void> _checkProfileAndNavigate() async {
    try {
      final profileRepository = ref.read(profileRepositoryProvider);

      // Step 1: Check if user exists
      final userExistsResponse = await profileRepository.checkUserExists();

      if (!mounted) return;

      if (!userExistsResponse.exists) {
        // User doesn't exist in backend - navigate to profile creation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please complete your profile setup'),
            backgroundColor: AppColors.primary,
          ),
        );

        Navigator.pushReplacementNamed(
          context,
          '/profile-creation/name',
        );
        return;
      }

      // Step 2: User exists - check profile completeness
      final publicProfile = await profileRepository.getPublicProfile(
        userExistsResponse.userId,
      );

      if (!mounted) return;

      // Check profile completeness
      final profileStatus = _checkProfileCompleteness(publicProfile);

      // Navigate based on profile status
      _navigateBasedOnProfileStatus(profileStatus);
    } on ProfileRepositoryException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Check which parts of the profile are complete
  /// Uses PublicProfileDTO from GET /users/id/{id}/public
  ProfileCompletionStatus _checkProfileCompleteness(PublicProfileDTO profile) {
    // Check if basic user info exists
    final hasBasicInfo = profile.name.isNotEmpty &&
        profile.userId.isNotEmpty;

    if (!hasBasicInfo) {
      return ProfileCompletionStatus.incomplete(
        '/profile-creation/name',
        'Basic profile information missing',
      );
    }

    // Check for Q&A responses (need at least 1)
    if (profile.profile.qas.isEmpty) {
      return ProfileCompletionStatus.incomplete(
        '/profile-creation/qa',
        'Please answer at least one question',
      );
    }

    // Check for photos (need at least 3 photos)
    final photos = profile.profile.photos;
    if (photos.isEmpty) {
      return ProfileCompletionStatus.incomplete(
        '/profile-creation/photos',
        'Please add your photos',
      );
    }

    if (photos.length < 3) {
      return ProfileCompletionStatus.incomplete(
        '/profile-creation/photos',
        'Please add at least 3 photos (you have ${photos.length})',
      );
    }

    // Profile is complete
    return ProfileCompletionStatus.complete();
  }

  /// Navigate to appropriate screen based on profile status
  void _navigateBasedOnProfileStatus(ProfileCompletionStatus status) {
    if (status.isComplete) {
      // Profile is complete - go to match screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome back!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pushReplacementNamed(context, '/match');
    } else {
      // Profile is incomplete - show message and navigate to appropriate screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status.message ?? 'Please complete your profile'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pushReplacementNamed(context, status.nextRoute!);
    }
  }

  Future<void> _onForgotPassword() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: Text('A password reset link will be sent to ${widget.email}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authNotifier = ref.read(authStateProvider.notifier);
      final success = await authNotifier.sendPasswordResetEmail(widget.email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Password reset email sent!'
                  : 'Failed to send reset email',
            ),
            backgroundColor: success ? Colors.green : AppColors.error,
          ),
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
                  'Welcome back',
                  style: Theme.of(context).textTheme.displayMedium,
                ),

                const SizedBox(height: 8),

                // Email display
                Text(
                  widget.email,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                // Password Input Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  keyboardType: TextInputType.visiblePassword,
                  autofocus: true,
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
                  onChanged: (value) {
                    setState(() {}); // Trigger rebuild for button state
                  },
                  onFieldSubmitted: (value) {
                    if (_passwordController.text.isNotEmpty) {
                      _onSignIn();
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Forgot password button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _onForgotPassword,
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Sign In Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _passwordController.text.isNotEmpty && !_isLoading
                        ? _onSignIn
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
                        : const Text('Sign in'),
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

/// Helper class to track profile completion status
class ProfileCompletionStatus {
  final bool isComplete;
  final String? nextRoute;
  final String? message;

  ProfileCompletionStatus.complete()
      : isComplete = true,
        nextRoute = null,
        message = null;

  ProfileCompletionStatus.incomplete(this.nextRoute, this.message)
      : isComplete = false;
}
