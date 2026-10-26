import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eros_app/features/profile/data/repositories/photo_repository.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/models/my_profile.dart';
import 'package:eros_app/features/profile/domain/models/photo_models.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_edit_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

MyPhotoDTO photo(int id, int position, {bool verification = false}) => MyPhotoDTO(
      id: id,
      mediaUrl: 'https://cdn/photos/u/$id.jpg?sig=$position',
      displayOrder: position,
      isPrimary: position == 1,
      isVerificationPhoto: verification,
    );

MyPhotoCollection collection(List<int> ids, {String revision = 'rev-1', bool verificationReset = false}) =>
    MyPhotoCollection(
      photos: [for (var i = 0; i < ids.length; i++) photo(ids[i], i + 1)],
      revision: revision,
      verificationReset: verificationReset,
    );

/// GET serves [stored]; each staged upload waits for the test to finish it; PUT records the
/// commit and returns [commitResult] or throws [commitError].
class FakePhotoRepository implements PhotoRepository {
  MyPhotoCollection stored = collection([11, 12, 13]);
  int loads = 0;
  final uploads = <Completer<String>>[];
  final uploadPositions = <int>[];
  final progressCallbacks = <void Function(double)?>[];
  final commits = <(String, List<PhotoSetEntry>)>[];
  MyPhotoCollection? commitResult;
  Object? commitError;

  /// When set, the commit waits for this.
  Completer<MyPhotoCollection>? heldCommit;

  /// When set, every load after the first throws it.
  Object? loadError;

  @override
  Future<MyPhotoCollection> getMyPhotos() async {
    loads++;
    if (loadError != null && loads > 1) throw loadError!;
    return stored;
  }

  @override
  Future<String> stageUpload({
    required File file,
    required String contentType,
    required int sizeBytes,
    required int displayOrder,
    void Function(double progress)? onProgress,
  }) {
    final completer = Completer<String>();
    uploads.add(completer);
    uploadPositions.add(displayOrder);
    progressCallbacks.add(onProgress);
    return completer.future;
  }

  @override
  Future<MyPhotoCollection> commitPhotoSet(String revision, List<PhotoSetEntry> entries) async {
    commits.add((revision, entries));
    if (commitError != null) throw commitError!;
    if (heldCommit != null) return heldCommit!.future;
    return commitResult!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Returns queued photos, as if the user picked them.
class FakePhotoPicker extends PhotoPicker {
  final queue = <Object?>[];
  FakePhotoPicker() : super(ImagePicker());

  @override
  Future<PickedPhoto?> pick() async {
    final next = queue.removeAt(0);
    if (next is PhotoPickException) throw next;
    if (next is Future<PickedPhoto?>) return next;
    return next as PickedPhoto?;
  }
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<MyProfile> getCurrentUser() async => MyProfile.fromJson(
        jsonDecode(File('test/fixtures/users/get_users_me.json').readAsStringSync()) as Map<String, dynamic>,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getPublicProfile) return Completer<Never>().future;
    return super.noSuchMethod(invocation);
  }
}

/// Counts builds: invalidating re-runs `build` on the same notifier.
class _CountingMyProfile extends MyProfileNotifier {
  final void Function() onBuild;
  _CountingMyProfile(this.onBuild);

  @override
  Future<MyProfile> build() {
    onBuild();
    return super.build();
  }
}

PickedPhoto picked(String name) =>
    PickedPhoto(path: '/tmp/$name.jpg', contentType: 'image/jpeg', sizeBytes: 300000);

void main() {
  late FakePhotoRepository repository;
  late FakePhotoPicker picker;
  late ProviderContainer container;
  late int userProfileBuilds;
  late int myProfileBuilds;

  PhotoEditState state() => container.read(photoEditProvider);
  PhotoEditNotifier notifier() => container.read(photoEditProvider.notifier);

  Future<void> loaded() async {
    container.listen(photoEditProvider, (_, _) {});
    await pumpEventQueue();
  }

  setUp(() {
    repository = FakePhotoRepository();
    picker = FakePhotoPicker();
    userProfileBuilds = 0;
    myProfileBuilds = 0;
    final profileRepository = _FakeProfileRepository();
    container = ProviderContainer(overrides: [
      photoRepositoryProvider.overrideWithValue(repository),
      photoPickerProvider.overrideWithValue(picker),
      profileRepositoryProvider.overrideWithValue(profileRepository),
      userProfileProvider.overrideWith((ref) {
        userProfileBuilds++;
        return UserProfileNotifier(profileRepository: profileRepository, userId: 'u');
      }),
      myProfileProvider.overrideWith(() => _CountingMyProfile(() => myProfileBuilds++)),
    ]);
  });

  tearDown(() => container.dispose());

  group('load', () {
    test('shows the saved photos in order, unchanged', () async {
      repository.stored = MyPhotoCollection(
        photos: [photo(11, 1), photo(12, 2, verification: true), photo(13, 3)],
        revision: 'rev-1',
      );
      await loaded();

      expect(state().isLoading, isFalse);
      expect(state().photos.map((p) => (p as SavedPhoto).id), [11, 12, 13]);
      expect((state().photos[1] as SavedPhoto).isVerificationPhoto, isTrue);
      expect(state().revision, 'rev-1');
      expect(state().isDirty, isFalse);
      expect(state().canSave, isFalse);
    });
  });

  group('Save is enabled', () {
    test('only once a new photo has finished uploading', () async {
      await loaded();
      picker.queue.add(picked('a'));

      await notifier().add();
      expect(state().photos.last, isA<StagedPhoto>());
      expect((state().photos.last as StagedPhoto).status, isA<StageUploading>());
      expect(state().isDirty, isTrue);
      expect(state().canSave, isFalse, reason: 'still uploading');

      repository.uploads.single.complete('photos/u/a.jpg');
      await pumpEventQueue();
      expect((state().photos.last as StagedPhoto).status, isA<StageReady>());
      expect(state().canSave, isTrue);
    });

    test('not with 2 photos', () async {
      await loaded();
      notifier().remove(0);

      expect(state().photos.length, 2);
      expect(state().isDirty, isTrue);
      expect(state().canSave, isFalse);
    });

    test('not with 7 photos', () async {
      repository.stored = collection([1, 2, 3, 4, 5, 6]);
      await loaded();
      picker.queue.add(picked('extra'));

      await notifier().add();

      expect(state().photos.length, 6, reason: 'a 7th is never added');
      expect(repository.uploads, isEmpty);
    });

    test('not when nothing has changed', () async {
      await loaded();
      notifier().reorder(0, 2);
      notifier().reorder(2, 0);

      expect(state().isDirty, isFalse);
      expect(state().canSave, isFalse);
    });

    test('not while a save is running', () async {
      await loaded();
      notifier().reorder(0, 1);
      final pending = Completer<MyPhotoCollection>();
      repository.heldCommit = pending;
      final future = notifier().save();

      expect(state().isSaving, isTrue);
      expect(state().canSave, isFalse);
      pending.complete(collection([12, 11, 13], revision: 'rev-2'));
      await future;
    });
  });

  group('while saving', () {
    test('remove, reorder and add are ignored', () async {
      repository.stored = collection([11, 12, 13, 14]);
      await loaded();
      notifier().remove(3);
      final pending = Completer<MyPhotoCollection>();
      repository.heldCommit = pending;
      final saving = notifier().save();

      notifier().remove(0);
      notifier().reorder(0, 1);
      picker.queue.add(picked('late'));
      await notifier().add();

      expect(state().entries, const [PhotoSetEntry.saved(11), PhotoSetEntry.saved(12), PhotoSetEntry.saved(13)]);
      expect(repository.uploads, isEmpty);
      pending.complete(collection([11, 12, 13], revision: 'rev-2'));
      await saving;
    });

    test('a pick that finishes after a save completed is dropped', () async {
      await loaded();
      notifier().reorder(0, 1);
      final pick = Completer<PickedPhoto?>();
      picker.queue.add(pick.future);
      final adding = notifier().add();
      repository.commitResult = collection([12, 11, 13], revision: 'rev-2');
      await notifier().save();

      pick.complete(picked('late'));
      await adding;

      expect(state().photos.whereType<StagedPhoto>(), isEmpty);
      expect(repository.uploads, isEmpty);
    });

    test('a replace whose pick finishes after a conflict reload is dropped', () async {
      await loaded();
      notifier().reorder(0, 1);
      final pick = Completer<PickedPhoto?>();
      picker.queue.add(pick.future);
      final replacing = notifier().replace(2);
      repository.stored = collection([21, 22, 23], revision: 'rev-other');
      repository.commitError = PhotoSetConflictException();
      await expectLater(notifier().save(), throwsA(isA<PhotoSetConflictException>()));

      pick.complete(picked('late'));
      await replacing;

      expect(state().photos.map((p) => (p as SavedPhoto).id), [21, 22, 23], reason: 'photo 23 is untouched');
    });

    test('a pick that finishes after Save started is dropped', () async {
      await loaded();
      notifier().reorder(0, 1);
      final pick = Completer<PickedPhoto?>();
      picker.queue.add(pick.future);
      final adding = notifier().add();
      final pending = Completer<MyPhotoCollection>();
      repository.heldCommit = pending;
      final saving = notifier().save();

      pick.complete(picked('late'));
      await adding;

      expect(state().photos.whereType<StagedPhoto>(), isEmpty);
      expect(repository.uploads, isEmpty);
      pending.complete(collection([12, 11, 13], revision: 'rev-2'));
      await saving;
    });
  });

  group('ordering', () {
    test('reorder and remove produce the right entries', () async {
      repository.stored = collection([11, 12, 13, 14]);
      await loaded();

      notifier().reorder(3, 0); // 14, 11, 12, 13
      notifier().remove(2); // 14, 11, 13

      expect(state().entries, const [PhotoSetEntry.saved(14), PhotoSetEntry.saved(11), PhotoSetEntry.saved(13)]);
    });

    test('replace puts a staged photo in place, and Save sends its key there', () async {
      await loaded();
      picker.queue.add(picked('new'));

      await notifier().replace(1);
      repository.uploads.single.complete('photos/u/new.jpg');
      await pumpEventQueue();

      expect(repository.uploadPositions, [2]);
      expect(state().entries, const [
        PhotoSetEntry.saved(11),
        PhotoSetEntry.staged('photos/u/new.jpg'),
        PhotoSetEntry.saved(13),
      ]);
    });

    test('a staged photo keeps its upload when moved, and is dropped when removed', () async {
      await loaded();
      picker.queue.addAll([picked('a'), picked('b')]);
      await notifier().add(); // 11 12 13 a
      await notifier().add(); // 11 12 13 a b

      notifier().reorder(4, 0); // b 11 12 13 a
      notifier().remove(4); // b 11 12 13
      repository.uploads[0].complete('photos/u/a.jpg'); // a was removed: ignored
      repository.uploads[1].complete('photos/u/b.jpg');
      await pumpEventQueue();

      expect(state().entries, const [
        PhotoSetEntry.staged('photos/u/b.jpg'),
        PhotoSetEntry.saved(11),
        PhotoSetEntry.saved(12),
        PhotoSetEntry.saved(13),
      ]);
    });

    test('upload progress shows on the tile', () async {
      await loaded();
      picker.queue.add(picked('a'));
      await notifier().add();

      repository.progressCallbacks.single!(0.5);

      expect(((state().photos.last as StagedPhoto).status as StageUploading).progress, 0.5);
    });
  });

  group('errors', () {
    test('a failed upload can be retried', () async {
      await loaded();
      picker.queue.add(picked('a'));
      await notifier().add();

      repository.uploads.single.completeError(PhotoRepositoryException('Upload failed. Tap to try again.'));
      await pumpEventQueue();
      final failed = state().photos.last as StagedPhoto;
      expect(failed.status, isA<StageFailed>());
      expect(state().canSave, isFalse);

      notifier().retry(failed.localId);
      expect((state().photos.last as StagedPhoto).status, isA<StageUploading>());
      repository.uploads.last.complete('photos/u/a.jpg');
      await pumpEventQueue();

      expect(repository.uploads.length, 2);
      expect(state().canSave, isTrue);
    });

    test('a photo the rules refuse shows why and adds nothing', () async {
      await loaded();
      picker.queue.add(const PhotoPickException('This photo format isn\'t supported.'));

      await notifier().add();

      expect(state().photos.length, 3);
      expect(state().error, 'This photo format isn\'t supported.');
    });

    test('a 409 reloads and sets the error', () async {
      await loaded();
      notifier().reorder(0, 1);
      repository.stored = collection([21, 22, 23], revision: 'rev-other-device');
      repository.commitError = PhotoSetConflictException();

      await expectLater(notifier().save(), throwsA(isA<PhotoSetConflictException>()));

      expect(repository.loads, 2);
      expect(state().photos.map((p) => (p as SavedPhoto).id), [21, 22, 23]);
      expect(state().revision, 'rev-other-device');
      expect(state().error, 'Your photos were changed on another device. Please check and try again.');
      expect(state().isSaving, isFalse);
    });

    test('a 409 whose reload also fails leaves Save usable and says why', () async {
      await loaded();
      notifier().reorder(0, 1);
      repository.commitError = PhotoSetConflictException();
      repository.loadError = PhotoRepositoryException('We couldn\'t load your photos. Please try again.');

      await expectLater(notifier().save(), throwsA(isA<PhotoSetConflictException>()));

      expect(state().isSaving, isFalse);
      expect(state().isLoading, isFalse);
      expect(state().error, 'Your photos were changed on another device. Please check and try again.');
    });

    test('a 400 keeps the edits and shows the server\'s message', () async {
      await loaded();
      notifier().reorder(0, 1);
      repository.commitError = PhotoRepositoryException('Upload photos/u/x.jpg wasn\'t found.');

      await expectLater(notifier().save(), throwsA(isA<PhotoRepositoryException>()));

      expect(state().error, 'Upload photos/u/x.jpg wasn\'t found.');
      expect(state().isDirty, isTrue);
      expect(state().isSaving, isFalse);
    });
  });

  group('success', () {
    test('Save sends the revision and entries, replaces the state and invalidates both providers', () async {
      // Keep both profile providers alive, as the open Profile tab and hub would.
      container.listen(userProfileProvider, (_, _) {});
      container.listen(myProfileProvider, (_, _) {});
      await loaded();
      expect((userProfileBuilds, myProfileBuilds), (1, 1));

      notifier().reorder(2, 0); // 13 11 12
      repository.commitResult = collection([13, 11, 12], revision: 'rev-2', verificationReset: true);

      final saved = await notifier().save();
      await pumpEventQueue();

      expect(repository.commits.single.$1, 'rev-1');
      expect(repository.commits.single.$2,
          const [PhotoSetEntry.saved(13), PhotoSetEntry.saved(11), PhotoSetEntry.saved(12)]);
      expect(saved.verificationReset, isTrue);
      expect(state().revision, 'rev-2');
      expect(state().isDirty, isFalse);
      expect(state().isSaving, isFalse);
      expect((userProfileBuilds, myProfileBuilds), (2, 2));
    });
  });
}
