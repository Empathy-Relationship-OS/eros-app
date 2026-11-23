import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/notifications/notification_router.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_provider.dart';
import 'package:eros_app/features/verification/presentation/start_verification.dart';
import 'package:eros_app/features/verification/presentation/verification_links.dart';
import 'package:eros_app/features/verification/presentation/widgets/age_check_step.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_state_layout.dart';

/// Opens [VerificationStatusScreen] on [context]'s navigator, named so that a decision push
/// tapped while it's already on top doesn't open it twice.
Future<void> openVerificationStatus(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: VerificationStatusScreen.routeName),
        builder: (_) => const VerificationStatusScreen(),
      ),
    );

/// Where the signed-in user stands with selfie verification, one layout per state (RFC-008 §7,
/// VF-F3). Opened from the Profile row, the Matches card, a decision push and, in the age check
/// (CF-F2), the wall on a date.
///
/// It's the user's own state only, never anything about anyone else (D-7), and it shows a
/// reason, never a score (primer rule 21). The state comes from [verificationStatusProvider]:
/// pull to refresh refetches it, and nothing here sets it (rule 22).
class VerificationStatusScreen extends ConsumerStatefulWidget {
  static const String routeName = verificationStatusRoute;

  const VerificationStatusScreen({super.key});

  @override
  ConsumerState<VerificationStatusScreen> createState() => _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends ConsumerState<VerificationStatusScreen> {
  /// An unknown state is refetched once per visit, in case it was a passing answer. More than
  /// once could loop against a server that keeps sending it.
  bool _refreshedUnknown = false;

  @override
  void initState() {
    super.initState();
    // A status someone else loaded earlier (the Profile row, the Matches card) may be stale.
    // One loaded just now for this screen is current already.
    final status = ref.read(verificationStatusProvider);
    if (status.hasValue && !status.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_refresh()));
    }
    ref.listenManual<AsyncValue<VerificationStatus>>(
      verificationStatusProvider,
      (_, next) {
        if (_refreshedUnknown || next.valueOrNull?.state != VerificationState.unknown) return;
        _refreshedUnknown = true;
        scheduleMicrotask(() => unawaited(_refresh()));
      },
      fireImmediately: true,
    );
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await ref.read(verificationStatusNotifierProvider).refresh();
  }

  /// Verify now and Try again. The flow refreshes the status when an attempt is sent or refused;
  /// a decision can land while its last message is open, so read it again once it's closed.
  Future<void> _startVerification() async {
    await startVerification(context, ref);
    await _refresh();
  }

  /// New photos can change the state (removing the reference photo resets it), so refetch it.
  Future<void> _openPhotoEditor() async {
    await ref.read(verificationLinksProvider).openPhotoEditor(context);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(verificationStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(VerificationCopy.verifyYourProfile)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: LayoutBuilder(
          // Full height, so the whole screen pulls to refresh, however short the content.
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: _buildBody(status),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AsyncValue<VerificationStatus> status) {
    final value = status.valueOrNull;
    if (value == null) {
      if (status.hasError) {
        return VerificationStateLayout(icon: Icons.cloud_off_outlined, lines: const [VerificationCopy.statusFailed]);
      }
      return const Center(child: CircularProgressIndicator());
    }

    switch (value.state) {
      case VerificationState.notVerified:
      case VerificationState.unknown:
        return VerificationStateLayout(
          icon: Icons.verified_user_outlined,
          title: VerificationCopy.verifyYourProfile,
          lines: [
            VerificationCopy.whyWeAsk,
            VerificationCopy.whatItTakes,
            ?_attemptsLine(value),
          ],
          actionLabel: _canTry(value) ? VerificationCopy.verifyNow : null,
          onAction: _startVerification,
        );
      case VerificationState.inReview:
        return VerificationStateLayout(
          icon: Icons.hourglass_top_outlined,
          title: VerificationCopy.inReview,
          lines: const [VerificationCopy.inReviewDetail],
        );
      case VerificationState.retry:
        final photosLink = value.reason == RetryReason.notSamePerson ||
            value.reason == RetryReason.profilePhotosUnsuitable;
        return VerificationStateLayout(
          icon: Icons.refresh,
          title: VerificationCopy.retryTitle,
          lines: [VerificationCopy.retryReason(value.reason), ?_attemptsLine(value)],
          actionLabel: _canTry(value) ? VerificationCopy.tryAgain : null,
          onAction: _startVerification,
          secondaryLabel: photosLink ? VerificationCopy.updatePhotos : null,
          onSecondary: _openPhotoEditor,
        );
      case VerificationState.ageCheck:
        return AgeCheckStep(status: value);
      case VerificationState.verified:
        return VerificationStateLayout(icon: Icons.verified_outlined, title: VerificationCopy.verified);
      case VerificationState.locked:
        // No support link: the app has no support channel yet (see the PR).
        return VerificationStateLayout(icon: Icons.support_agent, lines: const [VerificationCopy.locked]);
    }
  }

  /// Attempts left today, only when that's 1 or 0 (the server's count, never worked out here).
  String? _attemptsLine(VerificationStatus status) =>
      status.attemptsLeftToday <= 1 ? VerificationCopy.attemptsLeft(status.attemptsLeftToday) : null;

  /// No button that can only lead to "you've used your attempts".
  bool _canTry(VerificationStatus status) => status.canStart || status.attemptsLeftToday > 0;
}
