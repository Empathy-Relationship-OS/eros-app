import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

/// The selfie couldn't be turned into an upload: not a picture, or still too big.
class SelfieEncodingException implements Exception {
  const SelfieEncodingException();

  @override
  String toString() => 'SelfieEncodingException';
}

/// Turns the camera's picture into the bytes to upload, and deletes it (RFC-008 §5.4).
///
/// The bytes only ever live in memory: nothing here writes the selfie anywhere, and the
/// camera's temporary file is deleted with [discard] whatever happens (primer rule 19).
class SelfieProcessor {
  const SelfieProcessor();

  /// The longer side of the uploaded selfie, at most.
  static const int maxLongSide = 1600;
  static const int jpegQuality = 85;

  /// The largest selfie we upload. A 1600 px JPEG is far smaller; this catches a broken encode.
  static const int maxBytes = 5 * 1024 * 1024;

  /// Reads the picture at [path] and returns it as an upright JPEG ready to upload. Runs off
  /// the UI thread. Throws [SelfieEncodingException].
  Future<Uint8List> prepare(String path) =>
      Isolate.run(() => encodeSelfie(File(path).readAsBytesSync()));

  /// Deletes the picture at [path]. Never throws: a file that's already gone is fine.
  Future<void> discard(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already deleted.
    }
  }
}

/// [source] as an upright JPEG whose longer side is at most [SelfieProcessor.maxLongSide], with
/// no metadata (the camera's EXIF can carry the phone model and a time). Throws
/// [SelfieEncodingException].
Uint8List encodeSelfie(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) throw const SelfieEncodingException();

  // Turn the pixels the way EXIF says, so the picture is upright once EXIF is dropped.
  var selfie = img.bakeOrientation(decoded);
  final longSide = math.max(selfie.width, selfie.height);
  if (longSide > SelfieProcessor.maxLongSide) {
    final landscape = selfie.width >= selfie.height;
    selfie = img.copyResize(
      selfie,
      width: landscape ? SelfieProcessor.maxLongSide : null,
      height: landscape ? null : SelfieProcessor.maxLongSide,
      interpolation: img.Interpolation.average,
    );
  }
  selfie.exif = img.ExifData();

  final jpeg = img.encodeJpg(selfie, quality: SelfieProcessor.jpegQuality);
  if (jpeg.length > SelfieProcessor.maxBytes) throw const SelfieEncodingException();
  return jpeg;
}

final selfieProcessorProvider = Provider<SelfieProcessor>((ref) => const SelfieProcessor());
