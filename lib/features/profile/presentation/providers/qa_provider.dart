import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/profile/data/repositories/qa_repository.dart';
import 'package:eros_app/features/profile/domain/models/question_dto.dart';
import 'package:eros_app/features/profile/domain/models/qa_draft.dart';
import 'package:eros_app/features/profile/domain/models/user_qa_item_dto.dart';

/// Provider for the QA repository
final qaRepositoryProvider = Provider<QARepository>((ref) {
  return QARepository(
    authService: ref.watch(authServiceProvider),
  );
});

/// Provider for fetching all available questions
final questionsProvider = FutureProvider<List<QuestionDTO>>((ref) async {
  final repository = ref.watch(qaRepositoryProvider);
  return repository.getAllQuestions();
});

/// State notifier for managing Q&A drafts during profile creation
class QADraftsNotifier extends StateNotifier<List<QADraft>> {
  QADraftsNotifier() : super([]);

  /// Add a new Q&A draft
  void addQA(QADraft qa) {
    if (state.length >= 3) {
      throw StateError('Maximum 3 Q&As allowed');
    }

    // Check if question already exists
    final exists = state.any((draft) => draft.question.questionId == qa.question.questionId);
    if (exists) {
      throw StateError('This question has already been answered');
    }

    // Update display orders
    final updatedQA = qa.copyWith(displayOrder: state.length + 1);
    state = [...state, updatedQA];
  }

  /// Update an existing Q&A draft
  void updateQA(int index, QADraft updatedQA) {
    if (index < 0 || index >= state.length) {
      throw RangeError('Invalid Q&A index');
    }

    final newState = [...state];
    newState[index] = updatedQA.copyWith(displayOrder: index + 1);
    state = newState;
  }

  /// Remove a Q&A draft
  void removeQA(int index) {
    if (index < 0 || index >= state.length) {
      throw RangeError('Invalid Q&A index');
    }

    final newState = [...state];
    newState.removeAt(index);

    // Reorder remaining Q&As
    for (int i = 0; i < newState.length; i++) {
      newState[i] = newState[i].copyWith(displayOrder: i + 1);
    }

    state = newState;
  }

  /// Clear all Q&A drafts
  void clear() {
    state = [];
  }

  /// Check if we have the minimum required Q&As (at least 1)
  bool get hasMinimumQAs => state.isNotEmpty;

  /// Check if we can add more Q&As (max 3)
  bool get canAddMore => state.length < 3;

  /// Check if all Q&As are valid
  bool get allValid => state.every((qa) => qa.isValid);

  /// Convert drafts to UserQAItemDTOs for submission
  List<UserQAItemDTO> toUserQAItems(String userId) {
    return state.map((draft) {
      return UserQAItemDTO(
        userId: userId,
        question: draft.question,
        answer: draft.answer,
        displayOrder: draft.displayOrder,
      );
    }).toList();
  }

  /// Load existing Q&As (e.g., when editing profile)
  void loadQAs(List<QADraft> qas) {
    state = qas;
  }
}

/// Provider for the Q&A drafts notifier
final qaDraftsProvider = StateNotifierProvider<QADraftsNotifier, List<QADraft>>((ref) {
  return QADraftsNotifier();
});

/// Provider for submitting Q&A collection
final submitQACollectionProvider = FutureProvider.family<void, List<QADraft>>((ref, qaDrafts) async {
  final repository = ref.watch(qaRepositoryProvider);
  final authService = ref.watch(authServiceProvider);
  final userId = authService.getUserId();

  if (qaDrafts.isEmpty || qaDrafts.length > 3) {
    throw Exception('Must provide between 1 and 3 Q&As');
  }

  // Convert drafts to DTOs
  final qaItems = qaDrafts.asMap().entries.map((entry) {
    return UserQAItemDTO(
      userId: userId,
      question: entry.value.question,
      answer: entry.value.answer,
      displayOrder: entry.key + 1,
    );
  }).toList();

  // Submit to backend
  await repository.submitQACollection(qaItems);
});
