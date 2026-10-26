import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/data/repositories/qa_repository.dart';
import 'package:eros_app/features/profile/domain/models/my_profile.dart';
import 'package:eros_app/features/profile/domain/models/question_dto.dart';
import 'package:eros_app/features/profile/domain/models/user_qa_collection_dto.dart';
import 'package:eros_app/features/profile/domain/models/user_qa_item_dto.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/qa_edit_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const q1 = QuestionDTO(questionId: 1, question: 'What makes you laugh?');
const q2 = QuestionDTO(questionId: 2, question: 'Perfect Sunday?');
const q3 = QuestionDTO(questionId: 3, question: 'Best trip so far?');
const q4 = QuestionDTO(questionId: 4, question: 'Hidden talent?');

UserQACollectionDTO qaCollection(List<(QuestionDTO, String)> answers) => UserQACollectionDTO(
      userId: 'u1',
      qas: [
        for (var i = 0; i < answers.length; i++)
          UserQAItemDTO(userId: 'u1', question: answers[i].$1, answer: answers[i].$2, displayOrder: i + 1),
      ],
      totalCount: answers.length,
    );

/// GET serves [stored]; POST records the collection and stores it, or throws [submitError].
class FakeQARepository implements QARepository {
  UserQACollectionDTO stored = qaCollection([(q1, 'Puns'), (q2, 'Long walks')]);
  List<QuestionDTO> questions = const [q1, q2, q3, q4];
  final submissions = <List<UserQAItemDTO>>[];
  Object? submitError;
  int loads = 0;

  /// When set, the submit waits for this.
  Completer<void>? heldSubmit;

  /// When set, loading throws it (the first load only when [failFirstLoadOnly]).
  Object? loadError;
  bool failFirstLoadOnly = false;

  @override
  Future<UserQACollectionDTO> getMyQAs() async {
    loads++;
    if (loadError != null && (!failFirstLoadOnly || loads == 1)) throw loadError!;
    return stored;
  }

  @override
  Future<List<QuestionDTO>> getAllQuestions() async => questions;

  @override
  Future<UserQACollectionDTO> submitQACollection(List<UserQAItemDTO> qas) async {
    submissions.add(qas);
    if (heldSubmit != null) await heldSubmit!.future;
    if (submitError != null) throw submitError!;
    stored = UserQACollectionDTO(userId: 'u1', qas: qas, totalCount: qas.length);
    return stored;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<MyProfile> getCurrentUser() async => MyProfile.fromJson(
        jsonDecode(File('test/fixtures/users/get_users_me.json').readAsStringSync()) as Map<String, dynamic>,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getPublicProfile) return Completer<Never>().future;
    return super.noSuchMethod(invocation);
  }
}

/// Counts builds: invalidating re-runs `build` on the same notifier.
class _CountingMyProfile extends MyProfileNotifier {
  final void Function() onBuild;
  _CountingMyProfile(this.onBuild);

  @override
  Future<MyProfile> build() {
    onBuild();
    return super.build();
  }
}

void main() {
  late FakeQARepository repository;
  late ProviderContainer container;
  late int userProfileBuilds;
  late int myProfileBuilds;

  QAEditState state() => container.read(qaEditProvider);
  QAEditNotifier notifier() => container.read(qaEditProvider.notifier);

  Future<void> loaded() async {
    container.listen(qaEditProvider, (_, _) {});
    await pumpEventQueue();
  }

  setUp(() {
    repository = FakeQARepository();
    userProfileBuilds = 0;
    myProfileBuilds = 0;
    final profileRepository = _FakeProfileRepository();
    container = ProviderContainer(overrides: [
      qaRepositoryProvider.overrideWithValue(repository),
      profileRepositoryProvider.overrideWithValue(profileRepository),
      userProfileProvider.overrideWith((ref) {
        userProfileBuilds++;
        return UserProfileNotifier(profileRepository: profileRepository, userId: 'u1');
      }),
      myProfileProvider.overrideWith(() => _CountingMyProfile(() => myProfileBuilds++)),
    ]);
  });

  tearDown(() => container.dispose());

  test('loads the saved answers in order, unchanged', () async {
    repository.stored = UserQACollectionDTO(userId: 'u1', totalCount: 2, qas: const [
      UserQAItemDTO(userId: 'u1', question: q2, answer: 'Long walks', displayOrder: 2),
      UserQAItemDTO(userId: 'u1', question: q1, answer: 'Puns', displayOrder: 1),
    ]);
    await loaded();

    expect(state().answers.map((a) => a.question), [q1, q2]);
    expect(state().isDirty, isFalse);
    expect(state().canSave, isFalse);
  });

  group('a failed load', () {
    test('stops the spinner, says why, and never allows Save, even after adding an answer', () async {
      repository.loadError = QARepositoryException('Unable to connect to the server.');
      await loaded();

      expect(state().isLoading, isFalse);
      expect(state().error, 'Unable to connect to the server.');
      notifier().add(q3);
      notifier().setAnswer(0, 'Lisbon');
      expect(state().canSave, isFalse);
      await expectLater(notifier().save(), throwsA(isA<StateError>()));
      expect(repository.submissions, isEmpty, reason: 'the stored answers must not be replaced');
    });

    test('a retry that succeeds loads the answers and allows editing again', () async {
      repository
        ..loadError = QARepositoryException('Unable to connect to the server.')
        ..failFirstLoadOnly = true;
      await loaded();

      await notifier().load();
      notifier().setAnswer(0, 'Puns, mostly');

      expect(state().error, isNull);
      expect(state().answers.map((a) => a.question), [q1, q2]);
      expect(state().canSave, isTrue);
    });
  });

  group('Save is enabled', () {
    test('once an answer changes', () async {
      await loaded();

      notifier().setAnswer(0, 'Puns, mostly');

      expect(state().canSave, isTrue);
    });

    test('not when the only change is spaces', () async {
      await loaded();

      notifier().setAnswer(0, '  Puns  ');

      expect(state().isDirty, isFalse);
      expect(state().canSave, isFalse);
    });

    test('not with no answers left (a minimum of 1)', () async {
      await loaded();

      notifier().remove(0);
      notifier().remove(0);

      expect(state().answers, isEmpty);
      expect(state().isDirty, isTrue);
      expect(state().canSave, isFalse);
    });

    test('not while an added question has no answer yet, or one too short', () async {
      await loaded();

      notifier().add(q3);
      expect(state().canSave, isFalse);
      notifier().setAnswer(2, 'x');
      expect(state().canSave, isFalse);
      notifier().setAnswer(2, 'Lisbon');
      expect(state().canSave, isTrue);
    });

    test('not with an answer over 200 characters', () async {
      await loaded();

      notifier().setAnswer(0, 'a' * 201);

      expect(state().canSave, isFalse);
    });
  });

  group('editing', () {
    test('adds up to 3 answers, never a question already answered', () async {
      await loaded();

      notifier().add(q1);
      expect(state().answers.length, 2);
      notifier().add(q3);
      notifier().add(q4);

      expect(state().answers.map((a) => a.question), [q1, q2, q3]);
      expect(state().canAddMore, isFalse);
      expect(state().answeredQuestionIds, {1, 2, 3});
    });

    test('reorder moves an answer', () async {
      await loaded();

      notifier().reorder(1, 0);

      expect(state().answers.map((a) => a.question), [q2, q1]);
      expect(state().canSave, isTrue);
    });

    test('edits are ignored while a save runs', () async {
      await loaded();
      notifier().setAnswer(0, 'Puns, mostly');
      repository.heldSubmit = Completer<void>();
      final saving = notifier().save();

      notifier().remove(0);
      notifier().add(q3);
      notifier().setAnswer(1, 'changed');
      notifier().reorder(0, 1);

      expect(state().answers.map((a) => a.answer), ['Puns, mostly', 'Long walks']);
      repository.heldSubmit!.complete();
      await saving;
    });
  });

  group('save', () {
    test('sends the cleaned answers in order and invalidates the profile providers', () async {
      container.listen(userProfileProvider, (_, _) {});
      container.listen(myProfileProvider, (_, _) {});
      await loaded();
      expect((userProfileBuilds, myProfileBuilds), (1, 1));

      notifier().reorder(1, 0);
      notifier().setAnswer(1, '  Puns\n\n\n\nand dogs \u202e');
      notifier().add(q3);
      notifier().setAnswer(2, 'Lisbon');
      await notifier().save();
      await pumpEventQueue();

      final sent = repository.submissions.single;
      expect(sent.map((qa) => qa.question), [q2, q1, q3]);
      expect(sent.map((qa) => qa.answer), ['Long walks', 'Puns\n\nand dogs', 'Lisbon']);
      expect(sent.map((qa) => qa.displayOrder), [1, 2, 3]);
      expect(sent.map((qa) => qa.userId).toSet(), {'u1'});
      expect(state().isDirty, isFalse);
      expect(state().isSaving, isFalse);
      expect((userProfileBuilds, myProfileBuilds), (2, 2));
    });

    test('a refused save keeps the edits, clears isSaving and rethrows', () async {
      await loaded();
      notifier().setAnswer(0, 'Puns, mostly');
      repository.submitError = QARepositoryException('Duplicate questions are not allowed.');

      await expectLater(notifier().save(), throwsA(isA<QARepositoryException>()));

      expect(state().isSaving, isFalse);
      expect(state().isDirty, isTrue);
      expect(state().canSave, isTrue);
    });
  });
}
