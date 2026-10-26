import 'dart:io';

import 'package:eros_app/features/profile/data/repositories/photo_repository.dart';
import 'package:eros_app/features/profile/domain/models/photo_models.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

/// The revision of a set with no photos, as the backend computes it.
const emptyRevision = 'e3b0c44298fc1c14';

/// Stages each photo as `photos/u/<file name>`, failing the names in [failing]; GET serves
/// [stored]; PUT records the commit and stores the set.
class FakeRepository implements PhotoRepository {
  final failing = <String>{};
  final staged = <String>[];
  final commits = <(String, List<PhotoSetEntry>)>[];
  MyPhotoCollection stored = const MyPhotoCollection(photos: [], revision: emptyRevision);
  Object? commitError;
  int inFlight = 0;
  int peakInFlight = 0;

  @override
  Future<String> stageUpload({
    required File file,
    required String contentType,
    required int sizeBytes,
    required int displayOrder,
    void Function(double progress)? onProgress,
  }) async {
    final name = file.path.split('/').last;
    inFlight++;
    peakInFlight = inFlight > peakInFlight ? inFlight : peakInFlight;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    inFlight--;
    staged.add(name);
    if (failing.contains(name)) throw PhotoRepositoryException('Upload failed. Tap to try again.');
    return 'photos/u/$name';
  }

  @override
  Future<MyPhotoCollection> getMyPhotos() async => stored;

  @override
  Future<MyPhotoCollection> commitPhotoSet(String revision, List<PhotoSetEntry> entries) async {
    commits.add((revision, entries));
    if (commitError != null) throw commitError!;
    stored = MyPhotoCollection(
      photos: [
        for (var i = 0; i < entries.length; i++)
          MyPhotoDTO(
            id: 100 + i,
            mediaUrl: 'https://cdn.example.com/${entries[i].objectKey}?Expires=1&Signature=x',
            displayOrder: i + 1,
            isPrimary: i == 0,
          ),
      ],
      revision: 'rev-${commits.length}',
    );
    return stored;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedPicker implements ImagePicker {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory dir;
  late FakeRepository repository;
  late PhotoUploadNotifier notifier;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('photo_submit_test');
    repository = FakeRepository();
    notifier = PhotoUploadNotifier(photoRepository: repository, imagePicker: _UnusedPicker());
  });

  tearDown(() async => dir.delete(recursive: true));

  /// Adds [count] JPEG drafts named p1.jpg, p2.jpg, ...
  Future<void> givenPhotos(int count) async {
    for (var i = 1; i <= count; i++) {
      final file = File('${dir.path}/p$i.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, ...List.filled(120 * 1024, 0)]);
      notifier.addPhoto(localPath: file.path);
    }
  }

  List<String> keys(Iterable<int> numbers) => [for (final n in numbers) 'photos/u/p$n.jpg'];

  test('stages every photo, then commits them all once, in order, onto the empty set', () async {
    await givenPhotos(4);

    expect(await notifier.submitPhotos(), isTrue, reason: notifier.state.error);

    expect(repository.staged.toSet(), {'p1.jpg', 'p2.jpg', 'p3.jpg', 'p4.jpg'});
    expect(repository.commits.single.$1, emptyRevision);
    expect(repository.commits.single.$2.map((e) => e.objectKey), keys([1, 2, 3, 4]));
    expect(repository.commits.single.$2.every((e) => e.photoId == null), isTrue);
    expect(notifier.state.photos.map((p) => p.mediaId), [100, 101, 102, 103]);
    expect(notifier.state.isUploading, isFalse);
  });

  test('uploads at most 3 at a time', () async {
    await givenPhotos(6);

    await notifier.submitPhotos();

    expect(repository.peakInFlight, PhotoUploadNotifier.maxParallelUploads);
  });

  test('when photo 3 of 5 fails, nothing is committed; a retry stages only photo 3, then commits all 5', () async {
    await givenPhotos(5);
    repository.failing.add('p3.jpg');

    expect(await notifier.submitPhotos(), isFalse);
    expect(repository.commits, isEmpty);
    expect(notifier.state.error, 'One photo didn\'t upload. Please try again.');
    expect(notifier.state.photos.map((p) => p.isUploaded), [true, true, false, true, true]);

    repository.failing.clear();
    repository.staged.clear();
    expect(await notifier.submitPhotos(), isTrue, reason: notifier.state.error);

    expect(repository.staged, ['p3.jpg']);
    expect(repository.commits.single.$2.map((e) => e.objectKey), keys([1, 2, 3, 4, 5]));
  });

  test('progress counts uploaded photos up to the total', () async {
    await givenPhotos(3);
    final progress = <(int, int)>[];

    await notifier.submitPhotos(onProgress: (uploaded, total) => progress.add((uploaded, total)));

    expect(progress.first, (0, 3));
    expect(progress.last, (3, 3));
  });

  test('a refused commit forgets the uploads, so the next try uploads everything again', () async {
    await givenPhotos(3);
    repository.commitError = PhotoRepositoryException('Upload photos/u/p2.jpg wasn\'t found. Upload the photo again.');

    expect(await notifier.submitPhotos(), isFalse);
    expect(notifier.state.error, contains('wasn\'t found'));
    expect(notifier.state.photos.every((p) => !p.isUploaded), isTrue);

    repository.commitError = null;
    repository.staged.clear();
    expect(await notifier.submitPhotos(), isTrue);
    expect(repository.staged.length, 3);
  });

  test('after a commit whose response was lost, a retry sees the photos saved and commits nothing', () async {
    await givenPhotos(3);
    await notifier.submitPhotos();
    // As if the response had never arrived: the drafts still hold their keys.
    final saved = repository.stored;

    expect(await notifier.submitPhotos(), isTrue);

    expect(repository.commits.length, 1);
    expect(identical(repository.stored, saved), isTrue);
  });

  test('a conflict says so and commits nothing more', () async {
    await givenPhotos(3);
    repository.commitError = PhotoSetConflictException();

    expect(await notifier.submitPhotos(), isFalse);

    expect(notifier.state.error, contains('changed on another device'));
    expect(notifier.state.photos.every((p) => p.isUploaded), isTrue, reason: 'uploads are kept for a retry');
  });

  test('fewer than 3 photos uploads nothing', () async {
    await givenPhotos(2);

    expect(await notifier.submitPhotos(), isFalse);

    expect(repository.staged, isEmpty);
    expect(repository.commits, isEmpty);
  });

  test('reordering after a failed try keeps the uploads and commits the new order', () async {
    await givenPhotos(3);
    repository.failing.add('p2.jpg');
    await notifier.submitPhotos();

    notifier.reorderPhotos(2, 0); // p3, p1, p2
    repository.failing.clear();
    repository.staged.clear();
    await notifier.submitPhotos();

    expect(repository.staged, ['p2.jpg']);
    expect(repository.commits.single.$2.map((e) => e.objectKey), keys([3, 1, 2]));
  });
}
