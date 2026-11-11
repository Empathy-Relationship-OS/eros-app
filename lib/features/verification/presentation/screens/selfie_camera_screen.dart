import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/verification/data/selfie_camera.dart';
import 'package:eros_app/features/verification/data/selfie_processor.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';
import 'package:eros_app/features/verification/presentation/verification_links.dart';
import 'package:eros_app/features/verification/presentation/widgets/pose_illustration.dart';
import 'package:eros_app/features/verification/presentation/widgets/selfie_oval_guide.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_message_view.dart';

/// The front camera with the pose to copy (RFC-008 §5.4).
///
/// Front camera only: no flip, no gallery, no flash (primer rule 18). The camera is released
/// whenever the app leaves the foreground and opened again when it comes back, and when the
/// screen goes. [onCaptured] gets the temporary file, which the caller deletes (rule 19).
class SelfieCameraScreen extends ConsumerStatefulWidget {
  final VerificationPose pose;

  /// Why the last picture couldn't be used, shown above the shutter.
  final String? problem;
  final ValueChanged<String> onCaptured;
  final VoidCallback onClose;

  const SelfieCameraScreen({
    super.key,
    required this.pose,
    this.problem,
    required this.onCaptured,
    required this.onClose,
  });

  @override
  ConsumerState<SelfieCameraScreen> createState() => _SelfieCameraScreenState();
}

class _SelfieCameraScreenState extends ConsumerState<SelfieCameraScreen>
    with WidgetsBindingObserver {
  static final Logger _logger = Logger();

  /// The open camera, or null while it's opening, released or failed.
  SelfieCamera? _camera;

  /// Set while a camera is being opened, so a resume doesn't open a second one.
  Future<void>? _opening;
  SelfieCameraIssue? _issue;

  /// False while the app isn't in the foreground: a camera that finishes opening then is
  /// released straight away.
  bool _foreground = true;

  /// The user went to Settings to allow the camera, so coming back should try again. Without
  /// this, a refusal would reopen the camera, and on Android ask again, on every resume.
  bool _awaitingSettings = false;
  bool _taking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        if (_issue == null || _awaitingSettings) {
          _awaitingSettings = false;
          _open();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _foreground = false;
        if (_camera != null) setState(_release);
    }
  }

  void _open() {
    if (_opening != null || _camera != null) return;
    _opening = _openCamera().whenComplete(() => _opening = null);
  }

  Future<void> _openCamera() async {
    final camera = ref.read(selfieCameraFactoryProvider)();
    try {
      await camera.initialize();
    } on SelfieCameraException catch (e) {
      await camera.dispose();
      if (mounted) setState(() => _issue = e.issue);
      return;
    } catch (e) {
      _logger.w('📷 Selfie camera failed to open (${e.runtimeType})');
      await camera.dispose();
      if (mounted) setState(() => _issue = SelfieCameraIssue.failed);
      return;
    }
    if (!mounted || !_foreground) {
      await camera.dispose();
      return;
    }
    setState(() {
      _camera = camera;
      _issue = null;
    });
  }

  void _release() {
    final camera = _camera;
    _camera = null;
    camera?.dispose();
  }

  Future<void> _takePicture() async {
    final camera = _camera;
    if (camera == null || _taking) return;
    final processor = ref.read(selfieProcessorProvider);
    setState(() => _taking = true);
    try {
      final path = await camera.takePicture();
      if (!mounted) {
        // The flow closed while the picture was being taken: nobody else will delete it.
        await processor.discard(path);
        return;
      }
      widget.onCaptured(path);
    } catch (e) {
      _logger.w('📷 Selfie capture failed (${e.runtimeType})');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text(VerificationCopy.somethingWentWrong)));
      }
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  void _retryOpen() {
    setState(() => _issue = null);
    _open();
  }

  void _openSettings() {
    _awaitingSettings = true;
    ref.read(verificationLinksProvider).openSettings();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_issue != null)
            SafeArea(child: _issueView(_issue!))
          else if (camera == null)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else ...[
            camera.buildPreview(),
            const SelfieOvalGuide(),
          ],
          if (_issue == null)
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _closeButton(),
                  _PoseCard(pose: widget.pose),
                  const Spacer(),
                  if (widget.problem != null) _ProblemBanner(message: widget.problem!),
                  const _Tips(),
                  const SizedBox(height: 16),
                  Center(
                    child: _ShutterButton(
                      enabled: camera != null && !_taking,
                      onPressed: _takePicture,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            )
          else
            SafeArea(child: Align(alignment: Alignment.topLeft, child: _closeButton())),
        ],
      ),
    );
  }

  Widget _closeButton() => Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: VerificationCopy.closeLabel,
          onPressed: widget.onClose,
        ),
      );

  Widget _issueView(SelfieCameraIssue issue) => switch (issue) {
        SelfieCameraIssue.permissionDenied => VerificationMessageView(
            dark: true,
            icon: Icons.no_photography_outlined,
            message: VerificationCopy.cameraPermissionDenied,
            actionLabel: VerificationCopy.openSettings,
            onAction: _openSettings,
            secondaryLabel: VerificationCopy.closeLabel,
            onSecondary: widget.onClose,
          ),
        SelfieCameraIssue.noFrontCamera => VerificationMessageView(
            dark: true,
            icon: Icons.no_photography_outlined,
            message: VerificationCopy.noFrontCamera,
            actionLabel: VerificationCopy.closeLabel,
            onAction: widget.onClose,
          ),
        SelfieCameraIssue.failed => VerificationMessageView(
            dark: true,
            icon: Icons.no_photography_outlined,
            message: VerificationCopy.cameraFailed,
            actionLabel: VerificationCopy.tryAgain,
            onAction: _retryOpen,
            secondaryLabel: VerificationCopy.closeLabel,
            onSecondary: widget.onClose,
          ),
      };
}

/// The pose to copy: the bundled drawing and the server's instruction, read as one.
class _PoseCard extends StatelessWidget {
  final VerificationPose pose;

  const _PoseCard({required this.pose});

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              PoseIllustration(poseKey: pose.key, size: 72),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      VerificationCopy.poseHeading,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pose.instruction,
                      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// Why the last picture was bounced. Announced when the camera comes back with it.
class _ProblemBanner extends StatelessWidget {
  final String message;

  const _ProblemBanner({required this.message});

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const ExcludeSemantics(
                child: Icon(Icons.info_outline, color: AppColors.primaryOrangeDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Tips extends StatelessWidget {
  const _Tips();

  static const _icons = [Icons.wb_sunny_outlined, Icons.face_outlined];

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < VerificationCopy.cameraTips.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Icon(_icons[i % _icons.length], size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    VerificationCopy.cameraTips[i],
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      );
}

class _ShutterButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _ShutterButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: enabled,
        label: VerificationCopy.shutterLabel,
        onTap: enabled ? onPressed : null,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: enabled ? onPressed : null,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            padding: const EdgeInsets.all(5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ),
      );
}
