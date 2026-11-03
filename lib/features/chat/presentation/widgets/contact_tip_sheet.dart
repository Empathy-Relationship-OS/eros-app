import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/chat/presentation/widgets/chat_copy.dart';

/// The one-time safety tip, shown the first time the app shows a message the backend
/// flagged as having contact details (RFC-006 D-6). It's advice only: dismissing it is
/// all it asks, and nothing waits on it.
class ContactTipSheet extends StatelessWidget {
  const ContactTipSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.shield_outlined, size: 32, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text(
              ChatCopy.contactTip,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(ChatCopy.contactTipDismiss),
            ),
          ],
        ),
      ),
    );
  }
}
