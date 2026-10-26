import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/constants/user_text_limits.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/domain/models/question_dto.dart';
import 'package:eros_app/features/profile/presentation/providers/qa_edit_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/qa_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/qa_answer_rules.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/question_picker_list.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/text_field_editor.dart';

/// The Q&A section of Edit profile (eros-app #27): the user's answers, edited in place.
///
/// Each answer can be rewritten, removed or dragged into a new order, and **Add an answer** picks
/// a question not yet answered. Nothing is saved until **Save**, which replaces the whole set
/// ([QAEditNotifier.save]). At least one answer is kept, as in onboarding.
class EditQAScreen extends ConsumerStatefulWidget {
  const EditQAScreen({super.key});

  @override
  ConsumerState<EditQAScreen> createState() => _EditQAScreenState();
}

class _EditQAScreenState extends ConsumerState<EditQAScreen> {
  /// One controller per question, made from the answer the first time it is shown.
  final _controllers = <int, TextEditingController>{};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(EditableAnswer answer) => _controllers.putIfAbsent(
        answer.question.questionId,
        () => TextEditingController(text: answer.answer),
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(qaEditProvider);
    final notifier = ref.read(qaEditProvider.notifier);

    return EditSectionScaffold(
      title: 'Q&A',
      isDirty: state.isDirty,
      canSave: state.canSave,
      onSave: notifier.save,
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          // Never show an editable list that isn't the user's real set (see _LoadError).
          : state.error != null
          ? _LoadError(message: state.error!, onRetry: notifier.load)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const EditQuestion('Your answers'),
                    const SizedBox(height: 8),
                    Text(
                      '${state.answers.length}/$maxQAAnswers answers (at least $minQAAnswers)',
                      style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                    ),
                    if (state.answers.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Drag the handle to reorder.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      onReorder: (from, to) => notifier.reorder(from, to > from ? to - 1 : to),
                      children: [
                        for (var i = 0; i < state.answers.length; i++)
                          _AnswerCard(
                            key: ValueKey('qa-${state.answers[i].question.questionId}'),
                            index: i,
                            question: state.answers[i].question,
                            controller: _controllerFor(state.answers[i]),
                            onChanged: (text) => notifier.setAnswer(i, text),
                            // A save replaces the list, so nothing changes while it runs.
                            enabled: !state.isSaving,
                            onRemove: () => _remove(i, state.answers[i].question.questionId),
                          ),
                      ],
                    ),
                    if (state.answers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Add at least $minQAAnswers answer to save.',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    if (state.canAddMore)
                      OutlinedButton.icon(
                        onPressed: state.isSaving ? null : () => _pickQuestion(context, state.answeredQuestionIds),
                        icon: const Icon(Icons.add),
                        label: const Text('Add an answer'),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Removes answer [index] and forgets its field, so adding the question back starts empty.
  void _remove(int index, int questionId) {
    // The notifier ignores a remove during a save; the field must keep its controller then.
    if (ref.read(qaEditProvider).isSaving) return;
    ref.read(qaEditProvider.notifier).remove(index);
    final controller = _controllers.remove(questionId);
    // The field still uses it until the next frame has rebuilt without it.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller?.dispose());
  }

  Future<void> _pickQuestion(BuildContext context, Set<int> answered) async {
    final question = await showModalBottomSheet<QuestionDTO>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Consumer(
          builder: (context, ref, _) => ref.watch(questionsProvider).when(
                data: (questions) {
                  final available = questions.where((q) => !answered.contains(q.questionId)).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Text('Pick a question', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: available.isEmpty
                            ? const Center(child: Text('You\'ve answered every question.'))
                            : QuestionPickerList(
                                questions: available,
                                onSelected: (q) => Navigator.of(context).pop(q),
                              ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(questionsProvider),
                    child: const Text('Couldn\'t load questions. Tap to try again.'),
                  ),
                ),
              ),
        ),
      ),
    );
    if (question != null) ref.read(qaEditProvider.notifier).add(question);
  }
}

/// Shown instead of the list when the saved answers couldn't be read. Editing an empty list and
/// saving it would replace the user's answers, so nothing is editable until a retry succeeds.
class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700])),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// One answer: its question, a drag handle, a remove button and the answer field.
class _AnswerCard extends StatelessWidget {
  final int index;
  final QuestionDTO question;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;
  final bool enabled;

  const _AnswerCard({
    super.key,
    required this.index,
    required this.question,
    required this.controller,
    required this.onChanged,
    required this.onRemove,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  question.question,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove answer',
                onPressed: enabled ? onRemove : null,
              ),
              ReorderableDragStartListener(
                index: index,
                enabled: enabled,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle, semanticLabel: 'Drag to reorder'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextFieldEditor(
              controller: controller,
              maxLength: UserTextLimits.qaAnswer,
              maxLines: 4,
              hintText: 'Type your answer here...',
              validator: (text) => qaAnswerError(text ?? ''),
              onChanged: onChanged,
              enabled: enabled,
            ),
          ),
        ],
      ),
    );
  }
}
