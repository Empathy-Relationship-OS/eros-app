import 'dart:typed_data';

import 'package:eros_app/features/verification/data/selfie_camera.dart';
import 'package:eros_app/features/verification/data/selfie_processor.dart';
import 'package:eros_app/features/verification/presentation/verification_links.dart';
import 'package:flutter/material.dart';

/// Hands out [FakeSelfieCamera]s and remembers every one, so a test can tell how many were
/// opened, and whether any is still open.
class FakeCameraRig {
  final List<FakeSelfieCamera> made = [];

  /// The next cameras fail to open with this, until it's cleared.
  SelfieCameraIssue? failWith;
  int _pictures = 0;

  SelfieCamera create() {
    final camera = FakeSelfieCamera(this);
    made.add(camera);
    return camera;
  }

  int get opened => made.where((c) => c.initialized).length;
  int get open => made.where((c) => c.initialized && !c.disposed).length;

  /// The path of picture [n], counting from 1.
  static String picturePath(int n) => '/tmp/fake-selfie-$n.jpg';
}

class FakeSelfieCamera implements SelfieCamera {
  final FakeCameraRig _rig;
  bool initialized = false;
  bool disposed = false;

  FakeSelfieCamera(this._rig);

  static const previewKey = Key('fake-camera-preview');

  @override
  Future<void> initialize() async {
    final issue = _rig.failWith;
    if (issue != null) throw SelfieCameraException(issue);
    initialized = true;
  }

  @override
  Widget buildPreview() => const ColoredBox(key: previewKey, color: Colors.grey);

  @override
  Future<String> takePicture() async => FakeCameraRig.picturePath(++_rig._pictures);

  @override
  Future<void> dispose() async => disposed = true;
}

/// Records what was prepared and deleted instead of touching files.
class FakeSelfieProcessor implements SelfieProcessor {
  final List<String> prepared = [];
  final List<String> discarded = [];

  /// Thrown by [prepare] when set.
  Object? failWith;

  static final Uint8List bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

  @override
  Future<Uint8List> prepare(String path) async {
    prepared.add(path);
    final failure = failWith;
    if (failure != null) throw failure;
    return bytes;
  }

  @override
  Future<void> discard(String path) async => discarded.add(path);
}

class FakeVerificationLinks implements VerificationLinks {
  int privacyPolicy = 0;
  int settings = 0;
  int photoEditor = 0;

  @override
  Future<void> openPrivacyPolicy() async => privacyPolicy++;

  @override
  Future<void> openSettings() async => settings++;

  @override
  Future<void> openPhotoEditor(BuildContext context) async => photoEditor++;
}
