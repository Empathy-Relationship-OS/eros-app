import 'dart:io';

import 'package:camera/camera.dart';
import 'package:eros_app/features/verification/data/selfie_camera.dart';
import 'package:flutter_test/flutter_test.dart';

CameraDescription _camera(String name, CameraLensDirection direction) =>
    CameraDescription(name: name, lensDirection: direction, sensorOrientation: 90);

void main() {
  group('PluginSelfieCamera.frontCamera', () {
    test('picks the front camera, wherever it is in the list', () {
      final front = _camera('1', CameraLensDirection.front);
      final cameras = [
        _camera('0', CameraLensDirection.back),
        _camera('2', CameraLensDirection.external),
        front,
        _camera('3', CameraLensDirection.front),
      ];

      expect(PluginSelfieCamera.frontCamera(cameras), same(front));
    });

    test('never falls back to another camera', () {
      expect(
        PluginSelfieCamera.frontCamera([
          _camera('0', CameraLensDirection.back),
          _camera('2', CameraLensDirection.external),
        ]),
        isNull,
      );
      expect(PluginSelfieCamera.frontCamera([]), isNull);
    });
  });

  test('the plugin\'s permission codes mean permission denied; others are a failure', () {
    for (final code in [
      'CameraAccessDenied',
      'CameraAccessDeniedWithoutPrompt',
      'CameraAccessRestricted',
    ]) {
      expect(PluginSelfieCamera.issueFor(code), SelfieCameraIssue.permissionDenied, reason: code);
    }
    expect(PluginSelfieCamera.issueFor('cameraNotFound'), SelfieCameraIssue.failed);
  });

  // Primer rule 18: the selfie only ever comes from the in-app camera, never a picker, and is
  // never saved to the photo library.
  test('nothing in the verification feature can pick or save a picture', () {
    final sources = Directory('lib/features/verification')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in sources) {
      final source = file.readAsStringSync();
      for (final banned in ['image_picker', 'file_picker', 'gallery_saver', 'image_gallery']) {
        expect(source, isNot(contains(banned)), reason: '${file.path} uses $banned');
      }
    }
  });
}
