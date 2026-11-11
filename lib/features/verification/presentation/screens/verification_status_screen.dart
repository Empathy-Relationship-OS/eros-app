import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/notifications/notification_router.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_provider.dart';
import 'package:eros_app/features/verification/presentation/start_verification.dart';
import 'package:eros_app/features/verification/presentation/verification_links.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';

/// Opens [VerificationStatusScreen] on [context]'s navigator, named so that a decision push
/// tapped while it's already on top doesn't open it twice.
Future<void> openVerificationStatus(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: VerificationStatusScreen.routeName),
        builder: (_) => const VerificationStatusScreen(),
      ),
    );

/// Where the signed-in user stands with selfie verification, one layout per state (RFC-008 §7,
/// VF-F3). Opened from the Profile row, the Matches card and a decision push.
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
      backgroundColor: AppColors.background,
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
        return _Layout(icon: Icons.cloud_off_outlined, lines: const [VerificationCopy.statusFailed]);
      }
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    switch (value.state) {
      case VerificationState.notVerified:
      case VerificationState.unknown:
        return _Layout(
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
        return _Layout(
          icon: Icons.hourglass_top_outlined,
          title: VerificationCopy.inReview,
          lines: const [VerificationCopy.inReviewDetail],
        );
      case VerificationState.retry:
        final photosLink = value.reason == RetryReason.notSamePerson ||
            value.reason == RetryReason.profilePhotosUnsuitable;
        return _Layout(
          icon: Icons.refresh,
          title: VerificationCopy.retryTitle,
          lines: [VerificationCopy.retryReason(value.reason), ?_attemptsLine(value)],
          actionLabel: _canTry(value) ? VerificationCopy.tryAgain : null,
          onAction: _startVerification,
          secondaryLabel: photosLink ? VerificationCopy.updatePhotos : null,
          onSecondary: _openPhotoEditor,
        );
      case VerificationState.verified:
        return _Layout(icon: Icons.verified_outlined, title: VerificationCopy.verified);
      case VerificationState.locked:
        // No support link: the app has no support channel yet (see the PR).
        return _Layout(icon: Icons.support_agent, lines: const [VerificationCopy.locked]);
    }
  }

  /// Attempts left today, only when that's 1 or 0 (the server's count, never worked out here).
  String? _attemptsLine(VerificationStatus status) =>
      status.attemptsLeftToday <= 1 ? VerificationCopy.attemptsLeft(status.attemptsLeftToday) : null;

  /// No button that can only lead to "you've used your attempts".
  bool _canTry(VerificationStatus status) => status.canStart || status.attemptsLeftToday > 0;
}

/// One state's layout: an icon that only decorates, a heading, lines of text and up to two
/// actions.
class _Layout extends StatelessWidget {
  final IconData icon;
  final String? title;
  final List<String> lines;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _Layout({
    required this.icon,
    this.title,
    this.lines = const [],
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final actionLabel = this.actionLabel;
    final secondaryLabel = this.secondaryLabel;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 56, color: AppColors.primary)),
        const SizedBox(height: 24),
        if (title != null) ...[
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (final line in lines) ...[
          Text(
            line,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
        if (secondaryLabel != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onSecondary,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(secondaryLabel),
          ),
        ],
      ],
    );
  }
}
