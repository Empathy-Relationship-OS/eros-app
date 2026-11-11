import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_card_provider.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_provider.dart';
import 'package:eros_app/features/verification/presentation/screens/verification_status_screen.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';

/// "Verify before your first date", above the batch on the Matches tab (RFC-008 §5.3, §7,
/// VF-F3), so people verify before a date deadline is running. It covers existing users too
/// (D-14): there's no blocking sheet, the wall on a date is the only hard stop.
///
/// Shown per [shouldShowVerificationCard]. Dismissing it is remembered on this device; it comes
/// back when the user lands in retry. Nothing here is about anyone else (D-7).
class VerificationPromptCard extends ConsumerStatefulWidget {
  const VerificationPromptCard({super.key});

  @override
  ConsumerState<VerificationPromptCard> createState() => _VerificationPromptCardState();
}

class _VerificationPromptCardState extends ConsumerState<VerificationPromptCard> {
  @override
  void initState() {
    super.initState();
    // A dismissal made in retry moves on with the state, so that the next retry (after another
    // attempt) shows the card again.
    ref.listenManual<AsyncValue<VerificationStatus>>(
      verificationStatusProvider,
      (_, next) {
        final state = next.valueOrNull?.state;
        if (state == null || state == VerificationState.retry) return;
        if (ref.read(verificationCardDismissalProvider) != VerificationState.retry) return;
        ref.read(verificationCardDismissalProvider.notifier).dismiss(state);
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(verificationStatusProvider).valueOrNull;
    final state = status?.state;
    final dismissedIn = ref.watch(verificationCardDismissalProvider);
    if (state == null || !shouldShowVerificationCard(state, dismissedIn)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => openVerificationStatus(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(Icons.verified_user_outlined, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        VerificationCopy.cardTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state == VerificationState.retry
                            ? VerificationCopy.retryReason(status?.reason)
                            : VerificationCopy.whatItTakes,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  tooltip: VerificationCopy.cardDismiss,
                  onPressed: () =>
                      ref.read(verificationCardDismissalProvider.notifier).dismiss(state),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
