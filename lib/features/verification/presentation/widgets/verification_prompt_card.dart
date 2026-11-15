import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/widgets/app_prompt_card.dart';
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
      child: AppPromptCard(
        icon: Icons.verified_user_outlined,
        title: VerificationCopy.cardTitle,
        subtitle: state == VerificationState.retry
            ? VerificationCopy.retryReason(status?.reason)
            : VerificationCopy.whatItTakes,
        onTap: () => openVerificationStatus(context),
        onDismiss: () => ref.read(verificationCardDismissalProvider.notifier).dismiss(state),
        dismissTooltip: VerificationCopy.cardDismiss,
      ),
    );
  }
}
