import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/constants/support_contact.dart';
import 'package:eros_app/features/verification/domain/models/verification_failures.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_provider.dart';
import 'package:eros_app/features/verification/presentation/verification_links.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_state_layout.dart';

/// Why the last Confirm my age tap didn't get as far as Didit's page.
enum _StartProblem { limit, unavailable, couldNotOpen, failed }

/// "One more step: confirm your age" (RFC-009 §5.3.2, CF-F2): the `AGE_CHECK` state, on the
/// status screen and in the flow straight after a submit.
///
/// With [VerificationStatus.canStartIdCheck], Confirm my age asks the server for Didit's ID
/// check link and opens it in the browser. The link is held for that one call and never kept
/// (CF primer rule 19). The ID result reaches the server by Didit's webhook, so the state is
/// refetched when the app comes back to the front (rule 20), never worked out here. Without it,
/// the operator will call, and the user can email support.
class AgeCheckStep extends ConsumerStatefulWidget {
  final VerificationStatus status;

  const AgeCheckStep({super.key, required this.status});

  @override
  ConsumerState<AgeCheckStep> createState() => _AgeCheckStepState();
}

class _AgeCheckStepState extends ConsumerState<AgeCheckStep> {
  static final Logger _logger = Logger();

  late final AppLifecycleListener _lifecycle;

  bool _starting = false;
  _StartProblem? _problem;
  Duration? _retryAfter;

  /// The server said the operator will call, though the status we hold still offered the link.
  bool _byStaff = false;

  /// Set when the mail app wouldn't open, so the address is shown instead.
  bool _showAddress = false;

  @override
  void initState() {
    super.initState();
    // Didit's webhook may have landed while the user was in the browser.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_refresh()));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await ref.read(verificationStatusNotifierProvider).refresh();
  }

  Future<void> _confirmMyAge() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _problem = null;
    });
    final links = ref.read(verificationLinksProvider);
    _StartProblem? problem;
    Duration? retryAfter;
    try {
      final link = await ref.read(verificationRepositoryProvider).startAgeCheck();
      if (!await links.openAgeCheck(link.url)) problem = _StartProblem.couldNotOpen;
    } on AgeCheckLimitFailure catch (f) {
      problem = _StartProblem.limit;
      retryAfter = f.retryAfter;
    } on AgeCheckUnavailableFailure {
      problem = _StartProblem.unavailable;
    } on AgeCheckByStaffFailure {
      if (mounted) setState(() => _byStaff = true);
      await _refresh();
    } on AgeCheckNotNeededFailure {
      // The age has passed or the attempt moved on: the server's state says where to now.
      await _refresh();
    } catch (e) {
      _logger.w('🪪 Age check didn\'t start (${e.runtimeType})');
      problem = _StartProblem.failed;
    }
    if (!mounted) return;
    setState(() {
      _starting = false;
      _problem = problem;
      _retryAfter = retryAfter;
    });
  }

  Future<void> _emailSupport() async {
    final opened = await ref
        .read(verificationLinksProvider)
        .emailSupport(subject: VerificationCopy.ageCheckEmailSubject);
    if (!opened && mounted) setState(() => _showAddress = true);
  }

  String? get _problemLine => switch (_problem) {
        null => null,
        _StartProblem.limit => VerificationCopy.ageCheckLimit(_retryAfter),
        _StartProblem.unavailable => VerificationCopy.ageCheckUnavailable,
        _StartProblem.couldNotOpen => VerificationCopy.ageCheckCouldNotOpen,
        _StartProblem.failed => VerificationCopy.ageCheckFailed,
      };

  @override
  Widget build(BuildContext context) {
    final address = _showAddress ? VerificationCopy.noMailApp(SupportContact.email) : null;

    if (!widget.status.canStartIdCheck || _byStaff) {
      return VerificationStateLayout(
        icon: Icons.support_agent,
        title: VerificationCopy.ageCheckTitle,
        lines: [VerificationCopy.ageCheckByStaff, ?address],
        secondaryLabel: VerificationCopy.emailSupport,
        onSecondary: _emailSupport,
      );
    }

    final problem = _problemLine;
    return VerificationStateLayout(
      icon: Icons.badge_outlined,
      title: VerificationCopy.ageCheckTitle,
      lines: [
        VerificationCopy.ageCheckBody,
        problem ?? VerificationCopy.ageCheckComeBack,
        ?address,
      ],
      actionLabel: VerificationCopy.confirmMyAge,
      actionLoading: _starting,
      onAction: _confirmMyAge,
      // Support is offered once something has gone wrong, not before.
      secondaryLabel: problem == null ? null : VerificationCopy.emailSupport,
      onSecondary: _emailSupport,
    );
  }
}
