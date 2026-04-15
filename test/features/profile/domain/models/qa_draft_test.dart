import 'package:flutter_test/flutter_test.dart';
import 'package:eros_app/features/profile/domain/models/qa_draft.dart';
import 'package:eros_app/features/profile/domain/models/question_dto.dart';

void main() {
  group('QADraft', () {
    const testQuestion = QuestionDTO(
      questionId: 1,
      question: 'What is your favorite hobby?',
    );

    test('should be valid with proper answer', () {
      const draft = QADraft(
        question: testQuestion,
        answer: 'I love playing guitar and composing music',
        displayOrder: 1,
      );

      expect(draft.isValid, true);
    });

    test('should be invalid with empty answer', () {
      const draft = QADraft(
        question: testQuestion,
        answer: '',
        displayOrder: 1,
      );

      expect(draft.isValid, false);
    });

    test('should be invalid with answer too short', () {
      const draft = QADraft(
        question: testQuestion,
        answer: 'a',
        displayOrder: 1,
      );

      expect(draft.isValid, false);
    });

    test('should be invalid with answer too long', () {
      final longAnswer = 'a' * 201;
      final draft = QADraft(
        question: testQuestion,
        answer: longAnswer,
        displayOrder: 1,
      );

      expect(draft.isValid, false);
    });

    test('should be invalid with invalid display order', () {
      const draft1 = QADraft(
        question: testQuestion,
        answer: 'Valid answer',
        displayOrder: 0,
      );

      const draft2 = QADraft(
        question: testQuestion,
        answer: 'Valid answer',
        displayOrder: 4,
      );

      expect(draft1.isValid, false);
      expect(draft2.isValid, false);
    });

    test('should return correct character count', () {
      const draft = QADraft(
        question: testQuestion,
        answer: 'Hello World',
        displayOrder: 1,
      );

      expect(draft.characterCount, 11);
    });

    test('should serialize to JSON correctly', () {
      const draft = QADraft(
        question: testQuestion,
        answer: 'Test answer',
        displayOrder: 1,
      );

      final json = draft.toJson();

      expect(json['question']['questionId'], 1);
      expect(json['question']['question'], 'What is your favorite hobby?');
      expect(json['answer'], 'Test answer');
      expect(json['displayOrder'], 1);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'question': {
          'questionId': 1,
          'question': 'What is your favorite hobby?',
        },
        'answer': 'Test answer',
        'displayOrder': 1,
      };

      final draft = QADraft.fromJson(json);

      expect(draft.question.questionId, 1);
      expect(draft.question.question, 'What is your favorite hobby?');
      expect(draft.answer, 'Test answer');
      expect(draft.displayOrder, 1);
    });

    test('copyWith should update only specified fields', () {
      const original = QADraft(
        question: testQuestion,
        answer: 'Original answer',
        displayOrder: 1,
      );

      final updated = original.copyWith(answer: 'Updated answer');

      expect(updated.question, testQuestion);
      expect(updated.answer, 'Updated answer');
      expect(updated.displayOrder, 1);
    });
  });
}
