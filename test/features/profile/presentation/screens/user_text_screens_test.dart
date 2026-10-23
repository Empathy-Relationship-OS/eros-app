import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/cancel_provider.dart';
import 'package:eros_app/features/dates/presentation/widgets/cancel_date_dialog.dart';
import 'package:eros_app/features/profile/domain/models/question_dto.dart';
import 'package:eros_app/features/profile/presentation/providers/qa_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/name_input_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/qa/answer_input_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_harness.dart';

/// Free text is cleaned, never stripped, wherever it is saved (RFC-004 D-16, PE-F9). The bio,
/// occupation and editor screens are covered next to their other tests.
void main() {
  group('NameInputScreen', () {
    testWidgets('saves names in any script, with apostrophes, as typed', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const NameInputScreen());

      await tester.enterText(find.byType(TextFormField).at(0), ' José ');
      await tester.enterText(find.byType(TextFormField).at(1), "O'Brien\u202e");
      await tester.pump();
      await harness.tapContinue(tester);

      expect(harness.draft.firstName, 'José');
      expect(harness.draft.lastName, "O'Brien");
      expect(harness.pushed, ['/profile-creation/location']);
    });

    testWidgets('accepts 李雷 and Zoë', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const NameInputScreen());

      await tester.enterText(find.byType(TextFormField).at(0), '李雷');
      await tester.enterText(find.byType(TextFormField).at(1), 'Zoë');
      await tester.pump();
      await harness.tapContinue(tester);

      expect(harness.draft.firstName, '李雷');
      expect(harness.draft.lastName, 'Zoë');
    });
  });

  group('AnswerInputScreen', () {
    const question = QuestionDTO(questionId: 1, question: 'What would you order?');

    /// Opens the answer screen on top of two routes, as the Q&A flow does (it pops twice).
    Future<ProviderContainer> pumpAnswer(WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Builder(builder: (context) {
          return TextButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold()));
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AnswerInputScreen(question: question)));
            },
            child: const Text('open'),
          );
        })),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return container;
    }

    ElevatedButton saveButton(WidgetTester tester) =>
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save answer'));

    testWidgets('accepts an answer that only looks like SQL', (tester) async {
      final container = await pumpAnswer(tester);

      await tester.enterText(find.byType(TextField), "  I'd select pizza from the menu  ");
      await tester.pump();
      await tester.tap(find.text('Save answer'));
      await tester.pumpAndSettle();

      expect(container.read(qaDraftsProvider).single.answer, "I'd select pizza from the menu");
    });

    testWidgets('keeps line breaks, at most one blank line', (tester) async {
      final container = await pumpAnswer(tester);

      await tester.enterText(find.byType(TextField), 'Pizza.\n\n\n\nThen gelato.');
      await tester.pump();
      await tester.tap(find.text('Save answer'));
      await tester.pumpAndSettle();

      expect(container.read(qaDraftsProvider).single.answer, 'Pizza.\n\nThen gelato.');
    });

    testWidgets("can't save an answer of only spaces", (tester) async {
      await pumpAnswer(tester);

      await tester.enterText(find.byType(TextField), '     ');
      await tester.pump();

      expect(saveButton(tester).onPressed, isNull);
    });
  });

  group('CancelDateDialog', () {
    testWidgets('sends the note cleaned', (tester) async {
      final notifier = _RecordingCancelNotifier();
      await tester.pumpWidget(ProviderScope(
        overrides: [cancelProvider('7').overrideWith((ref) => notifier)],
        child: MaterialApp(
          home: Scaffold(
            body: CancelDateDialog(dateId: '7', dateDetail: _date, partnerName: 'Sam', currentUid: 'user1'),
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), '  Running\nlate \u202e ');
      await tester.tap(find.text('Cancel date'));
      await tester.pumpAndSettle();

      expect(notifier.reasons, ['Running late']);
    });

    testWidgets('sends no note when it is only spaces', (tester) async {
      final notifier = _RecordingCancelNotifier();
      await tester.pumpWidget(ProviderScope(
        overrides: [cancelProvider('7').overrideWith((ref) => notifier)],
        child: MaterialApp(
          home: Scaffold(
            body: CancelDateDialog(dateId: '7', dateDetail: _date, partnerName: 'Sam', currentUid: 'user1'),
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Cancel date'));
      await tester.pumpAndSettle();

      expect(notifier.reasons, [null]);
    });
  });
}

/// Records each reason, then fails, so the dialog takes the path that only shows a message.
class _RecordingCancelNotifier extends StateNotifier<CancelState> implements CancelNotifier {
  _RecordingCancelNotifier() : super(const CancelState());

  final reasons = <String?>[];

  @override
  Future<void> cancelDate({String? reason}) async {
    reasons.add(reason);
    state = const CancelState(errorMessage: 'stopped by the test');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _date = DateDetail(
  dateId: 7,
  matchId: 1007,
  user1Id: 'user1',
  user2Id: 'user2',
  partnerName: 'Sam',
  activityId: 1,
  activityName: 'Coffee',
  tokenCost: '5.00',
  cityId: 1,
  cityName: 'London',
  state: DateState.awaitingAvailability,
  availabilityRound: 1,
  depositStatus: const DepositStatus(user1: ParticipantDepositStatus.pending, user2: ParticipantDepositStatus.pending),
  cancellable: true,
  timeline: const [],
  createdAt: DateTime.utc(2026, 10, 23),
  updatedAt: DateTime.utc(2026, 10, 23),
);
