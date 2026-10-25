import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/profile/data/repositories/qa_repository.dart';
import 'package:eros_app/features/profile/domain/models/question_dto.dart';
import 'package:eros_app/features/profile/domain/models/user_qa_collection_dto.dart';
import 'package:eros_app/features/profile/domain/models/user_qa_item_dto.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/qa_answer_rules.dart';

/// Fewest and most answers a profile can have. The editor keeps at least one, as onboarding
/// does (eros-app #27); the backend allows at most three.
const int minQAAnswers = 1;
const int maxQAAnswers = 3;

/// The signed-in user's saved answers (`GET /users/qa/me`), for the Edit profile hub's row.
/// The Q&A editor invalidates it after a save.
final myQAsProvider = FutureProvider.autoDispose<UserQACollectionDTO>(
  (ref) => ref.watch(qaRepositoryProvider).getMyQAs(),
);

/// One answer in the editor. [answer] is the text as typed; it is cleaned when saved.
class EditableAnswer {
  final QuestionDTO question;
  final String answer;

  const EditableAnswer({required this.question, required this.answer});

  EditableAnswer withAnswer(String answer) => EditableAnswer(question: question, answer: answer);
}

class QAEditState {
  /// The answers in their edited order.
  final List<EditableAnswer> answers;

  /// The answers as loaded, to tell whether anything changed.
  final List<EditableAnswer> original;
  final bool isLoading;
  final bool isSaving;

  /// A load problem to show. Save problems are thrown to the screen's banner.
  final String? error;

  const QAEditState({
    this.answers = const [],
    this.original = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.error,
  });

  QAEditState copyWith({
    List<EditableAnswer>? answers,
    List<EditableAnswer>? original,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) =>
      QAEditState(
        answers: answers ?? this.answers,
        original: original ?? this.original,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        error: clearError ? null : (error ?? this.error),
      );

  /// Questions, order or cleaned answers differ from what was loaded.
  bool get isDirty {
    if (answers.length != original.length) return true;
    for (var i = 0; i < answers.length; i++) {
      if (answers[i].question.questionId != original[i].question.questionId) return true;
      if (cleanQAAnswer(answers[i].answer) != cleanQAAnswer(original[i].answer)) return true;
    }
    return false;
  }

  /// Every answer can be saved as it stands.
  bool get allValid => answers.every((a) => qaAnswerError(a.answer) == null);

  bool get canAddMore => answers.length < maxQAAnswers;

  /// 1–3 answers, all valid, something changed, and no save running.
  bool get canSave =>
      !isLoading &&
      !isSaving &&
      answers.length >= minQAAnswers &&
      answers.length <= maxQAAnswers &&
      allValid &&
      isDirty;

  /// Ids of the questions already in the list, so they aren't offered again.
  Set<int> get answeredQuestionIds => answers.map((a) => a.question.questionId).toSet();
}

/// The Q&A section of Edit profile (eros-app #27).
///
/// Loads the saved answers, keeps every change local, and [save] replaces the whole collection
/// in one `POST /users/qa/me/collection`, as the photo editor commits its whole set.
class QAEditNotifier extends StateNotifier<QAEditState> {
  final Ref _ref;

  /// The owner of the loaded collection; every saved item carries it.
  String _userId = '';

  QAEditNotifier(this._ref) : super(const QAEditState()) {
    load();
  }

  QARepository get _repository => _ref.read(qaRepositoryProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      _apply(await _repository.getMyQAs());
    } on QARepositoryException catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  // Edits are ignored while a save runs: its result replaces the list.

  /// Adds [question] at the end with an empty answer, if there is room and it isn't already in
  /// the list.
  void add(QuestionDTO question) {
    if (state.isSaving || !state.canAddMore || state.answeredQuestionIds.contains(question.questionId)) return;
    state = state.copyWith(answers: [...state.answers, EditableAnswer(question: question, answer: '')]);
  }

  void setAnswer(int index, String answer) {
    if (state.isSaving || index < 0 || index >= state.answers.length) return;
    state = state.copyWith(answers: [...state.answers]..[index] = state.answers[index].withAnswer(answer));
  }

  void remove(int index) {
    if (state.isSaving || index < 0 || index >= state.answers.length) return;
    state = state.copyWith(answers: [...state.answers]..removeAt(index));
  }

  /// Moves the answer at [from] to [to] (both indexes in the current list).
  void reorder(int from, int to) {
    final count = state.answers.length;
    if (state.isSaving || from < 0 || from >= count || to < 0 || to >= count || from == to) return;
    final answers = [...state.answers];
    answers.insert(to, answers.removeAt(from));
    state = state.copyWith(answers: answers);
  }

  /// Saves the answers in their current order, cleaned.
  ///
  /// On success the state becomes the server's collection, and the profile providers and
  /// [myQAsProvider] are invalidated (completeness may change). Throws [QARepositoryException]
  /// with the server's message if it refuses the collection.
  Future<void> save() async {
    if (!state.canSave) throw StateError('Nothing to save');
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final userId = _userId;
      final saved = await _repository.submitQACollection([
        for (var i = 0; i < state.answers.length; i++)
          UserQAItemDTO(
            userId: userId,
            question: state.answers[i].question,
            answer: cleanQAAnswer(state.answers[i].answer),
            displayOrder: i + 1,
          ),
      ]);
      _ref.invalidate(myQAsProvider);
      _ref.invalidate(userProfileProvider);
      _ref.invalidate(myProfileProvider);
      if (mounted) _apply(saved);
    } catch (_) {
      if (mounted) state = state.copyWith(isSaving: false);
      rethrow;
    }
  }

  void _apply(UserQACollectionDTO collection) {
    if (!mounted) return;
    _userId = collection.userId;
    final sorted = [...collection.qas]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final answers = [for (final qa in sorted) EditableAnswer(question: qa.question, answer: qa.answer)];
    state = QAEditState(answers: answers, original: answers, isLoading: false);
  }
}

/// The Q&A editor's state. Disposed when the editor closes, so each visit starts from the
/// server's answers.
final qaEditProvider = StateNotifierProvider.autoDispose<QAEditNotifier, QAEditState>(
  (ref) => QAEditNotifier(ref),
);
