import 'package:flutter/material.dart';
import 'package:eros_app/features/profile/domain/models/question_dto.dart';

/// A list of Q&A questions to choose from, one card each. Shared by onboarding's
/// `QuestionSelectorScreen` and the profile editor's "Add an answer" sheet.
///
/// Controlled: it shows [questions] and calls [onSelected]; the caller decides which questions
/// are offered (usually the ones not yet answered).
class QuestionPickerList extends StatelessWidget {
  final List<QuestionDTO> questions;
  final ValueChanged<QuestionDTO> onSelected;
  final bool shrinkWrap;

  const QuestionPickerList({
    super.key,
    required this.questions,
    required this.onSelected,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: shrinkWrap,
      itemCount: questions.length,
      itemBuilder: (context, index) => QuestionPickerItem(
        question: questions[index],
        onTap: () => onSelected(questions[index]),
      ),
    );
  }
}

/// One question card of a [QuestionPickerList].
class QuestionPickerItem extends StatelessWidget {
  final QuestionDTO question;
  final VoidCallback onTap;

  const QuestionPickerItem({super.key, required this.question, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                question.question,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
