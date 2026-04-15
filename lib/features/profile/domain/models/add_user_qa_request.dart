import 'package:eros_app/features/profile/domain/models/question_dto.dart';

/// Request DTO for adding a Q&A
/// Used with POST /users/qa
class AddUserQARequest {
  final String userId;
  final QuestionDTO question;
  final String answer;
  final int displayOrder; // 1-3

  const AddUserQARequest({
    required this.userId,
    required this.question,
    required this.answer,
    required this.displayOrder,
  });

  /// Validation before sending to backend
  void validate() {
    if (displayOrder < 1 || displayOrder > 3) {
      throw ArgumentError('Display order must be between 1 and 3');
    }
    if (answer.trim().isEmpty) {
      throw ArgumentError('Answer is required');
    }
    if (answer.length > 200) {
      throw ArgumentError('Answer must not exceed 200 characters');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'question': question.toJson(),
      'answer': answer,
      'displayOrder': displayOrder,
    };
  }

  factory AddUserQARequest.fromJson(Map<String, dynamic> json) {
    return AddUserQARequest(
      userId: json['userId'] as String,
      question: QuestionDTO.fromJson(json['question'] as Map<String, dynamic>),
      answer: json['answer'] as String,
      displayOrder: json['displayOrder'] as int,
    );
  }

  @override
  String toString() =>
      'AddUserQARequest(userId: $userId, question: ${question.questionId}, answer: $answer, displayOrder: $displayOrder)';
}
