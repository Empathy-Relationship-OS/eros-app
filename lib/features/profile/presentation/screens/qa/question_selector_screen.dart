import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/presentation/providers/qa_provider.dart';
import 'package:eros_app/features/profile/domain/models/question_dto.dart';

/// Question selector screen with category tabs
/// Matches screenshot: @screenshots/users/create-profile/2773081D-DBB1-4E02-85A9-F9C8DAA60F46.png
/// Shows questions organized by category: Interests, Personal, Fun, Ambitions
class QuestionSelectorScreen extends ConsumerStatefulWidget {
  const QuestionSelectorScreen({super.key});

  @override
  ConsumerState<QuestionSelectorScreen> createState() =>
      _QuestionSelectorScreenState();
}

class _QuestionSelectorScreenState
    extends ConsumerState<QuestionSelectorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // For now, we'll use placeholder categories until backend integration
  // The backend will return questions with categories
  final List<String> _categories = ['Interests', 'Personal', 'Fun', 'Ambitions'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(questionsProvider);
    final existingQAs = ref.watch(qaDraftsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pick a question',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.black,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(25),
          ),
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          tabs: _categories.map((category) {
            IconData icon;
            switch (category) {
              case 'Interests':
                icon = Icons.menu_book;
                break;
              case 'Personal':
                icon = Icons.person;
                break;
              case 'Fun':
                icon = Icons.sentiment_satisfied_alt;
                break;
              case 'Ambitions':
                icon = Icons.emoji_events;
                break;
              default:
                icon = Icons.help;
            }

            return Tab(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Text(category),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
      body: questionsAsync.when(
        data: (questions) {
          // Filter out already answered questions
          final answeredQuestionIds = existingQAs.map((qa) => qa.question.questionId).toSet();
          final availableQuestions = questions
              .where((q) => !answeredQuestionIds.contains(q.questionId))
              .toList();

          if (availableQuestions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 64, color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'You\'ve answered all available questions!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Go back and review your answers',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: _categories.map((category) {
              // For now, show all available questions in each tab
              // In production, filter by category from backend
              final categoryQuestions = availableQuestions;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: categoryQuestions.length,
                itemBuilder: (context, index) {
                  final question = categoryQuestions[index];
                  return _buildQuestionItem(context, question);
                },
              );
            }).toList(),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Failed to load questions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.refresh(questionsProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionItem(BuildContext context, QuestionDTO question) {
    return InkWell(
      onTap: () => _selectQuestion(context, question),
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

  void _selectQuestion(BuildContext context, QuestionDTO question) {
    // Navigate to answer input screen
    Navigator.pushNamed(
      context,
      '/profile-creation/qa/answer',
      arguments: question,
    );
  }
}
