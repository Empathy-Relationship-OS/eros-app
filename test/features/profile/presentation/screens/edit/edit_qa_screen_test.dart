import 'package:eros_app/features/profile/data/repositories/qa_repository.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_qa_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../providers/qa_edit_provider_test.dart' show FakeQARepository, q1, q2, q3, qaCollection;

Future<FakeQARepository> _pump(WidgetTester tester, {FakeQARepository? repository, Size size = const Size(800, 2400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = repository ?? FakeQARepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [qaRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditQAScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

TextButton _saveButton(WidgetTester tester) => tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save'));

Finder _field(int index) => find.byType(TextFormField).at(index);

void main() {
  testWidgets('shows the saved answers in their fields, with Save off', (tester) async {
    await _pump(tester);

    expect(find.text('What makes you laugh?'), findsOneWidget);
    expect(find.text('Puns'), findsOneWidget);
    expect(find.text('Long walks'), findsOneWidget);
    expect(find.text('2/3 answers (at least 1)'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('editing an answer and saving sends the whole set and closes', (tester) async {
    final repository = await _pump(tester);

    await tester.enterText(_field(0), "  Puns, and I'd select pizza from the menu ");
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.submissions.single.map((qa) => qa.answer),
        ["Puns, and I'd select pizza from the menu", 'Long walks']);
    expect(find.byType(EditQAScreen), findsNothing);
  });

  testWidgets('a too-short answer shows why and can\'t be saved', (tester) async {
    await _pump(tester);

    await tester.enterText(_field(0), 'x');
    await tester.pump();

    expect(find.text('This answer is not long enough'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('removing every answer keeps Save off and says at least 1 is needed', (tester) async {
    await _pump(tester);

    await tester.tap(find.byTooltip('Remove answer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove answer').first);
    await tester.pumpAndSettle();

    expect(find.text('Add at least 1 answer to save.'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('Add an answer offers only unanswered questions, and a removed question comes back empty',
      (tester) async {
    final repository = await _pump(tester);

    await tester.tap(find.text('Add an answer'));
    await tester.pumpAndSettle();
    expect(find.text('Best trip so far?'), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('What makes you laugh?')), findsNothing);
    await tester.tap(find.text('Best trip so far?'));
    await tester.pumpAndSettle();
    expect(find.text('3/3 answers (at least 1)'), findsOneWidget);
    expect(find.text('Add an answer'), findsNothing);

    await tester.enterText(_field(2), 'Lisbon');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.submissions.single.map((qa) => qa.question), [q1, q2, q3]);
  });

  testWidgets('a removed then re-added question starts with an empty answer', (tester) async {
    await _pump(tester, repository: FakeQARepository()..stored = qaCollection([(q1, 'Puns'), (q2, 'Long walks')]));

    await tester.tap(find.byTooltip('Remove answer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add an answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfect Sunday?'));
    await tester.pumpAndSettle();

    expect(find.text('Long walks'), findsNothing);
  });

  testWidgets('a refused save shows the server\'s message and stays open', (tester) async {
    final repository = await _pump(tester);
    repository.submitError = QARepositoryException('Duplicate questions are not allowed.');

    await tester.enterText(_field(0), 'Puns, mostly');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Duplicate questions are not allowed.'), findsOneWidget);
    expect(find.byType(EditQAScreen), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('dragging the first answer below the second reorders them', (tester) async {
    final repository = await _pump(tester);

    final handle = find.byIcon(Icons.drag_handle).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.submissions.single.map((qa) => qa.question), [q2, q1]);
  });

  testWidgets('lays out at phone size with 3 answers and the question sheet open', (tester) async {
    final repository = FakeQARepository()..stored = qaCollection([(q1, 'a' * 200), (q2, 'Long walks')]);
    await _pump(tester, repository: repository, size: const Size(375, 812));

    await tester.tap(find.text('Add an answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Best trip so far?'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('3/3 answers (at least 1)'), findsOneWidget);
  });

  testWidgets('a failed load shows why with a retry, and no editable list', (tester) async {
    final repository = FakeQARepository()
      ..loadError = QARepositoryException('Unable to connect to the server.')
      ..failFirstLoadOnly = true;
    await _pump(tester, repository: repository);

    expect(find.text('Unable to connect to the server.'), findsOneWidget);
    expect(find.text('Add an answer'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Puns'), findsOneWidget);
  });

  testWidgets('back with changes asks before discarding them', (tester) async {
    await _pump(tester);
    await tester.enterText(_field(0), 'Puns, mostly');
    await tester.pump();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
  });
}
