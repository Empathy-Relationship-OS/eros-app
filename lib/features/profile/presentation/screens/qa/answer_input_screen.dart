import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/utils/validators.dart';
import 'package:eros_app/features/profile/domain/models/question_dto.dart';
import 'package:eros_app/features/profile/domain/models/qa_draft.dart';
import 'package:eros_app/features/profile/presentation/providers/qa_provider.dart';

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

  static const int maxLength = 200;
  static const int minLength = 2;

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

  void _validateAnswer() {
    final answer = _answerController.text;

    if (answer.isEmpty) {
      _errorMessage = null;
      return;
    }

    // Validate against SQL injection and XSS
    if (!Validators.isSafeText(answer)) {
      _errorMessage = 'Invalid characters detected';
      return;
    }

    if (answer.trim().length < minLength) {
      _errorMessage = 'This answer is not long enough';
      return;
    }

    if (answer.length > maxLength) {
      _errorMessage = 'Answer exceeds maximum length';
      return;
    }

    _errorMessage = null;
  }

  bool get _canSave {
    final answer = _answerController.text;
    return answer.trim().length >= minLength &&
        answer.length <= maxLength &&
        _errorMessage == null &&
        Validators.isSafeText(answer);
  }

  @override
  Widget build(BuildContext context) {
    final characterCount = _answerController.text.length;
    final showError = _errorMessage != null && _answerController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 1.3,
                          ),
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
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: showError ? Colors.red : AppColors.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        counterText: '',
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
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
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          Text(
                            '$characterCount/$maxLength',
                            style: TextStyle(
                              color: characterCount > maxLength
                                  ? Colors.red
                                  : Colors.grey[600],
                              fontSize: 14,
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
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your answer should be at least $minLength characters',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 13,
                              ),
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
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _canSave ? _saveAnswer : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Save answer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
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

    final answer = _answerController.text.trim();

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
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
