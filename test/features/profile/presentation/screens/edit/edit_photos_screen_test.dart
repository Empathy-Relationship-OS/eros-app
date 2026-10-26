import 'package:eros_app/features/profile/data/repositories/photo_repository.dart';
import 'package:eros_app/features/profile/domain/models/photo_models.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_edit_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_photos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../providers/photo_edit_provider_test.dart' show FakePhotoPicker, FakePhotoRepository, collection, photo, picked;

Future<FakePhotoRepository> _pump(WidgetTester tester, {MyPhotoCollection? stored, FakePhotoPicker? picker}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = FakePhotoRepository();
  if (stored != null) repository.stored = stored;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      photoRepositoryProvider.overrideWithValue(repository),
      photoPickerProvider.overrideWithValue(picker ?? FakePhotoPicker()),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditPhotosScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repository;
}

/// The slot showing saved photo [id].
Finder _slot(int id) => find.byKey(ValueKey('saved-$id')).first; // the grid wraps each tile with the same key

Future<void> _chooseOn(WidgetTester tester, int id, String action) async {
  await tester.tap(_slot(id));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

TextButton _saveButton(WidgetTester tester) => tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save'));

final _verified = MyPhotoCollection(
  photos: [photo(11, 1), photo(12, 2, verification: true), photo(13, 3), photo(14, 4)],
  revision: 'rev-1',
);

void main() {
  testWidgets('shows the saved photos, the main photo badge and the Verified tag', (tester) async {
    await _pump(tester, stored: _verified);

    expect(find.text('4/6 photos (at least 3)'), findsOneWidget);
    expect(find.text('Main photo'), findsOneWidget);
    expect(find.descendant(of: _slot(12), matching: find.byKey(const Key('verified-tag'))), findsOneWidget);
    expect(find.byKey(const Key('verified-tag')), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);
  });

  group('verification photo warning', () {
    testWidgets('appears before removing the verification photo, and Keep photo keeps it', (tester) async {
      await _pump(tester, stored: _verified);

      await _chooseOn(tester, 12, 'Remove');

      expect(find.text(verificationPhotoWarning), findsOneWidget);
      await tester.tap(find.text('Keep photo'));
      await tester.pumpAndSettle();
      expect(_slot(12), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNull);
    });

    testWidgets('confirming removes the verification photo', (tester) async {
      await _pump(tester, stored: _verified);

      await _chooseOn(tester, 12, 'Remove');
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('saved-12')), findsNothing);
      expect(_saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('also appears before replacing it', (tester) async {
      await _pump(tester, stored: _verified);

      await _chooseOn(tester, 12, 'Replace');

      expect(find.text(verificationPhotoWarning), findsOneWidget);
    });

    testWidgets('does not appear for any other photo', (tester) async {
      await _pump(tester, stored: _verified);

      await _chooseOn(tester, 13, 'Remove');

      expect(find.text(verificationPhotoWarning), findsNothing);
      expect(find.byKey(const ValueKey('saved-13')), findsNothing);
    });
  });

  group('leaving', () {
    testWidgets('back with changes asks before discarding them', (tester) async {
      await _pump(tester, stored: collection([11, 12, 13, 14]));
      await _chooseOn(tester, 14, 'Remove');

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(EditPhotosScreen), findsNothing);
    });

    testWidgets('back without changes just goes back', (tester) async {
      await _pump(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(EditPhotosScreen), findsNothing);
    });
  });

  testWidgets('an added photo shows its upload, and a failed one can be retried', (tester) async {
    final picker = FakePhotoPicker()..queue.add(picked('new'));
    final repository = await _pump(tester, picker: picker);

    await tester.tap(find.text('Add\nPhoto').first);
    await tester.pump();
    expect(find.byKey(const Key('upload-progress')), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    repository.uploads.single.completeError(PhotoRepositoryException('Upload failed. Tap to try again.'));
    await tester.pump();
    expect(find.byKey(const Key('upload-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('upload-retry')));
    await tester.pump();
    repository.uploads.last.complete('photos/u/new.jpg');
    await tester.pump();

    expect(find.byKey(const Key('upload-retry')), findsNothing);
    expect(find.byKey(const Key('upload-progress')), findsNothing);
    expect(_saveButton(tester).onPressed, isNotNull);
  });

  group('a failed upload', () {
    Future<FakePhotoRepository> withFailedUpload(WidgetTester tester) async {
      final picker = FakePhotoPicker()..queue.add(picked('new'));
      final repository = await _pump(tester, picker: picker);
      await tester.tap(find.text('Add\nPhoto').first);
      await tester.pump();
      repository.uploads.single.completeError(PhotoRepositoryException('Upload failed. Tap to try again.'));
      await tester.pump();
      return repository;
    }

    testWidgets('says why Save is off', (tester) async {
      await withFailedUpload(tester);

      expect(find.text('Upload failed'), findsOneWidget);
      expect(find.byKey(const Key('upload-failed-hint')), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNull);
    });

    testWidgets('can be dragged by a long press on its retry button', (tester) async {
      await withFailedUpload(tester);
      final from = tester.getCenter(find.byKey(const Key('upload-retry')));
      final to = tester.getCenter(_slot(11));

      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 800));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy((to - from) / 20);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final state = ProviderScope.containerOf(tester.element(find.byType(EditPhotosScreen))).read(photoEditProvider);
      expect(state.photos.first, isA<StagedPhoto>(), reason: 'the failed photo moved to position 1');
    });
  });

  group('saving', () {
    testWidgets('a save that reset verification closes the editor and says so', (tester) async {
      final repository = await _pump(tester, stored: _verified);
      repository.commitResult = collection([11, 13, 14], revision: 'rev-2', verificationReset: true);
      await _chooseOn(tester, 12, 'Remove');
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.commits.single.$2,
          const [PhotoSetEntry.saved(11), PhotoSetEntry.saved(13), PhotoSetEntry.saved(14)]);
      expect(find.byType(EditPhotosScreen), findsNothing);
      expect(find.text(verificationResetNotice), findsOneWidget);
    });

    testWidgets('a conflict reloads, says why once, and stays open', (tester) async {
      final repository = await _pump(tester, stored: collection([11, 12, 13, 14]));
      await _chooseOn(tester, 14, 'Remove');
      repository.stored = collection([21, 22, 23], revision: 'rev-other');
      repository.commitError = PhotoSetConflictException();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(EditPhotosScreen), findsOneWidget);
      expect(find.text('Your photos were changed on another device. Please check and try again.'), findsOneWidget);
      expect(_slot(21), findsOneWidget);
      expect(find.byKey(const Key('edit-error-banner')), findsNothing);
    });

    testWidgets('fewer than 3 photos says so and can\'t be saved', (tester) async {
      await _pump(tester);

      await _chooseOn(tester, 13, 'Remove');

      expect(find.text('Add at least 3 photos to save.'), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNull);
    });
  });
}
