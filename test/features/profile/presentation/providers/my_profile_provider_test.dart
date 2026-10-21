import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/models/my_profile.dart';
import 'package:eros_app/features/profile/domain/models/update_user_request.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(File('test/fixtures/users/get_users_me.json').readAsStringSync()) as Map<String, dynamic>;

/// Serves the fixture from GET and records PATCH requests.
class _FakeProfileRepository implements ProfileRepository {
  final requests = <UpdateUserRequest>[];
  Object? updateError;

  @override
  Future<MyProfile> getCurrentUser() async => MyProfile.fromJson(_fixture());

  @override
  Future<MyProfile> updateUser(UpdateUserRequest request) async {
    requests.add(request);
    if (updateError != null) throw updateError!;
    // What the server returns: the stored profile, here with the new bio and a new score.
    return MyProfile.fromJson({..._fixture(), 'bio': request.bio, 'profileCompleteness': 80});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // UserProfileNotifier loads the public profile on creation; never complete it.
    if (invocation.memberName == #getPublicProfile) return Completer<Never>().future;
    return super.noSuchMethod(invocation);
  }
}

void main() {
  late _FakeProfileRepository repository;
  late ProviderContainer container;
  late int userProfileBuilds;

  setUp(() {
    repository = _FakeProfileRepository();
    userProfileBuilds = 0;
    container = ProviderContainer(overrides: [
      profileRepositoryProvider.overrideWithValue(repository),
      userProfileProvider.overrideWith((ref) {
        userProfileBuilds++;
        return UserProfileNotifier(profileRepository: repository, userId: 'fixture-user');
      }),
    ]);
    // Keep the Profile tab's provider alive, as the open tab would.
    container.listen(userProfileProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  test('loads the profile from GET /users/me', () async {
    final profile = await container.read(myProfileProvider.future);

    expect(profile.userId, 'fixture-user');
    expect(profile.bio, 'Likes long walks.');
  });

  test('saveSection sends only that request and replaces the state with the response', () async {
    await container.read(myProfileProvider.future);

    final saved = await container.read(myProfileProvider.notifier).saveSection(UpdateUserRequest(bio: 'New bio'));

    expect(repository.requests.single.toJson(), {'bio': 'New bio'});
    expect(saved.bio, 'New bio');
    expect(saved.profileCompleteness, 80, reason: 'state comes from the server, not a local merge');
    expect(container.read(myProfileProvider).value?.bio, 'New bio');
  });

  test('saveSection invalidates the Profile tab provider', () async {
    await container.read(myProfileProvider.future);
    expect(userProfileBuilds, 1);

    await container.read(myProfileProvider.notifier).saveSection(UpdateUserRequest(bio: 'New bio'));
    container.read(userProfileProvider);

    expect(userProfileBuilds, 2);
  });

  test('saveSection keeps the previous state and rethrows on failure', () async {
    await container.read(myProfileProvider.future);
    repository.updateError = ProfileValidationException('Bio must not exceed 300 characters');

    await expectLater(
      container.read(myProfileProvider.notifier).saveSection(UpdateUserRequest(bio: 'x')),
      throwsA(isA<ProfileValidationException>()),
    );

    final state = container.read(myProfileProvider);
    expect(state.hasError, isFalse);
    expect(state.value?.bio, 'Likes long walks.');
    expect(userProfileBuilds, 1);
  });
}
