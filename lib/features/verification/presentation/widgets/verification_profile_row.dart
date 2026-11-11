import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_provider.dart';
import 'package:eros_app/features/verification/presentation/screens/verification_status_screen.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';

/// "Verify your profile" on the signed-in user's own Profile tab, with a hint for where they
/// stand, opening [VerificationStatusScreen] (RFC-008 §7, VF-F3).
///
/// Only the user sees it: nothing changes in how other people's profiles look (D-7). No hint
/// while the status loads or can't be read.
class VerificationProfileRow extends ConsumerWidget {
  const VerificationProfileRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verificationStatusProvider).valueOrNull?.state;
    final hint = state == null ? null : VerificationCopy.profileHint(state);
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => openVerificationStatus(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.verified_user_outlined, size: 24, color: AppColors.textPrimary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                VerificationCopy.verifyYourProfile,
                style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            if (hint != null) ...[
              const SizedBox(width: 8),
              Text(
                hint,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            const Icon(Icons.chevron_right, size: 24, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
