import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';

/// Reusable error state widget for dates feature screens
///
/// Displays a user-friendly error message with:
/// - Large icon (error or specific icon based on error type)
/// - Heading
/// - Description text
/// - Primary action button (retry)
/// - Optional secondary action (go back)
///
/// Automatically tailors messaging based on exception type:
/// - NotFoundException: "Not ready yet" with softer language
/// - NetworkException: Connection-specific messaging
/// - ServerException: Server error messaging
/// - Default: Generic error with retry option
class ErrorStateWidget extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final VoidCallback? onGoBack;
  final String? customMessage;
  final String? customHeading;

  const ErrorStateWidget({
    super.key,
    required this.error,
    required this.onRetry,
    this.onGoBack,
    this.customMessage,
    this.customHeading,
  });

  @override
  Widget build(BuildContext context) {
    final errorInfo = _getErrorInfo(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: errorInfo.iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                errorInfo.icon,
                size: 40,
                color: errorInfo.iconColor,
              ),
            ),
            const SizedBox(height: 24),

            // Error heading
            Text(
              customHeading ?? errorInfo.heading,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Error description
            Text(
              customMessage ?? errorInfo.message,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Primary action - Retry
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Secondary action - Go back
            if (onGoBack != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onGoBack,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _ErrorInfo _getErrorInfo(Object error) {
    if (error is NotFoundException) {
      return _ErrorInfo(
        icon: Icons.location_searching,
        iconColor: AppColors.textSecondary,
        heading: 'Not ready yet',
        message:
            'This information is still being prepared. It usually takes just a few moments.',
      );
    } else if (error is NetworkException) {
      return _ErrorInfo(
        icon: Icons.wifi_off,
        iconColor: AppColors.error,
        heading: 'Connection problem',
        message:
            'Check your internet connection and try again. If the problem persists, try switching networks.',
      );
    } else if (error is ServerException) {
      return _ErrorInfo(
        icon: Icons.cloud_off,
        iconColor: AppColors.error,
        heading: 'Server error',
        message:
            'Our servers are having trouble right now. We\'re working on it. Please try again in a moment.',
      );
    } else if (error is UnauthorizedException) {
      return _ErrorInfo(
        icon: Icons.lock_outline,
        iconColor: AppColors.error,
        heading: 'Session expired',
        message: 'Your session has expired. Please sign in again.',
      );
    } else if (error is ForbiddenException) {
      return _ErrorInfo(
        icon: Icons.block,
        iconColor: AppColors.error,
        heading: 'Access denied',
        message: 'You don\'t have permission to view this.',
      );
    } else {
      // Generic error
      return _ErrorInfo(
        icon: Icons.error_outline,
        iconColor: AppColors.error,
        heading: 'Something went wrong',
        message:
            'We couldn\'t load this right now. Check your connection and try again.',
      );
    }
  }
}

class _ErrorInfo {
  final IconData icon;
  final Color iconColor;
  final String heading;
  final String message;

  _ErrorInfo({
    required this.icon,
    required this.iconColor,
    required this.heading,
    required this.message,
  });
}
