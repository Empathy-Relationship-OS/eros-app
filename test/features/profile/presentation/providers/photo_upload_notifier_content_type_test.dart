import 'dart:io';

import 'package:eros_app/core/utils/image_content_type.dart';
import 'package:eros_app/features/profile/data/repositories/photo_repository.dart';
import 'package:eros_app/features/profile/domain/models/photo_models.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

/// Returns [next] from `pickImage`.
class _FakeImagePicker implements ImagePicker {
  XFile? next;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #pickImage) return Future<XFile?>.value(next);
    return super.noSuchMethod(invocation);
  }
}

/// Records the content type of every staged upload, then commits onto an empty set.
class _RecordingPhotoRepository implements PhotoRepository {
  final uploadedContentTypes = <String>[];

  @override
  Future<String> stageUpload({
    required File file,
    required String contentType,
    required int sizeBytes,
    required int displayOrder,
    void Function(double progress)? onProgress,
  }) async {
    uploadedContentTypes.add(contentType);
    return 'photos/u/${file.path.split('/').last}';
  }

  @override
  Future<MyPhotoCollection> getMyPhotos() async => const MyPhotoCollection(photos: [], revision: 'e3b0c44298fc1c14');

  @override
  Future<MyPhotoCollection> commitPhotoSet(String revision, List<PhotoSetEntry> entries) async => MyPhotoCollection(
        photos: [
          for (var i = 0; i < entries.length; i++)
            MyPhotoDTO(id: i + 1, mediaUrl: 'https://cdn/${entries[i].objectKey}', displayOrder: i + 1, isPrimary: i == 0),
        ],
        revision: 'rev-1',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// An HEIF 'ftyp' box with the 'heim' brand, which the mime package doesn't recognise.
final _heimHeader = [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x6D];

void main() {
  late Directory dir;
  late _FakeImagePicker picker;
  late _RecordingPhotoRepository repository;
  late PhotoUploadNotifier notifier;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('photo_notifier_test');
    picker = _FakeImagePicker();
    repository = _RecordingPhotoRepository();
    notifier = PhotoUploadNotifier(photoRepository: repository, imagePicker: picker);
  });

  tearDown(() async => dir.delete(recursive: true));

  /// An extension-less file with the 'heim' header, padded past the 100 KB minimum.
  Future<File> heimPhoto(String name) async {
    final file = File('${dir.path}/$name');
    await file.writeAsBytes([..._heimHeader, ...List.filled(120 * 1024, 0)]);
    return file;
  }

  test('an extension-less HEIC accepted at pick time is uploaded with that type', () async {
    final files = [await heimPhoto('a'), await heimPhoto('b'), await heimPhoto('c')];
    // Precondition: without the picker's MIME type, the file alone isn't recognised.
    expect(await detectFileContentType(files.first), isNull);

    for (final file in files) {
      picker.next = XFile(file.path, mimeType: 'image/heic');
      final picked = await notifier.pickImageFromGallery();
      expect(picked, isNotNull, reason: notifier.state.error);
      notifier.addPhoto(localPath: picked!.path);
    }

    expect(notifier.state.photos.map((p) => p.contentType), everyElement('image/heic'));
    expect(await notifier.submitPhotos(), isTrue, reason: notifier.state.error);
    expect(repository.uploadedContentTypes, ['image/heic', 'image/heic', 'image/heic']);
  });

  test('a replaced photo keeps the type accepted for the new file', () async {
    final first = await heimPhoto('first');
    final second = await heimPhoto('second');
    picker.next = XFile(first.path, mimeType: 'image/heic');
    notifier.addPhoto(localPath: (await notifier.pickImageFromGallery())!.path);
    picker.next = XFile(second.path, mimeType: 'image/heif');
    final replacement = await notifier.pickImageFromGallery();

    notifier.replacePhoto(0, replacement!.path);

    expect(notifier.state.photos.single.contentType, 'image/heif');
  });

  group('PhotoUploadDraft', () {
    test('keeps contentType through a JSON round trip', () {
      final draft = PhotoUploadDraft(localPath: '/p', displayOrder: 1, contentType: 'image/heic');

      expect(PhotoUploadDraft.fromJson(draft.toJson()).contentType, 'image/heic');
    });

    test('loads a draft saved before contentType existed', () {
      final draft = PhotoUploadDraft.fromJson({'localPath': '/p', 'displayOrder': 1});

      expect(draft.contentType, isNull);
      expect(draft.acceptedContentType, isNull);
    });

    test('acceptedContentType ignores a stored type that is no longer allowed', () {
      expect(
        PhotoUploadDraft(localPath: '/p', displayOrder: 1, contentType: 'image/gif').acceptedContentType,
        isNull,
      );
      expect(
        PhotoUploadDraft(localPath: '/p', displayOrder: 1, contentType: 'image/jpg').acceptedContentType,
        'image/jpeg',
      );
    });
  });
}
