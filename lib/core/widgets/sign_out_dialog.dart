import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';

/// Shared sign-out dialog workflow
///
/// Shows confirmation dialog, performs sign-out, navigates to welcome screen,
/// and handles errors consistently across the app.
///
/// Usage:
/// ```dart
/// onPressed: () => showSignOutDialog(
///   context,
///   ref,
///   message: 'Are you sure you want to sign out?',
/// ),
/// ```
Future<void> showSignOutDialog(
  BuildContext context,
  WidgetRef ref, {
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign Out'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Sign Out'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    try {
      final authNotifier = ref.read(authStateProvider.notifier);
      await authNotifier.signOut();

      if (context.mounted) {
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
