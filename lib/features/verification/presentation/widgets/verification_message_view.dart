import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// A full-screen message in the verification flow: an outcome, a refusal or a camera problem.
///
/// The text says everything; the icon only decorates it, so nothing depends on colour.
class VerificationMessageView extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Dark, over the camera screen's black background.
  final bool dark;

  const VerificationMessageView({
    super.key,
    required this.icon,
    this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? Colors.white : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          ExcludeSemantics(child: Icon(icon, size: 56, color: AppColors.primary)),
          const SizedBox(height: 24),
          if (title != null) ...[
            Semantics(
              header: true,
              child: Text(
                title!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textColor),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.5, color: textColor),
          ),
          const Spacer(),
          ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          if (secondaryLabel != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondary,
              child: Text(secondaryLabel!, style: TextStyle(color: textColor)),
            ),
          ],
        ],
      ),
    );
  }
}
