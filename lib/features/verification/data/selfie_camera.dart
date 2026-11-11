import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Why the selfie camera couldn't open.
enum SelfieCameraIssue {
  /// The user refused camera access, or it's restricted. Only Settings can change it.
  permissionDenied,

  /// This phone has no front camera.
  noFrontCamera,

  /// Anything else. Worth one more try.
  failed,
}

class SelfieCameraException implements Exception {
  final SelfieCameraIssue issue;

  const SelfieCameraException(this.issue);

  @override
  String toString() => 'SelfieCameraException(${issue.name})';
}

/// The front camera, for the verification selfie (RFC-008 §5.4, primer rule 18).
///
/// One instance per opening: the camera screen disposes it when it leaves the screen or the
/// app goes to the background, and makes a new one to reopen. There is deliberately no way to
/// pick another camera or a picture from the gallery.
abstract class SelfieCamera {
  /// Opens the front camera. Throws [SelfieCameraException].
  Future<void> initialize();

  /// The live preview, filling its parent. Only after [initialize].
  Widget buildPreview();

  /// Takes the picture and returns the path of the temporary file it was written to. The
  /// caller owns that file and deletes it (rule 19).
  Future<String> takePicture();

  Future<void> dispose();
}

/// Makes the camera for one opening. Overridden in tests with a fake.
final selfieCameraFactoryProvider = Provider<SelfieCamera Function()>(
  (ref) => PluginSelfieCamera.new,
);

/// [SelfieCamera] over the `camera` package.
class PluginSelfieCamera implements SelfieCamera {
  static final Logger _logger = Logger();

  CameraController? _controller;

  @override
  Future<void> initialize() async {
    try {
      final front = frontCamera(await availableCameras());
      if (front == null) throw const SelfieCameraException(SelfieCameraIssue.noFrontCamera);

      // 1080p: enough for a 1600 px selfie. Audio off, so no microphone permission is needed.
      final controller = CameraController(
        front,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      try {
        await controller.setFlashMode(FlashMode.off);
      } on CameraException {
        // Many front cameras have no flash to turn off.
      }
    } on CameraException catch (e) {
      _logger.w('📷 Selfie camera failed to open (${e.code})');
      throw SelfieCameraException(issueFor(e.code));
    }
  }

  /// The camera to use: the first front one, never any other (primer rule 18).
  @visibleForTesting
  static CameraDescription? frontCamera(List<CameraDescription> cameras) {
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) return camera;
    }
    return null;
  }

  /// The camera plugin's error codes (its README), as what the screen can do about them.
  @visibleForTesting
  static SelfieCameraIssue issueFor(String code) => switch (code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' =>
          SelfieCameraIssue.permissionDenied,
        _ => SelfieCameraIssue.failed,
      };

  @override
  Widget buildPreview() {
    final controller = _controller!;
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    // The preview size is landscape. Cover the screen in portrait, cropping the overflow.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  @override
  Future<String> takePicture() async {
    final file = await _controller!.takePicture();
    return file.path;
  }

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
