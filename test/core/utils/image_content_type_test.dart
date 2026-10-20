import 'dart:io';

import 'package:eros_app/core/constants/media_constants.dart';
import 'package:eros_app/core/utils/image_content_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Leading bytes for each format, padded so they are a realistic header length.
List<int> _padded(List<int> bytes) => [...bytes, ...List.filled(32, 0)];

final _jpeg = _padded([0xFF, 0xD8, 0xFF, 0xE0]);
final _png = _padded([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
final _webp = _padded([0x52, 0x49, 0x46, 0x46, 0x10, 0x20, 0x30, 0x40, 0x57, 0x45, 0x42, 0x50]);
// 'ftypheic' at offset 4, after a box size.
final _heic = _padded([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63]);
// 'GIF89a'
final _gif = _padded([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);

void main() {
  group('detectImageContentType', () {
    test('recognises each allowed format from its bytes', () {
      expect(detectImageContentType(path: 'a', headerBytes: _jpeg), 'image/jpeg');
      expect(detectImageContentType(path: 'a', headerBytes: _png), 'image/png');
      expect(detectImageContentType(path: 'a', headerBytes: _webp), 'image/webp');
      expect(detectImageContentType(path: 'a', headerBytes: _heic), 'image/heic');
    });

    test('trusts the bytes over a misleading extension', () {
      expect(
        detectImageContentType(path: '/tmp/photo.png', headerBytes: _jpeg),
        'image/jpeg',
      );
    });

    test('accepts an extension-less HEIC when the picker reports its MIME type', () {
      expect(
        detectImageContentType(path: '/tmp/IMG_0001', reportedMimeType: 'image/heic'),
        'image/heic',
      );
    });

    test('falls back to the extension when there are no bytes or reported type', () {
      expect(detectImageContentType(path: '/tmp/photo.webp'), 'image/webp');
      expect(detectImageContentType(path: '/tmp/photo.HEIF'), 'image/heif');
    });

    test('normalises image/jpg to image/jpeg', () {
      expect(
        detectImageContentType(path: '/tmp/x', reportedMimeType: 'image/jpg'),
        'image/jpeg',
      );
    });

    test('rejects a GIF', () {
      expect(detectImageContentType(path: '/tmp/anim.gif', headerBytes: _gif), isNull);
      expect(detectImageContentType(path: '/tmp/anim.gif'), isNull);
    });

    test('returns null instead of guessing JPEG when nothing is recognised', () {
      expect(detectImageContentType(path: '/tmp/mystery'), isNull);
      expect(
        detectImageContentType(path: '/tmp/mystery', headerBytes: _padded([1, 2, 3])),
        isNull,
      );
    });
  });

  group('detectFileContentType', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('content_type_test'));
    tearDown(() async => dir.delete(recursive: true));

    test('reads the leading bytes of the file', () async {
      final file = File('${dir.path}/no_extension');
      await file.writeAsBytes(_png);

      expect(await detectFileContentType(file), 'image/png');
    });
  });

  group('MediaConstants', () {
    test('matches the backend limits (RFC-004 D-12)', () {
      expect(MediaConstants.minFileSizeBytes, 100 * 1024);
      expect(MediaConstants.maxFileSizeBytes, 10 * 1024 * 1024);
      expect(MediaConstants.minPhotos, 3);
      expect(MediaConstants.maxPhotos, 6);
      expect(MediaConstants.allowedContentTypes, containsAll(['image/webp', 'image/heif']));
    });

    test('rejects a 50 KB photo with the 100 KB message', () {
      expect(MediaConstants.isFileSizeValid(50 * 1024), isFalse);
      expect(MediaConstants.isFileSizeValid(100 * 1024), isTrue);
      expect(MediaConstants.invalidSizeMessage, contains('100.0 KB'));
    });
  });
}
