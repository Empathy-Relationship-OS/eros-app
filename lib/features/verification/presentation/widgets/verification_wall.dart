import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_provider.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';

/// The wall in place of a date action while the viewer isn't verified (RFC-008 §7, VF-F4).
///
/// It shows the viewer's own state only, never anything about the partner (D-7), and never a
/// score (primer rule 21). The state comes from [verificationStatusProvider]; the wall refetches
/// it when the app resumes and never sets it locally (rule 22).
///
/// When the status turns verified, [onVerified] runs so the host can refetch its date: the
/// server's `verificationRequired` decides when the wall comes down, not this widget.
class VerificationWall extends ConsumerStatefulWidget {
  /// The current step's deadline, formatted for display. Null when the step has none.
  final String? deadline;

  /// The one-line version, in place of the chat composer.
  final bool compact;

  final VoidCallback? onVerified;

  const VerificationWall({super.key, this.deadline, this.compact = false, this.onVerified});

  @override
  ConsumerState<VerificationWall> createState() => _VerificationWallState();
}

class _VerificationWallState extends ConsumerState<VerificationWall> {
  late final AppLifecycleListener _lifecycle;

  // TODO(VF-F2): remove with the placeholder in [_startVerification].
  static const String _flowComingSoon = 'Selfie verification is coming soon';

  @override
  void initState() {
    super.initState();
    // A decision may have landed while the app was in the background.
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(ref.read(verificationStatusNotifierProvider).refresh()),
    );
    ref.listenManual<AsyncValue<VerificationStatus>>(
      verificationStatusProvider,
      (previous, next) {
        final was = previous?.valueOrNull?.isVerified ?? false;
        final now = next.valueOrNull?.isVerified ?? false;
        // After the build: the host refetches its date, which changes providers.
        if (!was && now) scheduleMicrotask(() => widget.onVerified?.call());
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Every Verify now and Try again tap comes here.
  Future<void> _startVerification() async {
    // TODO(VF-F2): call `startVerification(context, ref)` from
    // lib/features/verification/presentation/start_verification.dart once VF-F2 merges.
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(_flowComingSoon)));
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(verificationStatusProvider);
    return Semantics(
      container: true,
      child: widget.compact ? _buildCompact(status) : _buildFull(status),
    );
  }

  Widget _buildFull(AsyncValue<VerificationStatus> status) {
    final deadline = widget.deadline;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          VerificationCopy.wallTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (deadline != null) ...[
          const SizedBox(height: 6),
          Text(
            VerificationCopy.keepYourDate(deadline),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        ..._buildStateBody(status),
      ],
    );
  }

  List<Widget> _buildStateBody(AsyncValue<VerificationStatus> status) {
    // An unreadable status still lets them start: the flow checks it again.
    if (status.hasError && !status.hasValue) return [_button(VerificationCopy.verifyNow)];
    final value = status.valueOrNull;
    if (value == null) return [_spinner()];

    switch (value.state) {
      case VerificationState.notVerified:
        return [_button(VerificationCopy.verifyNow)];
      case VerificationState.inReview:
        return [_line(VerificationCopy.inReview)];
      case VerificationState.retry:
        return [
          _line(VerificationCopy.retryReason(value.reason)),
          const SizedBox(height: 12),
          _button(VerificationCopy.tryAgain),
        ];
      case VerificationState.locked:
        return [_line(VerificationCopy.locked)];
      case VerificationState.verified:
        // The date is being refetched, and the wall comes down when it says so. Nothing to
        // start meanwhile.
        return const [];
      case VerificationState.unknown:
        return const [];
    }
  }

  Widget _buildCompact(AsyncValue<VerificationStatus> status) {
    final value = status.valueOrNull;
    final state =
        status.hasError && !status.hasValue ? VerificationState.notVerified : value?.state;

    final text = switch (state) {
      VerificationState.inReview => VerificationCopy.inReview,
      VerificationState.locked => VerificationCopy.locked,
      _ => VerificationCopy.wallTitle,
    };
    final action = switch (state) {
      VerificationState.notVerified => VerificationCopy.verifyNow,
      VerificationState.retry => VerificationCopy.tryAgain,
      _ => null,
    };

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: _startVerification,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(action),
            ),
        ],
      ),
    );
  }

  Widget _button(String label) => ElevatedButton(
        onPressed: _startVerification,
        child: Text(label),
      );

  Widget _line(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      );

  Widget _spinner() => const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
}
