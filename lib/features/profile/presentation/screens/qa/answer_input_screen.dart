import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/constants/user_text_limits.dart';
import 'package:eros_app/features/profile/domain/models/question_dto.dart';
import 'package:eros_app/features/profile/domain/models/qa_draft.dart';
import 'package:eros_app/features/profile/presentation/providers/qa_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/qa_answer_rules.dart';

/// Answer input screen
/// Matches screenshot: @screenshots/users/create-profile/CCD90428-DCE2-455B-A3A7-2EC6DC21F1C8.png
/// User types their answer with character count and validation
class AnswerInputScreen extends ConsumerStatefulWidget {
  final QuestionDTO question;

  const AnswerInputScreen({
    super.key,
    required this.question,
  });

  @override
  ConsumerState<AnswerInputScreen> createState() => _AnswerInputScreenState();
}

class _AnswerInputScreenState extends ConsumerState<AnswerInputScreen> {
  late TextEditingController _answerController;
  String? _errorMessage;

  static const int maxLength = UserTextLimits.qaAnswer;
  static const int minLength = qaAnswerMinLength;

  @override
  void initState() {
    super.initState();
    _answerController = TextEditingController();
    _answerController.addListener(_onAnswerChanged);
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _onAnswerChanged() {
    setState(() {
      _validateAnswer();
    });
  }

  /// The answer as it will be saved (see [qaAnswerError]).
  String get _answer => cleanQAAnswer(_answerController.text);

  void _validateAnswer() {
    _errorMessage = _answerController.text.isEmpty ? null : qaAnswerError(_answerController.text);
  }

  bool get _canSave => qaAnswerError(_answerController.text) == null;

  @override
  Widget build(BuildContext context) {
    final characterCount = _answerController.text.length;
    final showError = _errorMessage != null && _answerController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question text
                    Text(
                      widget.question.question,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 24),

                    // Answer input field
                    TextField(
                      controller: _answerController,
                      maxLines: 5,
                      maxLength: maxLength,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Type your answer here...',
                        // The theme draws the box. A too-short answer turns its focused edge red.
                        focusedBorder: showError
                            ? Theme.of(context).inputDecorationTheme.focusedErrorBorder
                            : null,
                        counterText: '',
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),

                    // Character count and error message
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (showError)
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.error,
                                    ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          Text(
                            '$characterCount/$maxLength',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: characterCount > maxLength
                                      ? AppColors.error
                                      : AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Helper text
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your answer should be at least $minLength characters',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Save button
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: AppButton(label: 'Save answer', onPressed: _canSave ? _saveAnswer : null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveAnswer() {
    if (!_canSave) {
      return;
    }

    final answer = _answer;

    // Create Q&A draft
    final qaDraft = QADraft(
      question: widget.question,
      answer: answer,
      displayOrder: 1, // Will be updated by the notifier
    );

    try {
      // Add to state
      ref.read(qaDraftsProvider.notifier).addQA(qaDraft);

      // Pop back to main Q&A screen (pop twice: this screen and question selector)
      Navigator.pop(context);
      Navigator.pop(context);

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Answer saved!'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
