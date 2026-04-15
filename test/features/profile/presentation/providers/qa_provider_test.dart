import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/profile/domain/models/qa_draft.dart';
import 'package:eros_app/features/profile/domain/models/question_dto.dart';
import 'package:eros_app/features/profile/presentation/providers/qa_provider.dart';

void main() {
  group('QADraftsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    const question1 = QuestionDTO(
      questionId: 1,
      question: 'What is your favorite hobby?',
    );

    const question2 = QuestionDTO(
      questionId: 2,
      question: 'What makes you happy?',
    );

    const question3 = QuestionDTO(
      questionId: 3,
      question: 'What are your goals?',
    );

    const question4 = QuestionDTO(
      questionId: 4,
      question: 'What do you value most?',
    );

    test('should start with empty list', () {
      final drafts = container.read(qaDraftsProvider);
      expect(drafts, isEmpty);
    });

    test('should add Q&A draft', () {
      final notifier = container.read(qaDraftsProvider.notifier);
      const draft = QADraft(
        question: question1,
        answer: 'Playing guitar',
        displayOrder: 1,
      );

      notifier.addQA(draft);

      final drafts = container.read(qaDraftsProvider);
      expect(drafts.length, 1);
      expect(drafts[0].question, question1);
      expect(drafts[0].answer, 'Playing guitar');
      expect(drafts[0].displayOrder, 1);
    });

    test('should update display order when adding Q&As', () {
      final notifier = container.read(qaDraftsProvider.notifier);

      notifier.addQA(const QADraft(
        question: question1,
        answer: 'Answer 1',
        displayOrder: 5, // Should be overridden
      ));

      notifier.addQA(const QADraft(
        question: question2,
        answer: 'Answer 2',
        displayOrder: 10, // Should be overridden
      ));

      final drafts = container.read(qaDraftsProvider);
      expect(drafts[0].displayOrder, 1);
      expect(drafts[1].displayOrder, 2);
    });

    test('should throw error when adding duplicate question', () {
      final notifier = container.read(qaDraftsProvider.notifier);
      const draft1 = QADraft(
        question: question1,
        answer: 'First answer',
        displayOrder: 1,
      );
      const draft2 = QADraft(
        question: question1,
        answer: 'Second answer',
        displayOrder: 2,
      );

      notifier.addQA(draft1);

      expect(
        () => notifier.addQA(draft2),
        throwsA(isA<StateError>()),
      );
    });

    test('should throw error when adding more than 3 Q&As', () {
      final notifier = container.read(qaDraftsProvider.notifier);

      notifier.addQA(const QADraft(
        question: question1,
        answer: 'Answer 1',
        displayOrder: 1,
      ));
      notifier.addQA(const QADraft(
        question: question2,
        answer: 'Answer 2',
        displayOrder: 2,
      ));
      notifier.addQA(const QADraft(
        question: question3,
        answer: 'Answer 3',
        displayOrder: 3,
      ));

      expect(
        () => notifier.addQA(const QADraft(
          question: question4,
          answer: 'Answer 4',
          displayOrder: 4,
        )),
        throwsA(isA<StateError>()),
      );
    });

    test('should update Q&A draft', () {
      final notifier = container.read(qaDraftsProvider.notifier);
      const draft = QADraft(
        question: question1,
        answer: 'Original answer',
        displayOrder: 1,
      );

      notifier.addQA(draft);

      final updated = draft.copyWith(answer: 'Updated answer');
      notifier.updateQA(0, updated);

      final drafts = container.read(qaDraftsProvider);
      expect(drafts[0].answer, 'Updated answer');
    });

    test('should throw error when updating invalid index', () {
      final notifier = container.read(qaDraftsProvider.notifier);

      expect(
        () => notifier.updateQA(0, const QADraft(
          question: question1,
          answer: 'Test',
          displayOrder: 1,
        )),
        throwsA(isA<RangeError>()),
      );
    });

    test('should remove Q&A draft and reorder remaining', () {
      final notifier = container.read(qaDraftsProvider.notifier);

      notifier.addQA(const QADraft(
        question: question1,
        answer: 'Answer 1',
        displayOrder: 1,
      ));
      notifier.addQA(const QADraft(
        question: question2,
        answer: 'Answer 2',
        displayOrder: 2,
      ));
      notifier.addQA(const QADraft(
        question: question3,
        answer: 'Answer 3',
        displayOrder: 3,
      ));

      notifier.removeQA(0);

      final drafts = container.read(qaDraftsProvider);
      expect(drafts.length, 2);
      expect(drafts[0].question, question2);
      expect(drafts[0].displayOrder, 1);
      expect(drafts[1].question, question3);
      expect(drafts[1].displayOrder, 2);
    });

    test('should clear all Q&A drafts', () {
      final notifier = container.read(qaDraftsProvider.notifier);

      notifier.addQA(const QADraft(
        question: question1,
        answer: 'Answer 1',
        displayOrder: 1,
      ));
      notifier.addQA(const QADraft(
        question: question2,
        answer: 'Answer 2',
        displayOrder: 2,
      ));

      notifier.clear();

      final drafts = container.read(qaDraftsProvider);
      expect(drafts, isEmpty);
    });

    test('hasMinimumQAs should be true when at least one Q&A exists', () {
      final notifier = container.read(qaDraftsProvider.notifier);

      expect(notifier.hasMinimumQAs, false);

      notifier.addQA(const QADraft(
        question: question1,
        answer: 'Answer 1',
        displayOrder: 1,
      ));

      expect(notifier.hasMinimumQAs, true);
    });

    test('canAddMore should be false when 3 Q&As exist', () {
      final notifier = container.read(qaDraftsProvider.notifier);

      expect(notifier.canAddMore, true);

      notifier.addQA(const QADraft(
        question: question1,
        answer: 'Answer 1',
        displayOrder: 1,
      ));
      notifier.addQA(const QADraft(
        question: question2,
        answer: 'Answer 2',
        displayOrder: 2,
      ));
      notifier.addQA(const QADraft(
        question: question3,
        answer: 'Answer 3',
        displayOrder: 3,
      ));

      expect(notifier.canAddMore, false);
    });

    test('allValid should check all Q&As are valid', () {
      final notifier = container.read(qaDraftsProvider.notifier);

      notifier.addQA(const QADraft(
        question: question1,
        answer: 'Valid answer that is long enough',
        displayOrder: 1,
      ));

      expect(notifier.allValid, true);

      // Add an invalid Q&A (answer too short)
      notifier.addQA(const QADraft(
        question: question2,
        answer: 'x', // Too short
        displayOrder: 2,
      ));

      expect(notifier.allValid, false);
    });
  });
}
