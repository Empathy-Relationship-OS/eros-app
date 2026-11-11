import 'dart:io';
import 'dart:typed_data';

import 'package:eros_app/features/verification/data/selfie_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A camera-sized JPEG, [width] by [height] as stored, with EXIF orientation [orientation].
List<int> cameraJpeg({required int width, required int height, int orientation = 1}) {
  final picture = img.Image(width: width, height: height);
  img.fill(picture, color: img.ColorRgb8(200, 120, 90));
  picture.exif.imageIfd.orientation = orientation;
  picture.exif.imageIfd['Model'] = img.IfdValueAscii('Test Phone');
  return img.encodeJpg(picture, quality: 95);
}

Uint8List encode(List<int> source) => encodeSelfie(Uint8List.fromList(source));

void main() {
  group('encodeSelfie', () {
    test('shrinks the longer side to 1600 px and keeps the shape', () {
      final out = img.decodeJpg(encode(cameraJpeg(width: 1080, height: 1920)))!;

      expect(out.height, SelfieProcessor.maxLongSide);
      expect(out.width, 900);
    });

    test('turns the picture upright from its EXIF orientation, then drops all EXIF', () {
      // Stored landscape, EXIF says "rotate 90°": a portrait selfie.
      final bytes = encode(cameraJpeg(width: 1920, height: 1080, orientation: 6));
      final out = img.decodeJpg(bytes)!;

      expect(out.width, 900);
      expect(out.height, 1600);
      expect(out.exif.imageIfd.hasOrientation, isFalse);
      expect(out.exif.imageIfd['Model'], isNull);
    });

    test('leaves a small picture its size', () {
      final out = img.decodeJpg(encode(cameraJpeg(width: 720, height: 1280)))!;

      expect([out.width, out.height], [720, 1280]);
    });

    test('is a JPEG well under 5 MB', () {
      final bytes = encode(cameraJpeg(width: 3024, height: 4032));

      expect(bytes.sublist(0, 2), [0xFF, 0xD8]);
      expect(bytes.length, lessThan(SelfieProcessor.maxBytes));
    });

    test('refuses something that isn\'t a picture', () {
      expect(
        () => encodeSelfie(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<SelfieEncodingException>()),
      );
    });
  });

  group('SelfieProcessor', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('selfie_processor_test');
      addTearDown(() => dir.delete(recursive: true));
    });

    test('prepare reads the file off the UI thread and returns the upload', () async {
      final file = File('${dir.path}/selfie.jpg')
        ..writeAsBytesSync(cameraJpeg(width: 1080, height: 1920));

      final out = img.decodeJpg(await const SelfieProcessor().prepare(file.path))!;

      expect(out.height, 1600);
      // Preparing never deletes or writes: the flow decides when the file goes.
      expect(dir.listSync().map((e) => e.path), [file.path]);
    });

    test('discard deletes the file, and is quiet when it\'s already gone', () async {
      final file = File('${dir.path}/selfie.jpg')..writeAsBytesSync([1, 2, 3]);

      await const SelfieProcessor().discard(file.path);
      expect(file.existsSync(), isFalse);

      await const SelfieProcessor().discard(file.path);
    });
  });
}
