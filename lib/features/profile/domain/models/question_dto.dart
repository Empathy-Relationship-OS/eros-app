/// DTO for questions fetched from the backend
/// Corresponds to GET /questions response
class QuestionDTO {
  final int questionId;
  final String question;

  const QuestionDTO({
    required this.questionId,
    required this.question,
  });

  factory QuestionDTO.fromJson(Map<String, dynamic> json) {
    return QuestionDTO(
      questionId: json['questionId'] as int,
      question: json['question'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'question': question,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionDTO &&
          runtimeType == other.runtimeType &&
          questionId == other.questionId &&
          question == other.question;

  @override
  int get hashCode => questionId.hashCode ^ question.hashCode;

  @override
  String toString() => 'QuestionDTO(questionId: $questionId, question: $question)';
}
