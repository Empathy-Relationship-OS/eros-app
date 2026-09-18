import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/widgets/sign_out_dialog.dart';

/// Emergency floating sign-out button that can be shown anywhere
///
/// This provides a last-resort sign-out option when users are stuck
/// due to authentication or permission errors.
class EmergencySignOutButton extends ConsumerWidget {
  const EmergencySignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () => showSignOutDialog(
        context,
        ref,
        message: 'Are you sure you want to sign out? This will clear all local data and return you to the welcome screen.',
      ),
      backgroundColor: AppColors.error,
      icon: const Icon(Icons.logout, color: AppColors.white),
      label: const Text(
        'Sign Out',
        style: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Convenience widget to add sign-out to app bar
class SignOutAppBarAction extends ConsumerWidget {
  const SignOutAppBarAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Sign Out',
      onPressed: () => showSignOutDialog(
        context,
        ref,
        message: 'Are you sure you want to sign out?',
      ),
    );
  }
}
