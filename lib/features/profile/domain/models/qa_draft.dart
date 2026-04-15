import 'package:eros_app/features/profile/domain/models/question_dto.dart';

/// Local model for managing Q&A answers during profile creation
/// This is used in the UI before submitting to the backend
class QADraft {
  final QuestionDTO question;
  final String answer;
  final int displayOrder;

  const QADraft({
    required this.question,
    required this.answer,
    required this.displayOrder,
  });

  /// Check if this Q&A draft is valid
  bool get isValid {
    return answer.trim().isNotEmpty &&
        answer.length >= 2 &&
        answer.length <= 200 &&
        displayOrder >= 1 &&
        displayOrder <= 3;
  }

  /// Get character count for display
  int get characterCount => answer.length;

  /// Check if answer meets minimum length (2 characters or 1 word)
  bool get meetsMinimumLength {
    final trimmed = answer.trim();
    return trimmed.isNotEmpty && (trimmed.length >= 2 || trimmed.split(' ').isNotEmpty);
  }

  QADraft copyWith({
    QuestionDTO? question,
    String? answer,
    int? displayOrder,
  }) {
    return QADraft(
      question: question ?? this.question,
      answer: answer ?? this.answer,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question.toJson(),
      'answer': answer,
      'displayOrder': displayOrder,
    };
  }

  factory QADraft.fromJson(Map<String, dynamic> json) {
    return QADraft(
      question: QuestionDTO.fromJson(json['question'] as Map<String, dynamic>),
      answer: json['answer'] as String,
      displayOrder: json['displayOrder'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QADraft &&
          runtimeType == other.runtimeType &&
          question == other.question &&
          answer == other.answer &&
          displayOrder == other.displayOrder;

  @override
  int get hashCode =>
      question.hashCode ^ answer.hashCode ^ displayOrder.hashCode;

  @override
  String toString() =>
      'QADraft(question: ${question.question}, answer: $answer, displayOrder: $displayOrder)';
}
