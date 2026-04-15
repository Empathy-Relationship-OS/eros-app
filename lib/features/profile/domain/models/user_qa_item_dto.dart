import 'package:eros_app/features/profile/domain/models/question_dto.dart';

/// DTO for a single Q&A item
/// Used in UserQACollectionDTO
class UserQAItemDTO {
  final String userId;
  final QuestionDTO question;
  final String answer;
  final int displayOrder; // 1-3

  const UserQAItemDTO({
    required this.userId,
    required this.question,
    required this.answer,
    required this.displayOrder,
  });

  factory UserQAItemDTO.fromJson(Map<String, dynamic> json) {
    return UserQAItemDTO(
      userId: json['userId'] as String,
      question: QuestionDTO.fromJson(json['question'] as Map<String, dynamic>),
      answer: json['answer'] as String,
      displayOrder: json['displayOrder'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'question': question.toJson(),
      'answer': answer,
      'displayOrder': displayOrder,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserQAItemDTO &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          question == other.question &&
          answer == other.answer &&
          displayOrder == other.displayOrder;

  @override
  int get hashCode =>
      userId.hashCode ^
      question.hashCode ^
      answer.hashCode ^
      displayOrder.hashCode;

  @override
  String toString() =>
      'UserQAItemDTO(userId: $userId, question: ${question.question}, answer: $answer, displayOrder: $displayOrder)';
}
