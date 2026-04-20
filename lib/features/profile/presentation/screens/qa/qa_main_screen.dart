import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/presentation/providers/qa_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';
import 'package:eros_app/features/profile/presentation/screens/photos/all_photos_screen.dart';
import 'package:eros_app/core/constants/profile_creation.dart' as constants;

/// Main Q&A screen
/// Matches screenshot: @screenshots/users/create-profile/5A0A4901-671B-40D4-8071-C221FAE190A0.png
/// User can view added Q&As and add new ones (min 1, max 3)
class QAMainScreen extends ConsumerWidget {
  const QAMainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qaDrafts = ref.watch(qaDraftsProvider);
    final canContinue = qaDrafts.isNotEmpty;

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
            // Progress indicator with padding
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: ProfileProgressBar(
                currentStep: constants.ProfileCreationConstants.profileStepQA,
                totalSteps: constants.ProfileCreationConstants.profileTotalSteps,
                sectionLabel: 'Profile',
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.question_answer_outlined,
                        size: 32,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Let\'s break the ice by answering a question',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 32),

                    // Q&A Cards
                    if (qaDrafts.isEmpty)
                      _buildAddFirstQuestionButton(context)
                    else
                      ...qaDrafts.asMap().entries.map((entry) {
                        final index = entry.key;
                        final qa = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildQACard(context, ref, index, qa),
                        );
                      }),

                    // Add another question button
                    if (qaDrafts.isNotEmpty && qaDrafts.length < 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _buildAddAnotherQuestionButton(context),
                      ),

                    // Helper text
                    if (qaDrafts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Answer at least 1 question to continue (max 3)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom navigation
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
                  onPressed: canContinue ? () => _continue(context, ref) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        canContinue
                            ? 'Continue'
                            : 'Add at least 1 question to continue',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (canContinue) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, color: Colors.white),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFirstQuestionButton(BuildContext context) {
    return InkWell(
      onTap: () => _navigateToQuestionSelector(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Pick a question to answer',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.add, color: Colors.grey[700], size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAnotherQuestionButton(BuildContext context) {
    return InkWell(
      onTap: () => _navigateToQuestionSelector(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Add another question',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.add, color: Colors.grey[700], size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQACard(
    BuildContext context,
    WidgetRef ref,
    int index,
    qa,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      qa.question.question,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      qa.answer,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => _removeQA(ref, index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToQuestionSelector(BuildContext context) {
    Navigator.pushNamed(context, '/profile-creation/qa/select-question');
  }

  void _removeQA(WidgetRef ref, int index) {
    ref.read(qaDraftsProvider.notifier).removeQA(index);
  }

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    final qaDrafts = ref.read(qaDraftsProvider);

    if (qaDrafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer at least one question'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Submit Q&A collection to backend
    try {
      await ref.read(submitQACollectionProvider(qaDrafts).future);

      // Clear draft on success
      await ref.read(profileCreationProvider.notifier).clearDraft();

      if (!context.mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Q&As saved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Navigate to photos section
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const AllPhotosScreen(),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save Q&As: ${e.toString()}'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
