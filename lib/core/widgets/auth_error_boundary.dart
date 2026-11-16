import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';

/// Global error boundary that always provides a sign-out option
///
/// This widget wraps error-prone content and provides a fallback UI
/// with a sign-out button when authentication or permission errors occur.
///
/// Use this to wrap screens that require authentication, especially where
/// auth errors might leave the user stuck without a way to sign out.
class AuthErrorBoundary extends ConsumerWidget {
  final Widget child;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const AuthErrorBoundary({
    super.key,
    required this.child,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (errorMessage != null) {
      return _ErrorFallback(
        errorMessage: errorMessage!,
        onRetry: onRetry,
        onSignOut: () => _handleSignOut(context, ref),
      );
    }

    return child;
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    try {
      final authNotifier = ref.read(authStateProvider.notifier);
      await authNotifier.signOut();

      if (context.mounted) {
        // Navigate to welcome screen and clear navigation stack
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/welcome',
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

/// Error fallback UI with sign-out option
class _ErrorFallback extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback onSignOut;

  const _ErrorFallback({
    required this.errorMessage,
    this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    // Check if this is a permission/auth error
    final isAuthError = errorMessage.toLowerCase().contains('permission') ||
        errorMessage.toLowerCase().contains('unauthorized') ||
        errorMessage.toLowerCase().contains('forbidden') ||
        errorMessage.toLowerCase().contains('access denied');

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error icon
              Icon(
                isAuthError ? Icons.lock_outline : Icons.error_outline,
                size: 80,
                color: AppColors.error,
              ),
              const SizedBox(height: 24),

              // Error title
              Text(
                isAuthError ? 'Access Error' : 'Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Error message
              Text(
                errorMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Action buttons
              if (onRetry != null) ...[
                AppButton(label: 'Try Again', onPressed: onRetry),
                const SizedBox(height: 12),
              ],

              // Always show sign-out button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Sign Out',
                  kind: AppButtonKind.outline,
                  onPressed: onSignOut,
                ),
              ),

              // Additional help text for auth errors
              if (isAuthError) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    border: Border.all(
                      color: AppColors.primaryTint,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.primaryDeep,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This might be caused by a previous account. Try signing out and creating a new account.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
