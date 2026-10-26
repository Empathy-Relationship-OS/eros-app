import 'dart:io';

import 'package:eros_app/features/profile/data/repositories/photo_repository.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/photos/profile_completion_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../providers/photo_upload_submit_test.dart' show FakeRepository;

/// Lets real file I/O and the fake uploads' timers both run.
Future<void> _settleWork(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  testWidgets('a failed upload shows why; Try again uploads the rest and moves on', (tester) async {
    final dir = Directory.systemTemp.createTempSync('completion_screen_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final repository = FakeRepository()..failing.add('p2.jpg');
    final container = ProviderContainer(overrides: [photoRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    for (var i = 1; i <= 3; i++) {
      final file = File('${dir.path}/p$i.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, ...List.filled(120 * 1024, 0)]);
      container.read(photoUploadProvider.notifier).addPhoto(localPath: file.path);
    }
    final pushed = <String?>[];

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: const ProfileCompletionLoadingScreen(),
        onGenerateRoute: (settings) {
          pushed.add(settings.name);
          return MaterialPageRoute(builder: (_) => const Scaffold());
        },
      ),
    ));
    await _settleWork(tester);

    expect(find.text('One photo didn\'t upload. Please try again.'), findsOneWidget);
    expect(repository.commits, isEmpty);

    repository.failing.clear();
    repository.staged.clear();
    await tester.tap(find.text('Try again'));
    await _settleWork(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));

    expect(repository.staged, ['p2.jpg']);
    expect(repository.commits.single.$2.map((e) => e.objectKey), ['photos/u/p1.jpg', 'photos/u/p2.jpg', 'photos/u/p3.jpg']);
    expect(pushed, ['/profile/welcome']);
  });
}
