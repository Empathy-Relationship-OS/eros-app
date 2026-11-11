import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/verification/data/selfie_processor.dart';
import 'package:eros_app/features/verification/domain/models/verification_failures.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_provider.dart';
import 'package:eros_app/features/verification/presentation/screens/selfie_camera_screen.dart';
import 'package:eros_app/features/verification/presentation/screens/selfie_review_screen.dart';
import 'package:eros_app/features/verification/presentation/screens/verification_consent_screen.dart';
import 'package:eros_app/features/verification/presentation/verification_links.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_message_view.dart';

enum _Step { consent, camera, review, message }

/// How the flow ended, or why it stopped.
enum _Outcome { submitted, verified, inReview, photosRequired, limit, locked, error }

/// Consent → camera → review → result (RFC-008 §5.4, VF-F2). Open it with `startVerification`.
///
/// Everything about the attempt lives in this screen's state and goes with it: the upload link,
/// the picture's temporary file (deleted whatever happens, primer rule 19). The verification
/// state is only ever read from the server (rule 22): this screen watches the status provider,
/// which keeps it alive while the flow is open, and refreshes it after a submit or a refusal.
class VerificationFlowScreen extends ConsumerStatefulWidget {
  const VerificationFlowScreen({super.key});

  @override
  ConsumerState<VerificationFlowScreen> createState() => _VerificationFlowScreenState();
}

class _VerificationFlowScreenState extends ConsumerState<VerificationFlowScreen> {
  static final Logger _logger = Logger();

  late final SelfieProcessor _processor;

  _Step _step = _Step.consent;

  /// Starting an attempt (after consent, or to try again).
  bool _starting = false;

  /// Resizing, uploading and submitting the picture.
  bool _sending = false;

  /// The choice made on the consent screen, kept for a fresh attempt on retry.
  bool _automatedCheck = true;
  VerificationAttemptStart? _attempt;

  /// Why the last picture couldn't be used, for the camera screen.
  String? _problem;

  /// The picture's temporary file while it's still on disk. Deleted on retake, once uploaded
  /// (or not), and when the flow closes.
  String? _capturePath;

  /// The picture shown on the review screen. It stays on screen while sending, after its file
  /// is gone.
  String? _reviewPath;

  _Outcome? _outcome;
  Duration? _retryAfter;

  @override
  void initState() {
    super.initState();
    _processor = ref.read(selfieProcessorProvider);
    // A status someone else already loaded may be stale: the flow needs the current state and
    // consent version. A status loaded just now for this screen is current already.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final status = ref.read(verificationStatusProvider);
      if (status.hasValue && !status.isLoading) _refreshStatus();
    });
  }

  @override
  void dispose() {
    final path = _capturePath;
    _capturePath = null;
    if (path != null) _processor.discard(path);
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (!mounted) return;
    await ref.read(verificationStatusNotifierProvider).refresh();
  }

  VerificationStatus? get _status => ref.read(verificationStatusProvider).valueOrNull;

  void _close() => Navigator.of(context).pop();

  void _show(_Outcome outcome, {Duration? retryAfter}) {
    if (!mounted) return;
    setState(() {
      _step = _Step.message;
      _outcome = outcome;
      _retryAfter = retryAfter;
      _starting = false;
      _sending = false;
    });
  }

  /// Starts an attempt with the consent given, then opens the camera, showing [problem] there.
  Future<void> _start({required bool automatedCheck, String? problem}) async {
    setState(() {
      _automatedCheck = automatedCheck;
      _starting = true;
    });
    try {
      final attempt = await ref.read(verificationRepositoryProvider).startAttempt(
            consentVersion: _status?.consentVersion ?? '',
            automatedCheck: automatedCheck,
          );
      if (!mounted) return;
      setState(() {
        _attempt = attempt;
        _problem = problem;
        _step = _Step.camera;
        _starting = false;
      });
    } catch (e) {
      await _fail(e);
    }
  }

  /// Shows what a refusal means. Nothing here is decided locally: the state is refetched.
  Future<void> _fail(Object e) async {
    switch (e) {
      case PhotosRequiredFailure():
        _show(_Outcome.photosRequired);
      case VerificationLimitFailure(:final retryAfter):
        await _refreshStatus();
        if (_status?.state == VerificationState.locked) {
          _show(_Outcome.locked);
        } else {
          _show(_Outcome.limit, retryAfter: retryAfter);
        }
      case AlreadyVerifiedFailure():
        await _refreshStatus();
        _show(_Outcome.verified);
      case ConflictException():
        // An attempt is already with staff.
        await _refreshStatus();
        _show(_Outcome.inReview);
      default:
        // An expired upload link, no connection, a server error: start again on retry.
        _logger.w('🤳 Verification step failed (${e.runtimeType})');
        _show(_Outcome.error);
    }
  }

  void _onCaptured(String path) {
    setState(() {
      _capturePath = path;
      _reviewPath = path;
      _step = _Step.review;
    });
  }

  Future<void> _retake() async {
    await _discardCapture();
    if (!mounted) return;
    setState(() {
      _problem = null;
      _reviewPath = null;
      _step = _Step.camera;
    });
  }

  Future<void> _discardCapture() async {
    final path = _capturePath;
    _capturePath = null;
    if (path != null) await _processor.discard(path);
  }

  /// Resize, upload, submit: one progress state for all three.
  Future<void> _use() async {
    if (_sending) return;
    final attempt = _attempt!;
    final path = _capturePath!;
    final repository = ref.read(verificationRepositoryProvider);
    setState(() => _sending = true);
    try {
      try {
        final bytes = await _processor.prepare(path);
        await repository.uploadSelfie(attempt, bytes);
      } finally {
        await _discardCapture();
      }
      final submitted = await repository.submit(attempt.attemptId);
      await _refreshStatus();
      final verified =
          submitted == VerificationState.verified || (_status?.isVerified ?? false);
      _show(verified ? _Outcome.verified : _Outcome.submitted);
    } on SelfieUnusableFailure catch (f) {
      final problem = VerificationCopy.selfieProblem(f.problem);
      final upload = f.upload;
      if (!mounted) return;
      if (upload == null) {
        // No fresh link to retake with: a new attempt, then the camera with the problem.
        setState(() => _sending = false);
        await _start(automatedCheck: _automatedCheck, problem: problem);
        return;
      }
      setState(() {
        _attempt = attempt.withUpload(upload, expiresAt: f.expiresAt);
        _problem = problem;
        _sending = false;
        _reviewPath = null;
        _step = _Step.camera;
      });
    } catch (e) {
      await _fail(e);
    }
  }

  Future<void> _addPhotos() async {
    await ref.read(verificationLinksProvider).openPhotoEditor(context);
    if (!mounted) return;
    setState(() {
      _step = _Step.consent;
      _outcome = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watched on every step, so the auto-disposing status stays alive while the flow is open.
    final status = ref.watch(verificationStatusProvider);
    return PopScope(
      canPop: _step != _Step.review && !_sending,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == _Step.review && !_sending) _retake();
      },
      child: _buildStep(status),
    );
  }

  Widget _buildStep(AsyncValue<VerificationStatus> status) {
    if (_starting && _step != _Step.consent) return const _Loading();
    switch (_step) {
      case _Step.consent:
        return _consentOrStatus(status);
      case _Step.camera:
        return SelfieCameraScreen(
          pose: _attempt!.pose,
          problem: _problem,
          onCaptured: _onCaptured,
          onClose: _close,
        );
      case _Step.review:
        return SelfieReviewScreen(
          path: _reviewPath!,
          sending: _sending,
          onUse: _use,
          onRetake: _retake,
        );
      case _Step.message:
        return _outcomeView(_outcome!);
    }
  }

  /// Consent, unless the status says there's nothing to start.
  Widget _consentOrStatus(AsyncValue<VerificationStatus> status) {
    final current = status.valueOrNull;
    if (current == null) {
      if (!status.hasError) return const _Loading();
      return _MessagePage(
        child: VerificationMessageView(
          icon: Icons.error_outline,
          message: VerificationCopy.somethingWentWrong,
          actionLabel: VerificationCopy.tryAgain,
          onAction: _refreshStatus,
          secondaryLabel: VerificationCopy.closeLabel,
          onSecondary: _close,
        ),
      );
    }
    switch (current.state) {
      case VerificationState.verified:
        return _outcomeView(_Outcome.verified);
      case VerificationState.inReview:
        return _outcomeView(_Outcome.inReview);
      case VerificationState.locked:
        return _outcomeView(_Outcome.locked);
      case VerificationState.notVerified:
      case VerificationState.retry:
      case VerificationState.unknown:
        if (!current.canStart && current.attemptsLeftToday == 0) {
          return _outcomeView(_Outcome.limit);
        }
    }
    return VerificationConsentScreen(
      busy: _starting,
      onAgree: () => _start(automatedCheck: true),
      onPersonInstead: () => _start(automatedCheck: false),
      onPrivacyPolicy: () => ref.read(verificationLinksProvider).openPrivacyPolicy(),
      onClose: _close,
    );
  }

  Widget _outcomeView(_Outcome outcome) {
    VerificationMessageView done(IconData icon, String message) => VerificationMessageView(
          icon: icon,
          message: message,
          actionLabel: VerificationCopy.done,
          onAction: _close,
        );
    return _MessagePage(
      child: switch (outcome) {
        _Outcome.submitted => done(Icons.hourglass_top, VerificationCopy.submitted),
        _Outcome.verified => done(Icons.verified_outlined, VerificationCopy.verified),
        _Outcome.inReview => done(Icons.hourglass_top, VerificationCopy.inReview),
        _Outcome.limit => done(Icons.schedule, VerificationCopy.limitReached(_retryAfter)),
        _Outcome.locked => done(Icons.support_agent, VerificationCopy.locked),
        _Outcome.photosRequired => VerificationMessageView(
            icon: Icons.photo_library_outlined,
            title: VerificationCopy.photosRequiredTitle,
            message: VerificationCopy.photosRequiredBody,
            actionLabel: VerificationCopy.photosRequiredAction,
            onAction: _addPhotos,
            secondaryLabel: VerificationCopy.closeLabel,
            onSecondary: _close,
          ),
        _Outcome.error => VerificationMessageView(
            icon: Icons.error_outline,
            message: VerificationCopy.somethingWentWrong,
            actionLabel: VerificationCopy.tryAgain,
            onAction: () => _start(automatedCheck: _automatedCheck),
            secondaryLabel: VerificationCopy.closeLabel,
            onSecondary: _close,
          ),
      },
    );
  }
}

class _MessagePage extends StatelessWidget {
  final Widget child;

  const _MessagePage({required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: child),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
}
